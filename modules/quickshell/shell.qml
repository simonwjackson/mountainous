// Kamoi's two bars. See modules/bars.nix for provenance.
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "lanes.js" as Lanes

ShellRoot {
    id: root

    // Kamoi Meta+I hides the top bar and the dock together.
    property bool chromeVisible: true
    property bool topbarAccessVisible: false
    // True when SUPER+O R opened the builder menu: its focus ring shows
    // from the start. Any other menu clears it.
    property bool builderKeyboard: false

    // One menu is open at a time, on one screen: MenuState. The bar's
    // controls, the Super+O chord and the IPC targets below all go
    // through it, so opening one menu closes any other, OCI included.
    function openMenu(name, screen) {
        root.topbarAccessVisible = false;
        MenuState.open(name, screen, -1);
    }

    function toggleMenu(name, screen) {
        root.topbarAccessVisible = false;
        MenuState.toggle(name, screen, -1);
    }

    function closeMenu(name) {
        if (MenuState.current === name) MenuState.close();
    }

    Connections {
        target: MenuState
        function onCurrentChanged() {
            if (MenuState.current !== "builder") root.builderKeyboard = false;
            if (MenuState.current !== "") root.topbarAccessVisible = false;
        }
    }

    onChromeVisibleChanged: if (!root.chromeVisible) MenuState.close()

    // Popups go to the screen with keyboard focus, where the reader is
    // looking, and to the first screen when Hyprland has not said.
    function focusedScreen() {
        const monitor = Hyprland.focusedMonitor;
        if (monitor) {
            for (const screen of Quickshell.screens) {
                if (screen.name === monitor.name) return screen;
            }
        }
        return root.primaryScreen();
    }

    function primaryScreen() {
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    // The omni bar. Its component lives in modules/omni.nix, which
    // QML resolves by filename from this directory.
    OmniBar { id: omniBarService }

    // One owner for capture, queueing, backend work, insertion, and the
    // bottom-centre state overlay. The top bar only reads its public state.
    Dictation { id: dictationService }

    // The notification socket, and the popups. notifyd owns the D-Bus name;
    // see modules/notification-view.nix. Each top bar has its own centre.
    Notifications { id: notificationService }

    // Whether myoko accepts remote builds; see BuilderGate.qml. Hosts
    // without nix-builder-gate show no control.
    BuilderGate { id: builderGateService }

    NotificationPopups {
        service: notificationService
        screen: root.focusedScreen()
        suppressed: MenuState.current === "ntf"
        onOpenCentreRequested: root.openMenu("ntf", root.focusedScreen())
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.toggleMenu("ntf", root.focusedScreen()); }
        function hide(): void { root.closeMenu("ntf"); }
        function reveal(): void { root.openMenu("ntf", root.focusedScreen()); }
        function current(): string {
            return notificationService.connection.kind
                + " " + notificationService.status.server
                + " " + notificationService.count
                + " " + notificationService.popups.length;
        }
    }

    // Quickshell 0.3.1 registers IPC handlers reliably at the shell root. Keep
    // transport here and forward every event to the dictation state owner.
    IpcHandler {
        target: "dictation"
        function press(): void { dictationService.press(false); }
        function pressEnter(): void { dictationService.press(true); }
        function release(): void { dictationService.release(); }
        function cancel(): void { dictationService.cancel(); }
        function retry(): void { dictationService.retryFailed(); }
        function dismiss(): void { dictationService.dismissFailure(); }
        function current(): string {
            return dictationService.state + " "
                + (dictationService.backend || "none") + " "
                + dictationService.queueCount;
        }
    }

    // Reached from the compositor with:  qs -c mountainous ipc call chrome toggle
    IpcHandler {
        target: "chrome"
        function toggle(): void { root.chromeVisible = !root.chromeVisible; }
        function hide(): void   { root.chromeVisible = false; }
        // Named reveal, not show: `qs ipc call chrome show` returns the
        // interface listing and does nothing, because `show` collides
        // with the qs CLI's own introspection verb. toggle and hide
        // both work, and Meta+I uses toggle.
        function reveal(): void { root.chromeVisible = true; }
    }

    // The Super+O chord's letters (modules/hyprland/hyprland.lua) land here.
    IpcHandler {
        target: "bluetooth"
        function toggle(): void { root.toggleMenu("bt", root.primaryScreen()); }
        function hide(): void { root.closeMenu("bt"); }
        function reveal(): void { root.openMenu("bt", root.primaryScreen()); }
    }

    IpcHandler {
        target: "wifi"
        function toggle(): void { root.toggleMenu("wifi", root.primaryScreen()); }
        function hide(): void { root.closeMenu("wifi"); }
        function reveal(): void { root.openMenu("wifi", root.primaryScreen()); }
    }

    IpcHandler {
        target: "sound"
        function toggle(): void { root.toggleMenu("vol", root.primaryScreen()); }
        function hide(): void { root.closeMenu("vol"); }
        function reveal(): void { root.openMenu("vol", root.primaryScreen()); }
    }

    IpcHandler {
        target: "brightness"
        function toggle(): void { root.toggleMenu("bri", root.primaryScreen()); }
        function hide(): void { root.closeMenu("bri"); }
        function reveal(): void { root.openMenu("bri", root.primaryScreen()); }
    }

    IpcHandler {
        target: "oci"
        function reveal(): void { root.openMenu("oci", root.primaryScreen()); }
        function hide(): void { root.closeMenu("oci"); }
    }

    IpcHandler {
        target: "storage"
        function reveal(): void { root.openMenu("disk", root.primaryScreen()); }
        function hide(): void { root.closeMenu("disk"); }
    }

    IpcHandler {
        target: "builder"
        function reveal(): void {
            if (!builderGateService.enabled) return;
            root.builderKeyboard = true;
            root.openMenu("builder", root.focusedScreen());
        }
        function hide(): void { root.closeMenu("builder"); }
        function current(): string {
            const s = builderGateService.sample;
            return s.kind + (s.kind === "ready"
                ? " " + s.value.accepting + " " + s.value.reason + " " + s.value.running : "")
                + " pending=" + (builderGateService.pending || "none")
                + " panel=" + (MenuState.current === "builder");
        }
    }

    IpcHandler {
        target: "topbar"
        function hide(): void { root.topbarAccessVisible = false; }
        function reveal(): void {
            root.chromeVisible = true;
            root.topbarAccessVisible = true;
        }
    }

    // Quickshell 0.3.1 drops an openwindow event when Hyprland creates the
    // destination workspace at the same time. Its journal says:
    //
    //   Got openwindow for workspace "1" which was not previously tracked.
    //
    // The missing event leaves Hyprland.toplevels one window behind until a
    // later full refresh. Refresh workspaces first, then toplevels. The timer
    // is a fallback when the workspace already existed and valuesChanged does
    // not fire. movewindowv2 has the same race for a newly created page.
    Timer {
        id: dockToplevelRefresh
        interval: 100
        repeat: false
        onTriggered: Hyprland.refreshToplevels()
    }

    Connections {
        target: Hyprland.workspaces

        function onValuesChanged() {
            if (!dockToplevelRefresh.running) return;
            dockToplevelRefresh.stop();
            Hyprland.refreshToplevels();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "openwindow" && event.name !== "movewindowv2") return;
            dockToplevelRefresh.restart();
            Hyprland.refreshWorkspaces();
        }
    }

    // One screen's windows, ordered along its pages. Each screen is its
    // own lane: its dock lists every page on that screen, and none of
    // the other screen's. See lanes.js.
    //
    // Every page, not just the one showing: the dock is how you see the
    // screen's whole session at once, so a window two pages away is
    // reachable in one click rather than by walking the strip to find it.
    function windowsOn(screen) {
        return Lanes.windowsOn(Hyprland.toplevels.values, screen ? screen.name : "");
    }

    // Which page a window is on, or -1 while it is between pages.
    //
    // windowsOn filters on t.workspace before building the list, but
    // that only makes the list safe at the moment it is built. Each
    // delegate binding re-runs when the property changes, and Hyprland
    // nulls workspace while it moves or closes a window, so the filter
    // cannot protect the delegate. Reproduced on hiyori by moving one
    // window across pages and closing it:
    //
    //   WARN scene: @shell.qml[242]: TypeError: Cannot read property
    //                                'id' of null
    //   WARN scene: @shell.qml[272]: same
    //
    // -1 is safe as the unknown value because windowsOn keeps only
    // ids above zero; special workspaces are already excluded.
    function pageOf(toplevel) {
        return Lanes.pageOf(toplevel);
    }

    // Hyprland addresses a window as address:0x... in a dispatcher.
    // The Wayland handle carries no address, so it comes from the last
    // IPC payload, which is empty until Hyprland has reported the
    // window once.
    function addressOf(toplevel) {
        const o = toplevel ? toplevel.lastIpcObject : null;
        return (o && o.address) ? o.address : "";
    }

    // Kamoi's dock shows one page, so dragging an icon onto another
    // swaps two window positions. This dock shows every page, which
    // makes a drop across a page boundary mean something else: send
    // the window to that page. Inside one page it still swaps.
    //
    // Both actions go through hyprctl rather than the Wayland toplevel
    // protocol, because neither has a protocol equivalent. The two
    // dispatchers differ in shape, measured on hiyori:
    //
    //   window.move accepts `window`, so it names its own subject.
    //   window.swap does not. It acts on the focused window, so the
    //   dragged window has to be focused first, in the same batch to
    //   keep the two steps from racing.
    //
    // Both indices are into one dock's list, so a drag never leaves its
    // screen. Each dock is a separate surface, and a pointer drag cannot
    // cross from one surface to another.
    function dropOnto(windows, fromIndex, toIndex) {
        if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return;

        const from = windows[fromIndex];
        const to   = windows[toIndex];
        const a = root.addressOf(from);
        const b = root.addressOf(to);
        if (a === "" || b === "") return;

        const fromPage = root.pageOf(from);
        const toPage   = root.pageOf(to);
        if (fromPage < 0 || toPage < 0) return;

        if (fromPage === toPage) {
            Quickshell.execDetached(["hyprctl", "--batch",
                'dispatch hl.dsp.focus({ window = "address:' + a + '" }) ; '
                + 'dispatch hl.dsp.window.swap({ target = "address:' + b + '" })']);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch",
                'hl.dsp.window.move({ window = "address:' + a + '", '
                + 'workspace = ' + toPage + ' })']);
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    //----------------------------------------------------------------
    // TOP BAR
    //----------------------------------------------------------------
    // Per screen: the data owners, the bar that reads them, and the one
    // window that shows whichever menu is open.
    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope

            required property var modelData

            // The window that last had focus on this screen. The title
            // falls back to it once focus moves to another screen, so this
            // bar keeps naming what this screen shows.
            property var lastFocused: null

            Connections {
                target: Hyprland

                function onActiveToplevelChanged() {
                    const t = Hyprland.activeToplevel;
                    if (t && Lanes.screenOf(t) === screenScope.modelData.name) screenScope.lastFocused = t;
                }
            }

            readonly property var frontWindow: Lanes.frontWindow(
                Hyprland.toplevels.values, modelData.name,
                Hyprland.activeToplevel, lastFocused)

            function shows(name) {
                return MenuState.current === name && MenuState.screen === screenScope.modelData;
            }

            BluetoothPanel { id: bluetoothPanel; shown: screenScope.shows("bt") }
            WifiPanel { id: wifiPanel; shown: screenScope.shows("wifi") }
            SoundPanel { id: soundPanel; shown: screenScope.shows("vol") }
            BrightnessPanel { id: brightnessPanel; shown: screenScope.shows("bri") }
            OciEgress { id: ociEgress; shown: screenScope.shows("oci") }
            StorageHealth { id: storageHealth; shown: screenScope.shows("disk") }
            BuilderPanel {
                id: builderPanel
                gate: builderGateService
                shown: screenScope.shows("builder")
                openedByKeyboard: root.builderKeyboard
            }
            NotificationCentre {
                id: notificationCentre
                service: notificationService
                shown: screenScope.shows("ntf")
            }

            TopBar {
                id: topBar
                modelData: screenScope.modelData
                visible: root.chromeVisible
                bluetooth: bluetoothPanel
                wifi: wifiPanel
                sound: soundPanel
                brightness: brightnessPanel
                oci: ociEgress
                storage: storageHealth
                notifications: notificationService
                dictation: dictationService
                omniBar: omniBarService
                frontWindow: screenScope.frontWindow
                builderGate: builderGateService
                now: clock.date
                chordVisible: root.topbarAccessVisible
            }

            Component {
                id: clockMenu
                ClockMenu { now: clock.date }
            }

            Component {
                id: overflowMenu
                OverflowMenu { bar: topBar }
            }

            MenuHost {
                screen: screenScope.modelData
                bar: topBar
                menus: ({
                    bt: bluetoothPanel.menu,
                    wifi: wifiPanel.menu,
                    vol: soundPanel.menu,
                    bri: brightnessPanel.menu,
                    oci: ociEgress.enabled ? ociEgress.menu : null,
                    disk: storageHealth.enabled ? storageHealth.menu : null,
                    ntf: notificationCentre.menu,
                    builder: builderGateService.enabled ? builderPanel.menu : null,
                    clock: clockMenu,
                    more: overflowMenu
                })
            }
        }
    }

    //----------------------------------------------------------------
    // BOTTOM DOCK
    //----------------------------------------------------------------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockWindow

            required property var modelData
            screen: modelData
            visible: root.chromeVisible

            // This screen's windows only. See root.windowsOn.
            readonly property var lane: root.windowsOn(modelData)

            anchors { bottom: true; left: true; right: true }
            implicitHeight: 44
            // Kamoi: "a floating window dock reserves space at the
            // bottom". The margin floats it; the anchors reserve it.
            margins { bottom: 6; left: 6; right: 6 }
            color: "transparent"

            Rectangle {
                id: dock
                anchors.centerIn: parent
                implicitWidth: dockRow.implicitWidth + 16
                implicitHeight: 38
                radius: Theme.radiusMedium
                color: Theme.bgPanel
                visible: dockWindow.lane.length > 0

                // -1 means no drag is in progress. Holding both ends
                // here rather than in each icon keeps one owner for the
                // gesture, so the icons only read it.
                property int dragIndex: -1
                property int dropIndex: -1

                // The row is one flat strip, so the icon under the
                // pointer is whatever child sits at that x. childAt
                // returns the slot, and each slot knows its own index.
                function slotIndexAt(x, y) {
                    const item = dockRow.childAt(x, y);
                    return (item && item.slotIndex !== undefined) ? item.slotIndex : -1;
                }

                RowLayout {
                    id: dockRow
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: ScriptModel { values: dockWindow.lane }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            // dock.slotIndexAt reads this off whatever
                            // childAt returns, so a drop can name the
                            // window it landed on.
                            readonly property int slotIndex: index

                            // A hairline before the first window of each
                            // workspace, so the strip's shape is visible
                            // without labelling every group.
                            readonly property bool startsWorkspace: {
                                if (index === 0) return false;
                                const here = root.pageOf(modelData);
                                const prev = root.pageOf(dockWindow.lane[index - 1]);
                                // While either window is between pages,
                                // draw nothing rather than a separator
                                // that moves again a moment later.
                                if (here < 0 || prev < 0) return false;
                                return here !== prev;
                            }

                            implicitWidth: 30 + (startsWorkspace ? 9 : 0)
                            implicitHeight: 30
                            radius: Theme.radiusSmall
                            color: "transparent"

                            Rectangle {
                                visible: parent.startsWorkspace
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: 18
                                color: Theme.bgSeparator
                            }

                            Rectangle {
                                id: cell
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 30
                                radius: Theme.radiusSmall
                                // The focused window is marked, on
                                // whichever screen has focus. Windows on
                                // pages this screen is not showing are
                                // dimmed rather than hidden, so the
                                // screen's whole session reads at a
                                // glance. "Showing" is per screen: focus
                                // on the other screen does not dim this
                                // one. A window between pages is not
                                // shown anywhere, so it stays dimmed.
                                color: modelData.activated ? Theme.bgActive : "transparent"
                                opacity: Lanes.isShown(modelData) ? 1.0 : 0.45

                                // A toplevel has no wayland handle until
                                // Hyprland reports its address, so appId
                                // is briefly empty. iconPath("") builds a
                                // malformed url and the journal fills up
                                // with: Could not load icon "?fallback="
                                readonly property string appId: {
                                    const wl = modelData.wayland;
                                    return wl && wl.appId ? wl.appId : "";
                                }

                                // A window class is not an icon name.
                                // Chromium reports the class
                                // chromium-browser while its icon is
                                // named chromium, so asking the theme
                                // for the class filled the journal
                                // with: Could not load icon
                                // "chromium-browser?fallback=...".
                                //
                                // The desktop entry is the mapping
                                // between the two. heuristicLookup
                                // matches on id, name and
                                // StartupWMClass, which is how the
                                // --app web apps resolve: their class
                                // is chrome-<host>__-Default and only
                                // their entry knows that.
                                readonly property string iconName: {
                                    if (cell.appId === "") return "";
                                    const e = DesktopEntries.heuristicLookup(cell.appId);
                                    return (e && e.icon) ? e.icon : cell.appId;
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: 20
                                    visible: source !== ""
                                    source: cell.iconName === ""
                                        ? ""
                                        : Quickshell.iconPath(cell.iconName, "application-x-executable")
                                }

                                // Until the icon resolves, show the first
                                // letter rather than an empty square.
                                Text {
                                    anchors.centerIn: parent
                                    visible: cell.appId === ""
                                    text: (modelData.title || "?").charAt(0).toUpperCase()
                                    color: Theme.textSecondary
                                    font.pixelSize: 13
                                    font.family: Theme.fontFamily
                                }

                                // The icon lifts while it is dragged, and
                                // the icon under the pointer lights up, so
                                // the drop target is never a guess.
                                scale: dock.dragIndex === index ? 1.18 : 1.0
                                border.width: dock.dropIndex === index
                                              && dock.dragIndex !== index ? 1 : 0
                                border.color: Theme.accent

                                MouseArea {
                                    id: grip
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                    // A click and a drag start the same
                                    // way, so the gesture only becomes a
                                    // drag after the pointer travels far
                                    // enough to rule out a shaky click.
                                    readonly property int threshold: 8
                                    property real pressX: 0
                                    property bool dragging: false

                                    function targetAt(mx, my) {
                                        const p = grip.mapToItem(dockRow, mx, my);
                                        return dock.slotIndexAt(p.x, p.y);
                                    }

                                    onPressed: function (mouse) {
                                        grip.pressX = mouse.x;
                                        grip.dragging = false;
                                    }

                                    onPositionChanged: function (mouse) {
                                        if (!(mouse.buttons & Qt.LeftButton)) return;
                                        if (!grip.dragging
                                            && Math.abs(mouse.x - grip.pressX) < grip.threshold) return;
                                        grip.dragging = true;
                                        dock.dragIndex = index;
                                        dock.dropIndex = grip.targetAt(mouse.x, mouse.y);
                                    }

                                    onReleased: function (mouse) {
                                        if (!grip.dragging) return;
                                        root.dropOnto(dockWindow.lane, index, grip.targetAt(mouse.x, mouse.y));
                                        dock.dragIndex = -1;
                                        dock.dropIndex = -1;
                                    }

                                    // A release after a drag still emits
                                    // clicked, and activating the window
                                    // there would undo the drop by pulling
                                    // focus to the old page.
                                    onClicked: function (mouse) {
                                        if (grip.dragging) { grip.dragging = false; return; }
                                        const wl = modelData.wayland;
                                        if (!wl) return;
                                        // Go through the Wayland toplevel
                                        // protocol, not Hyprland.dispatch:
                                        // dispatcher syntax differs under
                                        // a Lua config (Hyprland.usingLua)
                                        // and this path avoids the issue.
                                        // activate() also pulls the focus
                                        // to that window's workspace.
                                        if (mouse.button === Qt.MiddleButton) wl.close();
                                        else wl.activate();
                                    }

                                    onCanceled: {
                                        grip.dragging = false;
                                        dock.dragIndex = -1;
                                        dock.dropIndex = -1;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
