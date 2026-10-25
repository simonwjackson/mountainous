import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "lanes.js" as Lanes
import "app-model.js" as AppModel
import "themes/platinum/menu-models.js" as Menus
import "themes/platinum/strip-plan.js" as StripPlan

// One screen's complete chrome. Data owners outlive this theme instance.
Scope {
    id: desktop
    required property var screen
    required property var context
    required property var theme
    property bool active: false
    readonly property string diagnostics: " bar=" + PlatinumTokens.barSurface
        + " rule=" + (PlatinumTokens.barRuled ? PlatinumTokens.barRule : "none")

    function reveal() {
        context.shell.chromeVisible = true;
        context.shell.chromeAccessVisible = true;
    }
    function hide() { context.shell.chromeAccessVisible = false; }
    function open(control) {
        if (control === "theme") { MenuState.close(); ThemePicker.open(screen); return; }
        if (!menuMap[control]) return;
        if (control === "builder") context.shell.builderKeyboard = true;
        context.shell.openMenu(control, desktop.screen);
    }

    //----------------------------------------------------------------
    // Apps and windows, read from the shell's shared rows
    //----------------------------------------------------------------
    readonly property var shell: desktop.context.shell
    readonly property var rows: desktop.shell.windowRows || []
    readonly property var mru: desktop.shell.mru || []
    readonly property var hider: desktop.shell.hider || null
    readonly property string here: desktop.screen ? desktop.screen.name : ""
    readonly property string frontAddress: {
        const w = desktop.context.frontWindow;
        return w ? AppModel.key(w.address) : "";
    }
    readonly property var frontRow: {
        for (const r of desktop.rows) if (r.address === desktop.frontAddress) return r;
        return null;
    }
    readonly property string frontApp: desktop.frontRow ? desktop.frontRow.appId : ""

    // An app id's desktop entry gives its name and icon (a window class is
    // not an icon name: Chromium's class is chromium-browser, its icon
    // chromium; a --app web app's class is chrome-<host>__-Default).
    function entryFor(appId) {
        DesktopEntries.applications.values;
        return appId ? DesktopEntries.heuristicLookup(appId) : null;
    }
    function appName(appId) { const e = desktop.entryFor(appId); return e && e.name ? e.name : appId; }
    function appIcon(appId) { const e = desktop.entryFor(appId); return e && e.icon ? e.icon : appId; }
    readonly property var appNames: {
        const out = {};
        for (const r of desktop.rows) if (r.appId && !(r.appId in out)) out[r.appId] = desktop.appName(r.appId);
        return out;
    }
    readonly property var appIcons: {
        const out = {};
        for (const r of desktop.rows) if (r.appId && !(r.appId in out)) out[r.appId] = desktop.appIcon(r.appId);
        return out;
    }
    readonly property var apps: AppModel.apps(desktop.rows, desktop.mru, desktop.frontAddress, desktop.appNames, desktop.appIcons)

    // Every launch from these menus goes through Launcher: each app runs in
    // its own systemd scope, and Launcher records Recent Applications.
    readonly property var recent: Launcher.recent

    // The declared web apps (modules/web-apps.nix): desktop entries named
    // webapp-<id>, each with its lettermark icon.
    readonly property var webApps: DesktopEntries.applications.values
        .filter(function (e) { return e.id && e.id.indexOf("webapp-") === 0; })
        .map(function (e) { return { id: e.id.slice(7), name: e.name, icon: e.icon, entry: e }; })

    property string host: ""
    FileView { path: "/proc/sys/kernel/hostname"; blockLoading: true; printErrors: false
        onLoaded: desktop.host = text().trim() }

    readonly property var appleRows: Menus.apple({
        host: desktop.host,
        builder: desktop.context.builderGate.enabled === true,
        recent: desktop.recent,
        webApps: desktop.webApps
    })

    readonly property var applicationRows: Menus.application({
        apps: desktop.apps,
        front: desktop.frontAddress,
        frontApp: desktop.frontApp,
        frontName: desktop.frontApp ? desktop.appName(desktop.frontApp) : "",
        othersShown: desktop.rows.some(function (r) {
            return r.page > 0 && r.screen === desktop.here && r.appId !== desktop.frontApp;
        }),
        anyHidden: desktop.hider ? desktop.hider.hiddenCount > 0 : false,
        target: desktop.cycleTarget,
        here: desktop.here,
        screenLabel: Lanes.screenLabel
    })

    // The page this screen shows, for windows whose home page is unknown.
    function shownPage() {
        const monitor = Hyprland.monitors.values.find(function (m) { return m.name === desktop.here; });
        return monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1;
    }

    function activateWindow(address) {
        if (typeof desktop.shell.activate === "function") desktop.shell.activate(address);
    }

    // Choosing an app activates its most recent window; a hidden app is
    // shown first.
    function switchApp(appId) {
        const app = desktop.apps.find(function (a) { return a.appId === appId; });
        const w = AppModel.recentWindow(app, desktop.mru);
        if (!w) return;
        if (app.hiddenCount > 0 && desktop.hider) desktop.hider.showApp(appId, desktop.shownPage(), w.address);
        else desktop.activateWindow(w.address);
    }

    // A web app launches from its desktop entry's parsed command with web-app
    // metadata, so Recent Applications lists it as a web app; an entry without
    // a command falls back to launchEntry. A recent item launches its argv.
    function launchWebApp(app) {
        const meta = { id: "webapp-" + app.id, name: app.name || app.id, icon: app.icon || "", kind: "webapp" };
        const argv = app.entry && app.entry.command ? Array.from(app.entry.command) : [];
        if (argv.length > 0) Launcher.launch(argv, meta);
        else if (app.entry) Launcher.launchEntry(app.entry);
    }
    function launchRecent(e) {
        Launcher.launch(e.argv, { id: e.id, name: e.name, icon: e.icon || "", kind: e.kind });
    }

    // The commands behind the session items. hypridle locks before sleep.
    // They are short-lived system helpers, not apps, so they do not go
    // through Launcher; each argv is a literal, as launcher-model.test.js
    // requires of a detached helper.
    function runSession(what) {
        switch (what) {
        case "lock": Quickshell.execDetached(["loginctl", "lock-session"]); break;
        case "sleep": Quickshell.execDetached(["systemctl", "suspend"]); break;
        case "logout": Quickshell.execDetached(["hyprctl", "--instance", "0", "dispatch", "hl.dsp.exit()"]); break;
        case "restart": Quickshell.execDetached(["systemctl", "reboot"]); break;
        case "shutdown": Quickshell.execDetached(["systemctl", "poweroff"]); break;
        }
    }

    // One place runs every menu row's action. The menu closes first; the
    // action runs on the next turn of the event loop, once the menu that
    // emitted it is gone (it is destroyed while its signal is on the stack).
    function run(row) {
        const a = row ? row.action : null;
        if (!a) return;
        MenuState.close();
        Qt.callLater(desktop.perform, a);
    }
    function perform(a) {
        switch (a.kind) {
        case "open": desktop.open(a.control); break;
        case "about": desktop.aboutOpen = true; break;
        case "find": desktop.context.omniBar.enterRoot(); break;
        case "launchWebApp": desktop.launchWebApp(a.app); break;
        case "launchRecent": desktop.launchRecent(a.entry); break;
        case "session": desktop.runSession(a.what); break;
        case "confirm": desktop.confirming = a.what; break;
        case "hide": if (desktop.hider) desktop.hider.hideApp(a.appId); break;
        case "hideOthers": if (desktop.hider) desktop.hider.hideOthers(a.appId, desktop.here); break;
        case "showAll": if (desktop.hider) desktop.hider.showAll(desktop.shownPage()); break;
        case "switchApp": desktop.switchApp(a.appId); break;
        case "activate": desktop.activateWindow(a.address); break;
        case "close": if (typeof desktop.shell.closeWindow === "function") desktop.shell.closeWindow(a.address); break;
        case "moveTo": if (typeof desktop.shell.moveToPage === "function") desktop.shell.moveToPage(a.address, a.page); break;
        }
    }

    //----------------------------------------------------------------
    // Super+Tab held: cycle apps on the Application menu
    //----------------------------------------------------------------
    // hyprland.lua does the quick press itself (focus last window); a
    // second Tab while Super is down reaches here as step 2, and releasing
    // Super as commit with the final position. See app-model.js.
    property var cycleState: null
    property string cycleTarget: ""
    property bool cycleDropped: false
    function cycle(action, position) {
        if (action === "cancel") { desktop.endCycle(false); desktop.cycleDropped = false; return; }
        if (desktop.cycleDropped) {
            // The menu was closed by hand mid-cycle: ignore the rest of it.
            if (action === "commit") desktop.cycleDropped = false;
            return;
        }
        if (!desktop.cycleState) {
            desktop.cycleState = AppModel.cycleStart(desktop.rows, desktop.mru, desktop.appNames);
            desktop.context.shell.openMenu("app", desktop.screen);
        }
        desktop.cycleTarget = AppModel.cycleTarget(desktop.cycleState, position);
        if (action === "commit") desktop.endCycle(true);
    }
    function endCycle(commit) {
        const target = desktop.cycleTarget;
        const was = desktop.cycleState !== null;
        desktop.cycleState = null;
        desktop.cycleTarget = "";
        if (MenuState.current === "app" && MenuState.screen === desktop.screen) MenuState.close();
        if (was) console.debug("[platinum] app cycle " + (commit ? "commit " : "cancel ") + target);
        if (was && commit && target !== "") desktop.switchApp(target);
    }
    Connections {
        target: MenuState
        function onCurrentChanged() {
            if (desktop.cycleState && MenuState.current !== "app") {
                desktop.cycleState = null;
                desktop.cycleTarget = "";
                desktop.cycleDropped = true;
            }
        }
    }

    //----------------------------------------------------------------
    // The Control Strip's tile menu
    //----------------------------------------------------------------
    property string stripMenuAddress: ""
    property real stripMenuBottom: -1
    function openStripMenu(screen, address, x, bottom) {
        desktop.stripMenuAddress = address;
        desktop.stripMenuBottom = bottom;
        MenuState.open("strip", screen, x);
    }
    function stripMenuOpen(screen, address) {
        return MenuState.current === "strip" && MenuState.screen === screen && desktop.stripMenuAddress === address;
    }
    function dropTile(lane, from, to) {
        if (typeof desktop.shell.dropOnto === "function") desktop.shell.dropOnto(lane, from, to);
    }
    readonly property var stripRows: {
        const r = desktop.rows.find(function (x) { return x.address === desktop.stripMenuAddress; });
        if (!r) return [];
        const lane = desktop.rows.filter(function (x) { return x.page > 0 && x.screen === desktop.here; });
        const page = desktop.shownPage();
        return Menus.tile({
            window: r, appName: desktop.appName(r.appId), appIcon: desktop.appIcon(r.appId),
            front: r.toplevel ? r.toplevel.activated : false,
            shown: Lanes.isShown(r.toplevel),
            move: StripPlan.movePages(lane, r.page, page,
                typeof desktop.shell.pageIds === "function" ? desktop.shell.pageIds() : [])
        });
    }

    //----------------------------------------------------------------
    // About and the confirmation alerts
    //----------------------------------------------------------------
    property bool aboutOpen: false
    property string confirming: ""
    function endConfirm() { desktop.confirming = ""; }
    readonly property var alertSpec: Menus.alert(desktop.confirming, desktop.host)
    onActiveChanged: if (!active) { aboutOpen = false; confirming = ""; }

    LazyLoader {
        active: desktop.active && desktop.aboutOpen
        PlatinumAboutWindow {
            modelData: desktop.screen
            onCloseRequested: Qt.callLater(function () { desktop.aboutOpen = false; })
        }
    }

    LazyLoader {
        active: desktop.active && desktop.alertSpec !== null
        PlatinumAlert {
            modelData: desktop.screen
            spec: desktop.alertSpec
            // The alert is destroyed when confirming clears, so that is the
            // last thing each handler does, on the next turn of the loop.
            onCancelled: Qt.callLater(desktop.endConfirm)
            onAccepted: {
                desktop.runSession(desktop.confirming);
                Qt.callLater(desktop.endConfirm);
            }
        }
    }

    // The installed registry selects this theme's picker. The shared model
    // persists across PlatinumDesktop swaps; the view is destroyed with its theme.
    Loader {
        active: desktop.active && ThemePicker.visible && ThemePicker.screen === desktop.screen
        function loadView() {
            if (active) setSource(Qt.resolvedUrl(desktop.theme.picker),
                {screen: desktop.screen, model: ThemePicker});
        }
        onActiveChanged: loadView()
        Component.onCompleted: loadView()
    }

    Component { id: btMenu; PlatinumBluetoothMenu { panel: desktop.context.bluetooth } }
    Component { id: wifiMenu; PlatinumWifiMenu { panel: desktop.context.wifi } }
    Component { id: volMenu; PlatinumSoundMenu { panel: desktop.context.sound } }
    Component { id: briMenu; PlatinumBrightnessMenu { panel: desktop.context.brightness } }
    Component { id: ociMenu; PlatinumOciEgressMenu { panel: desktop.context.oci } }
    Component { id: diskMenu; PlatinumStorageHealthMenu { panel: desktop.context.storage } }
    Component { id: builderMenu; PlatinumBuilderMenu { panel: desktop.context.builder } }
    Component { id: ntfMenu; PlatinumNotificationCentreMenu { panel: desktop.context.centre } }

    // Fleet: its bar readout, the Fleet window and the glance space.
    PlatinumFleetGlance { id: fleetGlance; desktop: desktop; bar: topBar }
    readonly property bool fleetShown: fleetGlance.shown
    readonly property bool fleetDetailShown: fleetGlance.detailShown
    function toggleFleet() { fleetGlance.toggleFleet(); }
    function toggleGlance() { fleetGlance.toggleGlance(null); }
    function showGlance() { fleetGlance.showGlance(); }
    function hideGlance() { fleetGlance.hideGlance(); }

    PlatinumTopBar {
        id: topBar
        modelData: desktop.screen
        beszel: fleetGlance.beszel
        visible: desktop.active && desktop.context.shell.chromeVisible
        bluetooth: desktop.context.bluetooth
        wifi: desktop.context.wifi
        sound: desktop.context.sound
        brightness: desktop.context.brightness
        oci: desktop.context.oci
        storage: desktop.context.storage
        notifications: desktop.context.notifications
        dictation: desktop.context.dictation
        omniBar: desktop.context.omniBar
        frontWindow: desktop.context.frontWindow
        builderGate: desktop.context.builderGate
        now: desktop.context.now
        chordVisible: desktop.context.shell.chromeAccessVisible
    }

    // The shadow under this bar. It shows and hides with the bar.
    PlatinumBarShadow { bar: topBar }

    Component {
        id: clockMenu
        PlatinumClockMenu { now: desktop.context.now }
    }

    Component {
        id: overflowMenu
        PlatinumOverflowMenu { bar: topBar }
    }

    Component {
        id: appleMenu
        PlatinumCascadeMenu {
            items: desktop.appleRows
            onActivated: function (row) { desktop.run(row); }
        }
    }

    Component {
        id: applicationMenu
        PlatinumCascadeMenu {
            items: desktop.applicationRows
            alignRight: true
            highlightId: desktop.cycleTarget !== "" ? "app-" + desktop.cycleTarget : ""
            onActivated: function (row) { desktop.run(row); }
        }
    }

    Component {
        id: stripMenu
        PlatinumCascadeMenu {
            items: desktop.stripRows
            bottomY: desktop.stripMenuBottom
            onActivated: function (row) { desktop.run(row); }
        }
    }

    readonly property var menuMap: ({
            bt: btMenu,
            wifi: wifiMenu,
            vol: volMenu,
            bri: briMenu,
            oci: desktop.context.oci.enabled ? ociMenu : null,
            disk: desktop.context.storage.enabled ? diskMenu : null,
            fleet: fleetGlance.menu,
            ntf: ntfMenu,
            builder: desktop.context.builderGate.enabled ? builderMenu : null,
            clock: clockMenu,
            more: overflowMenu,
            apple: appleMenu,
            app: applicationMenu,
            strip: desktop.stripMenuAddress !== "" ? stripMenu : null
        })

    PlatinumMenuHost {
        enabled: desktop.active
        screen: desktop.screen
        bar: topBar
        menus: desktop.menuMap
    }

    // The Control Strip, in place of the dock.
    PlatinumControlStrip {
        modelData: desktop.screen
        shell: desktop.context.shell
        owner: desktop
        visible: desktop.active && desktop.context.shell.chromeVisible
    }
}
