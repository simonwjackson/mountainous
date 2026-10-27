// Kamoi's two bars. See modules/bars.nix for provenance.
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "panels"
import "lanes.js" as Lanes
import "app-model.js" as AppModel
import "chrome-open.js" as ChromeOpen

ShellRoot {
    id: root

    property var desktops: ({})
    property var pendingChrome: ({})
    Connections {
        target: Theme
        function onNameChanged() { root.pendingChrome = {}; }
    }
    Binding {
        target: Theme
        property: "chromeStatus"
        value: {
            const desktops = Object.values(root.desktops);
            return desktops.length > 0 ? desktops[0].diagnostics || "" : "";
        }
    }
    function registerDesktop(screen, desktop) {
        if (!screen) return;
        const next = Object.assign({}, root.desktops);
        if (desktop) next[screen.name] = desktop;
        else delete next[screen.name];
        root.desktops = next;
        Qt.callLater(root.flushChrome);
    }
    function revealChrome() {
        for (const desktop of Object.values(root.desktops).filter(Boolean)) desktop.reveal();
    }
    function hideChrome() {
        for (const desktop of Object.values(root.desktops).filter(Boolean)) desktop.hide();
    }
    function openChrome(control) {
        // Keep the established chord routing: hardware controls use the
        // primary screen; builder, notifications and picker follow focus.
        const primary = ["bt", "wifi", "vol", "bri", "oci", "disk"].indexOf(control) >= 0;
        const screen = primary ? root.primaryScreen() : root.focusedScreen();
        if (!screen) return;
        root.pendingChrome = ChromeOpen.enqueue(root.pendingChrome, screen.name, Theme.name, control);
        Qt.callLater(root.flushChrome);
    }
    function flushChrome() {
        for (const name of Object.keys(root.pendingChrome)) {
            const desktop = root.desktops[name];
            const ready = !!desktop && desktop.active && desktop.theme.id === Theme.name;
            const result = ChromeOpen.take(root.pendingChrome, name, Theme.name, ready);
            root.pendingChrome = result.pending;
            if (result.request) desktop.open(result.request.control);
        }
    }

    // Super+Tab held: hyprland.lua numbers each step; see app-model.js.
    property real cycleSeq: 0
    function cycleChrome(action, position, seq) {
        if (!AppModel.accept(root.cycleSeq, seq)) return;
        root.cycleSeq = seq;
        const screen = root.focusedScreen();
        const desktop = screen ? root.desktops[screen.name] : null;
        if (desktop && typeof desktop.cycle === "function") desktop.cycle(action, position);
    }

    //----------------------------------------------------------------
    // Windows as plain rows, for every theme
    //----------------------------------------------------------------
    // Every toplevel, hidden ones included: the hide/show owner, the
    // running-app lists and the window strips read these. A row's address
    // has no "0x"; x and y are where Hyprland last said the window sits.
    readonly property var windowRows: Hyprland.toplevels.values.map(function (t) { return root.rowOf(t); })
    function rowOf(t) {
        const o = t.lastIpcObject || {};
        const ws = t.workspace;
        const wl = t.wayland;
        const at = o.at && o.at.length === 2 ? o.at : null;
        return {
            address: AppModel.key(t.address || o.address),
            appId: wl && wl.appId ? wl.appId : (o["class"] || ""),
            title: t.title || "",
            page: ws ? ws.id : -1,
            workspace: ws ? ws.name : "",
            screen: Lanes.screenOf(t),
            x: at ? at[0] : undefined,
            y: at ? at[1] : undefined,
            focusHistory: typeof o.focusHistoryID === "number" ? o.focusHistoryID : -1,
            toplevel: t
        };
    }

    // Most recently used windows first, across screens. Hyprland's focus
    // history seeds it after a restart.
    property var focusOrder: []
    readonly property var mru: AppModel.reconcile(root.focusOrder, root.windowRows)
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const t = Hyprland.activeToplevel;
            if (t && t.address) root.focusOrder = AppModel.touch(root.focusOrder, t.address);
        }
    }

    // Hide and Show (Hyprland has no minimise). See WindowHider.qml.
    WindowHider { id: windowHider; rows: root.windowRows }
    readonly property var hider: windowHider

    function rowFor(address) {
        const k = AppModel.key(address);
        for (const r of root.windowRows) if (r.address === k) return r;
        return null;
    }

    // Bring a window forward, on its page. A hidden window's app is shown
    // first, and the window is focused in the same batch.
    function activate(address) {
        const r = root.rowFor(address);
        if (!r) return;
        if (windowHider.isHidden(r)) { windowHider.showApp(r.appId, 0, r.address); return; }
        const wl = r.toplevel ? r.toplevel.wayland : null;
        if (wl) wl.activate();
        else Quickshell.execDetached(["hyprctl", "--instance", "0", "dispatch",
            'hl.dsp.focus({ window = "address:0x' + r.address + '" })']);
    }

    function closeWindow(address) {
        const r = root.rowFor(address);
        const wl = r && r.toplevel ? r.toplevel.wayland : null;
        if (wl) wl.close();
    }

    // Send a window to a page without following it there.
    function moveToPage(address, page) {
        const k = AppModel.key(address);
        if (k === "" || !(page > 0)) return;
        Quickshell.execDetached(["hyprctl", "--instance", "0", "dispatch",
            'hl.dsp.window.move({ window = "address:0x' + k + '", workspace = ' + page + ', follow = false })']);
        positionRefresh.restart();
    }

    // Every page id Hyprland has, on every screen.
    function pageIds() {
        return Hyprland.workspaces.values.map(function (w) { return w.id; }).filter(function (id) { return id > 0; });
    }

    // Kamoi Meta+I hides the top bar and the dock together.
    property bool chromeVisible: true
    property bool chromeAccessVisible: false
    // True when SUPER+O R opened the builder menu: its focus ring shows
    // from the start. Any other menu clears it.
    property bool builderKeyboard: false

    // One menu is open at a time, on one screen: MenuState. The bar's
    // controls, the Super+O chord and the IPC targets below all go
    // through it, so opening one menu closes any other, OCI included.
    function openMenu(name, screen) {
        root.chromeAccessVisible = false;
        MenuState.open(name, screen, -1);
    }

    function toggleMenu(name, screen) {
        root.chromeAccessVisible = false;
        MenuState.toggle(name, screen, -1);
    }

    function closeMenu(name) {
        if (MenuState.current === name) MenuState.close();
    }

    Connections {
        target: MenuState
        function onCurrentChanged() {
            if (MenuState.current !== "builder") root.builderKeyboard = false;
            if (MenuState.current !== "") root.chromeAccessVisible = false;
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

    // The Platinum title bar's collapse box (modules/hyprland/titlebars.lua).
    // Hyprland cannot roll a window up to its title bar, so collapse hides
    // the focused window; its app's Show brings it back.
    IpcHandler {
        target: "windows"
        function collapseActive(): void {
            const t = Hyprland.activeToplevel;
            if (t && t.address) windowHider.hideWindow(t.address);
        }
    }

    IpcHandler {
        target: "themePicker"
        function open(): void { MenuState.close(); ThemePicker.open(root.focusedScreen()); }
        function hide(): void { ThemePicker.close(); }
    }

    // The omni bar. Its component lives in modules/omni.nix, which
    // QML resolves by filename from this directory.
    OmniBar { id: omniBarService }

    Heartbeat {}
    OptionalWebTheme {}

    // One owner for capture, queueing, backend work, insertion, and the
    // bottom-centre state overlay. The top bar only reads its public state.
    Dictation { id: dictationService }

    // The notification socket, and the popups. notifyd owns the D-Bus name;
    // see modules/notification-view.nix. Each top bar has its own centre.
    Notifications { id: notificationService }

    // Whether myoko accepts remote builds; see BuilderGate.qml. Hosts
    // without nix-builder-gate show no control.
    BuilderGate { id: builderGateService }

    // The fleet's health (Beszel), one owner for every screen's Fleet views.
    // It polls while a Desktop shows one; a theme without them never does.
    function anyDesktop(flag) {
        return Object.values(root.desktops).some(function (d) { return d && d[flag] === true; });
    }
    Beszel {
        id: beszelService
        shown: root.anyDesktop("fleetShown")
        detailShown: root.anyDesktop("fleetDetailShown")
    }
    // Fleet and glance routes go to the focused screen's Desktop; a theme
    // without them ignores them (Platinum and Win98 both have them).
    function fleetCall(method) {
        const screen = root.focusedScreen();
        const desktop = screen ? root.desktops[screen.name] : null;
        if (desktop && typeof desktop[method] === "function") desktop[method]();
    }

    // Super+B and Super+O F: the Fleet window.
    IpcHandler {
        target: "fleet"
        function toggle(): void { root.fleetCall("toggleFleet"); }
        function current(): string {
            return beszelService.state + " " + beszelService.fleet.tone + " " + beszelService.fleet.hosts.length
                + " problems=" + beszelService.fleet.problems.length + " stale=" + beszelService.stale
                + " window=" + (GlanceState.fleetScreen ? GlanceState.fleetScreen.name : "none");
        }
    }

    // Super+W: the glance space. Named reveal, not show (see chrome).
    IpcHandler {
        target: "glance"
        function toggle(): void { root.fleetCall("toggleGlance"); }
        function reveal(): void { root.fleetCall("showGlance"); }
        function hide(): void { root.fleetCall("hideGlance"); }
        // Review tools: hold the motion at ms (-1 runs again), "in" or "out";
        // play it n times slower.
        function seek(ms: int, direction: string): void { GlanceState.hold(ms, direction); }
        function slow(factor: int): void { GlanceState.slow = Math.max(1, factor); }
        function current(): string {
            return (GlanceState.glanceScreen ? "shown " + GlanceState.glanceScreen.name : "hidden")
                + " motion=" + (GlanceState.reducedMotion ? "reduced" : "full");
        }
    }

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
        function hide(): void { root.hideChrome(); }
        // Named reveal, not show: `qs ipc call chrome show` returns the
        // interface listing and does nothing, because `show` collides
        // with the qs CLI's own introspection verb. toggle and hide
        // both work, and Meta+I uses toggle.
        function reveal(): void { root.revealChrome(); }
        function open(control: string): void { root.openChrome(control); }
        // Super+Tab held (hyprland.lua): step <position> <seq>,
        // commit <position> <seq>, cancel 0 <seq>.
        function cycle(action: string, position: int, seq: string): void {
            root.cycleChrome(action, position, Number(seq));
        }
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
        function hide(): void { root.hideChrome(); }
        function reveal(): void { root.revealChrome(); }
        function open(control: string): void { root.openChrome(control); }
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
            if (event.name === "closewindow" || event.name === "activewindowv2"
                || event.name === "changefloatingmode" || event.name === "fullscreen") {
                positionRefresh.restart();
                return;
            }
            if (event.name !== "openwindow" && event.name !== "movewindowv2") return;
            dockToplevelRefresh.restart();
            Hyprland.refreshWorkspaces();
        }
    }

    // Where each window sits (lastIpcObject.at) orders a page's windows on
    // the Control Strip, so a swap moves the tiles with the windows.
    // Hyprland sends no event for a swap or a layout change, only for the
    // focus that comes with it, and the toplevel's IPC object is only
    // rewritten by a refresh. Measured in the nested session: after
    // window.swap the socket said only activewindow/activewindowv2.
    Timer {
        id: positionRefresh
        interval: 150
        repeat: false
        onTriggered: Hyprland.refreshToplevels()
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
            Quickshell.execDetached(["hyprctl", "--instance", "0", "--batch",
                'dispatch hl.dsp.focus({ window = "address:' + a + '" }) ; '
                + 'dispatch hl.dsp.window.swap({ target = "address:' + b + '" })']);
        } else {
            Quickshell.execDetached(["hyprctl", "--instance", "0", "dispatch",
                'hl.dsp.window.move({ window = "address:' + a + '", '
                + 'workspace = ' + toPage + ' })']);
        }
        positionRefresh.restart();
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
            // The glance space's Disks widget reads this owner too.
            StorageHealth { id: storageHealth; shown: screenScope.shows("disk") || GlanceState.glanceScreen === screenScope.modelData }
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

            readonly property var desktopContext: QtObject {
                readonly property var shell: root
                readonly property var bluetooth: bluetoothPanel
                readonly property var wifi: wifiPanel
                readonly property var sound: soundPanel
                readonly property var brightness: brightnessPanel
                readonly property var oci: ociEgress
                readonly property var storage: storageHealth
                readonly property var builder: builderPanel
                readonly property var centre: notificationCentre
                readonly property var notifications: notificationService
                readonly property var dictation: dictationService
                readonly property var omniBar: omniBarService
                readonly property var builderGate: builderGateService
                readonly property var beszel: beszelService
                readonly property var frontWindow: screenScope.frontWindow
                readonly property date now: clock.date
            }

            ThemeDesktop {
                screen: screenScope.modelData
                context: screenScope.desktopContext
                onDesktopChanged: root.registerDesktop(screen, desktop)
            }
        }
    }

}
