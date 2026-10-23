pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "themes/win98/tray-model.js" as Tray
import "themes/win98/taskbar-plan.js" as Plan

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

    readonly property real u: Win98Tokens.u
    readonly property string current: desktop.openId
    readonly property bool menuShown: host.enabled && current !== ""
    readonly property bool keyboardMode: host.enabled && desktop.taskbarFocus !== "" && current === ""

    // The taskbar's controls in keyboard order.
    readonly property var focusOrder: {
        const p = host.taskbar.plan, out = ["start"];
        for (const g of p.groups) {
            out.push("page" + g.page);
            for (const i of g.windows) out.push("win" + i);
        }
        if (p.taskOut.length) out.push("tasks");
        if (p.trayOut.length) out.push("more");
        for (const id of p.tray) if (id !== "bat") out.push(id);
        out.push("clock");
        return out;
    }
    function moveFocus(delta) {
        const list = host.focusOrder, at = list.indexOf(desktop.taskbarFocus);
        desktop.taskbarFocus = list[((at < 0 ? 0 : at + delta) % list.length + list.length) % list.length];
    }
    function activateFocus() {
        const id = desktop.taskbarFocus;
        desktop.taskbarFocus = "";
        if (id.indexOf("win") === 0) desktop.activateWindow(desktop.lane[Number(id.slice(3))]);
        else if (id.indexOf("page") === 0) desktop.showPage(Number(id.slice(4)));
        else desktop.openMenu(id, true);
    }

    LazyLoader {
        active: host.menuShown || host.keyboardMode

        PanelWindow {
            id: win

            screen: host.desktop.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "mountainous-menu"
            focusable: true
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property var components: ({
                start: startMenu, tasks: tasksMenu, more: moreMenu, logoff: logoffDialog,
                bt: btWindow, wifi: wifiWindow, vol: soundWindow, bri: brightnessWindow, oci: ociWindow,
                disk: storageWindow, builder: builderWindow, ntf: notificationWindow, dict: dictationWindow, clock: clockWindow
            })
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
                    sourceComponent: host.menuShown ? (win.components[host.current] || null) : null
                    readonly property bool isMenu: host.current === "start" || host.current === "tasks" || host.current === "more"
                    readonly property var anchor: host.taskbar.placeOf(host.desktop.anchorId !== "" ? host.desktop.anchorId : host.current)
                    readonly property real w: item ? (item as Item).width : 0
                    readonly property real h: item ? (item as Item).height : 0
                    x: {
                        if (host.current === "start") return 2 * host.u;
                        if (host.current === "logoff") return Win98Tokens.snap(win.width / 2 - w / 2);
                        const centre = loader.anchor ? loader.anchor.x + loader.anchor.w / 2 : win.width;
                        return Math.max(2 * host.u, Math.min(Win98Tokens.snap(centre - w / 2), win.width - w - 2 * host.u));
                    }
                    y: {
                        if (host.current === "logoff") return Win98Tokens.snap(win.barTop / 2 - h / 2);
                        return Math.max(0, win.barTop - h + (loader.isMenu ? 2 * host.u : 0));
                    }
                    onLoaded: { host.desktop.openItem = item; (item as Item).forceActiveFocus(); }
                    Component.onDestruction: if (host.desktop.openItem === item) host.desktop.openItem = null

                    // A press inside the menu stays inside it.
                    MouseArea {
                        z: -1
                        width: loader.w; height: loader.h
                        onPressed: function (mouse) { mouse.accepted = true; }
                    }
                }
            }

            // The widest a window may be: the screen, less 2 u each side.
            function widthFor(units) { return Math.min(units * host.u, win.width - 4 * host.u); }

            Component {
                id: startMenu
                Win98Menu {
                    big: true
                    widthUnits: 196
                    bandText: "Kamoi"
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
                    widthUnits: Math.min(340, Math.floor(win.width / host.u) - 4)
                    bounds: menuBounds
                    model: Plan.overflowWindows(host.desktop.lane.map(function (t) {
                        return { page: host.desktop.shell.pageOf(t) };
                    }), host.taskbar.plan.taskOut).map(function (i) {
                        const t = host.desktop.lane[i];
                        return { text: String((t && t.title) || "(untitled)").replace(/&/g, "&&"), icon: host.desktop.winIcon(t) || "doc",
                            shortcut: "Page " + host.desktop.shell.pageOf(t), window: i };
                    })
                    onTriggered: function (item) { MenuState.close(); host.desktop.activateWindow(host.desktop.lane[item.window]); }
                    onClosed: MenuState.close()
                }
            }
            Component {
                id: moreMenu
                Win98Menu {
                    widthUnits: Math.min(260, Math.floor(win.width / host.u) - 4)
                    bounds: menuBounds
                    model: host.taskbar.plan.trayOut.map(function (id) {
                        return { text: Tray.LABEL[id], icon: host.desktop.trayIcon(id),
                            shortcut: Tray.overflowValue(id, host.desktop.trayData).replace(/&/g, "&&"), control: id };
                    })
                    onTriggered: function (item) { host.desktop.openFromOverflow(item.control); }
                    onClosed: MenuState.close()
                }
            }
            Component {
                id: logoffDialog
                Win98LogOffDialog {
                    width: win.widthFor(300)
                    desktop: host.desktop
                }
            }
            Component { id: btWindow; Win98BluetoothWindow { width: win.widthFor(340); panel: host.desktop.context.bluetooth } }
            Component { id: wifiWindow; Win98WifiWindow { width: win.widthFor(340); panel: host.desktop.context.wifi } }
            Component { id: soundWindow; Win98SoundWindow { width: win.widthFor(350); panel: host.desktop.context.sound } }
            Component { id: brightnessWindow; Win98BrightnessWindow { width: win.widthFor(310); panel: host.desktop.context.brightness } }
            Component { id: ociWindow; Win98OciWindow { width: win.widthFor(420); panel: host.desktop.context.oci } }
            Component { id: storageWindow; Win98StorageWindow { width: win.widthFor(390); panel: host.desktop.context.storage } }
            Component { id: builderWindow; Win98BuilderWindow { width: win.widthFor(360); panel: host.desktop.context.builder } }
            Component { id: notificationWindow; Win98NotificationWindow { width: win.widthFor(430); panel: host.desktop.context.centre; now: host.desktop.context.now } }
            Component { id: dictationWindow; Win98DictationWindow { width: win.widthFor(310); dictation: host.desktop.dictation; text: host.desktop.dictText } }
            Component { id: clockWindow; Win98ClockWindow { width: win.widthFor(210); now: host.desktop.context.now } }
        }
    }
}
