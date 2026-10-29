pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "themes/win98/tray-model.js" as Tray
import "themes/win98/taskbar-plan.js" as Plan
import "themes/win98/session-model.js" as Session

// The one surface of a screen that shows whichever Win98 menu or window is
// open: the Start menu, a tray window, a chevron menu, or the Log Off
// question. MenuState says which.
//
// It covers the screen except the taskbar: the input mask leaves the bar
// out, so the pointer still reaches the bar while a menu is open. That lets
// a menu follow the pointer from control to control, and a second press on
// a control close its menu. A press anywhere else closes it; Esc closes one
// level. Menus rise from the bar: the Start menu from its left end, a tray
// window centred over its icon and kept 2 u inside the screen.
//
// While the taskbar has the keyboard (after Esc from a Start menu the
// keyboard opened, as Win98 left focus on the Start button), this surface
// holds the keyboard and draws nothing: Left/Right/Tab move along the bar,
// Enter, Space or Up opens, Esc lets go.
Scope {
    id: host

    required property var desktop
    required property var taskbar
    property bool enabled: true

    readonly property real u: Kit.Win98Tokens.unitFor(host.taskbar)
    readonly property string current: desktop.openId
    // The Shut Down dialog has a surface of its own (Win98ShutDownScreen).
    readonly property bool menuShown: host.enabled && current !== "" && current !== "shutdown"
    readonly property bool keyboardMode: host.enabled && desktop.taskbarFocus !== "" && current === ""

    // The taskbar's controls in keyboard order.
    readonly property var focusOrder: {
        const p = host.taskbar.plan, out = ["start"];
        // Page dividers are drawn only: the keyboard steps over them.
        for (const g of p.groups) for (const i of g.windows) out.push("win" + i);
        if (p.tasksChevron) out.push("tasks");
        if (p.chevron) out.push("more");
        if (p.structure !== "start") for (const id of p.tray) if (id !== "bat") out.push(id);
        if (!p.clockOut) out.push("clock");
        return out;
    }
    function moveFocus(delta) {
        const list = host.focusOrder, at = list.indexOf(desktop.taskbarFocus);
        desktop.taskbarFocus = list[((at < 0 ? 0 : at + delta) % list.length + list.length) % list.length];
    }
    function activateFocus() {
        const id = desktop.taskbarFocus;
        desktop.taskbarFocus = "";
        if (id.indexOf("win") === 0) desktop.clickWindow(desktop.lane[Number(id.slice(3))]);
        else desktop.openMenu(id, true);
    }
    // Shift+F10 or the Menu key: the focused window button's window menu,
    // anything else the taskbar's own menu, from the control's left edge.
    function contextFocus() {
        const id = desktop.taskbarFocus;
        const place = host.taskbar.placeOf(id);
        const x = place ? place.x : 0;
        const y = host.taskbar.height > 0 ? desktop.screen.height - host.taskbar.barHeight : 0;
        desktop.taskbarFocus = "";
        if (id.indexOf("win") === 0) desktop.windowMenu(desktop.addressOf(desktop.lane[Number(id.slice(3))]), x, y);
        else desktop.taskbarMenu(x, y);
    }

    // The open menu or window's root item, for checks.
    // (The live window binds it; a destroyed item reads as null.)
    property var openItem: null

    LazyLoader {
        id: lazy
        active: host.menuShown || host.keyboardMode

        PanelWindow {
            id: win
            readonly property real u: Kit.Win98Tokens.unitFor(win)

            screen: host.desktop.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "mountainous-menu"
            focusable: true
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property var components: ({
                start: startMenu, tasks: tasksMenu, more: moreMenu, logoff: logoffDialog,
                glance: glanceMenu, fleetmenu: fleetMenu,
                winmenu: windowMenu, tbmenu: taskbarMenu, sysprops: systemWindow,
                layout: layoutWindow, bt: btWindow, wifi: wifiWindow, vol: soundWindow, bri: brightnessWindow, oci: ociWindow,
                disk: storageWindow, builder: builderWindow, ntf: notificationWindow, dict: dictationWindow, clock: clockWindow,
                find: host.desktop.omniClaimed ? findWindow : null, address: host.desktop.omniClaimed ? openDialog : null
            })
            Binding {
                target: host
                property: "openItem"
                value: loader.item
                // A window on its way out unloads after the next has loaded;
                // only a loaded item is written.
                when: win.alive && loader.item !== null
                restoreMode: Binding.RestoreNone
            }
            readonly property real barTop: win.height - host.taskbar.barHeight
            // Input everywhere but the bar.
            mask: Region { x: 0; y: 0; width: win.width; height: Math.max(0, win.barTop) }

            // A window outlives its menu for a moment. Once its menu closes
            // it must never grab again.
            property bool alive: true
            Connections {
                target: host
                function onMenuShownChanged() { if (!host.menuShown && !host.keyboardMode) win.alive = false; }
            }
            HyprlandFocusGrab {
                active: win.alive && (host.menuShown || host.keyboardMode)
                windows: [ win, host.taskbar ]
                onCleared: if (win.alive) { host.desktop.taskbarFocus = ""; MenuState.close(); }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: { host.desktop.taskbarFocus = ""; MenuState.close(); }
            }

            // Cascades stay above the bar and inside the screen.
            Item { id: menuBounds; width: win.width; height: win.barTop }

            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: function (event) {
                    if (host.keyboardMode) {
                        if (event.key === Qt.Key_Escape) host.desktop.taskbarFocus = "";
                        else if (event.key === Qt.Key_Right || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) host.moveFocus(1);
                        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) host.moveFocus(-1);
                        else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) host.contextFocus();
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Up) host.activateFocus();
                        else return;
                        event.accepted = true;
                        return;
                    }
                    if (event.key !== Qt.Key_Escape) return;
                    // A window may take Esc for itself first (the Wi-Fi prompt).
                    const w = loader.item as Win98Window;
                    if (w && w.cancel()) { event.accepted = true; return; }
                    MenuState.close();
                    event.accepted = true;
                }

                Loader {
                    id: loader
                    focus: true
                    // A window on its way out (LazyLoader deletes it later)
                    // never loads again: the next menu is the next window's.
                    sourceComponent: host.menuShown && win.alive ? (win.components[host.current] || null) : null
                    readonly property bool isMenu: ["start", "tasks", "more", "glance", "fleetmenu"].indexOf(host.current) >= 0
                    // The context menus open at a point (the pointer, a
                    // caption's left edge below its bar): its top-left,
                    // moved up to stay above the taskbar and left to stay
                    // on the screen.
                    readonly property bool atPoint: host.current === "winmenu" || host.current === "tbmenu"
                    readonly property bool centred: host.current === "logoff" || host.current === "sysprops"
                    readonly property var anchor: host.taskbar.placeOf(host.desktop.anchorId !== "" ? host.desktop.anchorId : host.current)
                    readonly property real w: item ? (item as Item).width : 0
                    readonly property real h: item ? (item as Item).height : 0
                    // Find and Open place themselves (themes/win98/find-plan.js).
                    readonly property Win98FindWindow findItem: item as Win98FindWindow
                    readonly property Win98OpenDialog dialogItem: item as Win98OpenDialog
                    x: {
                        if (loader.findItem) return loader.findItem.placeX;
                        if (loader.dialogItem) return loader.dialogItem.placeX;
                        if (host.current === "start") return 2 * win.u;
                        if (loader.centred) return Kit.Win98Tokens.snap(win.width / 2 - w / 2, win.u);
                        if (loader.atPoint) return Math.max(0, Math.min(Kit.Win98Tokens.snap(host.desktop.menuPoint.x, win.u), win.width - w));
                        const centre = loader.anchor ? loader.anchor.x + loader.anchor.w / 2 : win.width;
                        return Math.max(2 * win.u, Math.min(Kit.Win98Tokens.snap(centre - w / 2, win.u), win.width - w - 2 * win.u));
                    }
                    y: {
                        if (loader.findItem) return loader.findItem.placeY;
                        if (loader.dialogItem) return loader.dialogItem.placeY;
                        if (loader.centred) return Math.max(0, Kit.Win98Tokens.snap(win.barTop / 2 - h / 2, win.u));
                        if (loader.atPoint) return Math.max(0, Math.min(Kit.Win98Tokens.snap(host.desktop.menuPoint.y, win.u), win.barTop - h));
                        return Math.max(0, win.barTop - h + (loader.isMenu ? 2 * win.u : 0));
                    }
                    onLoaded: (item as Item).forceActiveFocus()

                    // A press inside the menu stays inside it.
                    MouseArea {
                        z: -1
                        width: loader.w; height: loader.h
                        onPressed: function (mouse) { mouse.accepted = true; }
                    }
                }
            }

            // The widest a window may be: the screen, less 2 u each side.
            function widthFor(units) { return Math.min(units * win.u, win.width - 4 * win.u); }

            Component {
                id: startMenu
                Win98Menu {
                    // Narrow, decoration gives way before the labels do:
                    // first the 32-u rows become 20-u rows, then the
                    // band goes.
                    readonly property int room: Math.floor(win.width / win.u) - 4
                    big: room >= 160
                    widthUnits: Math.min(196, room)
                    bandText: room >= 140 ? "Kamoi" : ""
                    bandSubText: host.desktop.hostLabel
                    roll: "up"
                    bounds: menuBounds
                    model: host.desktop.startModel
                    // A cursor drawn by the harness (state sheets).
                    Component.onCompleted: {
                        const p = host.desktop.preview || {};
                        if (p.startPath !== undefined) setState(p.startPath, p.startCursor === undefined ? -1 : p.startCursor);
                    }
                    onTriggered: function (item) { host.desktop.runStart(item); }
                    onClosed: {
                        const byKeyboard = host.desktop.keyboardOpened;
                        MenuState.close();
                        if (byKeyboard) host.desktop.taskbarFocus = "start";
                    }
                }
            }
            Component {
                id: tasksMenu
                Win98Menu {
                    // The chevron menus appear at once, as the mock's do.
                    animate: false
                    widthUnits: Math.min(340, Math.floor(win.width / win.u) - 4)
                    bounds: menuBounds
                    // By page, a separator between two pages (never a number).
                    model: {
                        const out = [];
                        let last = null;
                        for (const i of Plan.overflowWindows(host.desktop.lane.map(function (t) {
                            return { page: host.desktop.pageOf(t) };
                        }), host.taskbar.plan.taskOut)) {
                            const t = host.desktop.lane[i];
                            if (last !== null && host.desktop.pageOf(t) !== last) out.push({ separator: true });
                            last = host.desktop.pageOf(t);
                            out.push({ text: String((t && t.title) || "(untitled)").replace(/&/g, "&&"), icon: host.desktop.winIcon(t) || "doc",
                                shortcut: host.desktop.windowHint(t), window: i });
                        }
                        return out;
                    }
                    onTriggered: function (item) { MenuState.close(); host.desktop.activateWindow(host.desktop.lane[item.window]); }
                    onClosed: MenuState.close()
                }
            }
            Component {
                id: moreMenu
                Win98Menu {
                    animate: false
                    widthUnits: Math.min(260, Math.floor(win.width / win.u) - 4)
                    bounds: menuBounds
                    model: host.desktop.overflowItems(host.taskbar.plan.structure === "compact")
                    onTriggered: function (item) {
                        if (item.action === "window") { MenuState.close(); host.desktop.activateWindow(host.desktop.lane[item.window]); }
                        else if (item.action === "restorefleet") { MenuState.close(); host.desktop.restoreFleet(); }
                        else host.desktop.openFromOverflow(item.control);
                    }
                    onClosed: MenuState.close()
                }
            }
            // The Glance button's menu, and the tray Fleet icon's.
            Component {
                id: glanceMenu
                Win98Menu {
                    objectName: "glanceMenu"
                    animate: false
                    bounds: menuBounds
                    model: host.desktop.glanceMenu
                    onTriggered: function (item) { host.desktop.runFleetMenu(item); }
                    onClosed: MenuState.close()
                }
            }
            Component {
                id: fleetMenu
                Win98Menu {
                    objectName: "fleetTrayMenu"
                    animate: false
                    bounds: menuBounds
                    model: host.desktop.fleetMenu
                    onTriggered: function (item) { host.desktop.runFleetMenu(item); }
                    onClosed: MenuState.close()
                }
            }
            // The window menu (a button's right click, a caption's icon,
            // Alt+Space) and the taskbar's own menu.
            Component {
                id: windowMenu
                Win98Menu {
                    objectName: "windowMenu"
                    animate: false
                    bounds: menuBounds
                    model: host.desktop.windowMenuItems
                    onTriggered: function (item) { host.desktop.runMenu(item); }
                    onClosed: MenuState.close()
                }
            }
            Component {
                id: taskbarMenu
                Win98Menu {
                    objectName: "taskbarMenu"
                    animate: false
                    bounds: menuBounds
                    model: host.desktop.taskbarMenuItems
                    onTriggered: function (item) { host.desktop.runMenu(item); }
                    onClosed: MenuState.close()
                }
            }
            Component {
                id: systemWindow
                Win98SystemProperties {
                    width: win.widthFor(420)
                    availableHeight: win.barTop
                    desktop: host.desktop
                }
            }
            Component {
                id: logoffDialog
                Win98LogOffDialog {
                    width: win.widthFor(300)
                    availableHeight: win.barTop
                    desktop: host.desktop
                }
            }
            Component {
                id: layoutWindow
                Win98LayoutWindow { width: win.widthFor(Session.LAYOUT.width); availableHeight: win.barTop; layout: host.desktop.layout }
            }
            Component { id: btWindow; Win98BluetoothWindow { width: win.widthFor(340); availableHeight: win.barTop; panel: host.desktop.context.bluetooth } }
            Component { id: wifiWindow; Win98WifiWindow { width: win.widthFor(340); availableHeight: win.barTop; panel: host.desktop.context.wifi } }
            Component { id: soundWindow; Win98SoundWindow { width: win.widthFor(350); availableHeight: win.barTop; panel: host.desktop.context.sound } }
            Component { id: brightnessWindow; Win98BrightnessWindow { width: win.widthFor(310); availableHeight: win.barTop; panel: host.desktop.context.brightness } }
            Component { id: ociWindow; Win98OciWindow { width: win.widthFor(420); availableHeight: win.barTop; panel: host.desktop.context.oci } }
            Component { id: storageWindow; Win98StorageWindow { width: win.widthFor(390); availableHeight: win.barTop; panel: host.desktop.context.storage } }
            Component { id: builderWindow; Win98BuilderWindow { width: win.widthFor(360); availableHeight: win.barTop; panel: host.desktop.context.builder } }
            Component { id: notificationWindow; Win98NotificationWindow { width: win.widthFor(430); availableHeight: win.barTop; panel: host.desktop.context.centre; now: host.desktop.context.now } }
            Component { id: dictationWindow; Win98DictationWindow { width: win.widthFor(310); availableHeight: win.barTop; dictation: host.desktop.dictation; text: host.desktop.dictText } }
            Component { id: clockWindow; Win98ClockWindow { width: win.widthFor(210); availableHeight: win.barTop; now: host.desktop.context.now } }
            // The omni service's Win98 view: the Find window and IE's Open.
            Component {
                id: findWindow
                Win98FindWindow {
                    omni: host.desktop.omni
                    areaWidth: win.width
                    areaHeight: win.barTop
                    onAction: function (kind, arg) { host.desktop.findAction(kind, arg); }
                }
            }
            Component {
                id: openDialog
                Win98OpenDialog {
                    omni: host.desktop.omni
                    screen: host.desktop.screen
                    areaWidth: win.width
                    areaHeight: win.barTop
                    onAction: function (kind, arg) { host.desktop.findAction(kind, arg); }
                }
            }
        }
    }
}
