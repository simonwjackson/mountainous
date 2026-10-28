// DEV HARNESS (not delivered): the real Win98Desktop, loaded by the real
// ThemeDesktop, with the production data owners (panels/) fed from the
// approved mock's state catalogue instead of D-Bus, PipeWire and Hyprland.
// Staged as shell.qml in a copy of modules/quickshell; win98-dev/ holds
// this folder. See capture.sh and behaviour.test.js.
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Wayland
import QtQuick
import "panels"
import "lanes.js" as Lanes
import "app-model.js" as AppModel
import "window-hide.js" as WindowHide
import "win98-dev/states.js" as States
import "win98-dev/find-states.js" as FindStates

ShellRoot {
    id: root

    property string stateId: "tb-normal"
    property var st: States.stateById(stateId) || { p: {} }
    property var dd: States.dataFor(stateId)
    // A Find window or Open dialog state (find-states.js), or null.
    property var findSt: FindStates.stateById(stateId)
    readonly property var screen0: Quickshell.screens[0]
    property var log: []
    function note(s) { root.log = root.log.concat([s]); console.log("harness:", s); }

    function obj(fields, extra) {
        const keys = Object.keys(fields);
        const src = "import QtQuick\nQtObject {\n" + keys.map(function (k) { return "property var " + k; }).join("\n")
            + "\nsignal connectionFailed(int reason)\n" + (extra || "") + "\n}";
        const o = Qt.createQmlObject(src, root);
        for (const k of keys) o[k] = fields[k];
        return o;
    }

    // ---- shell: the fields and helpers a Desktop reads from context.shell
    QtObject {
        id: shellStub
        property bool chromeVisible: true
        property bool chromeAccessVisible: false
        property bool builderKeyboard: false
        function windowsOn(screen) { return Lanes.windowsOn(root.toplevels, screen ? screen.name : ""); }
        function pageOf(t) { return Lanes.pageOf(t); }
        function dropOnto(windows, from, to) { root.note("drop " + from + " " + to); }
        function openMenu(name, screen) { MenuState.open(name, screen, -1); }
        function toggleMenu(name, screen) { MenuState.toggle(name, screen, -1); }
        function closeMenu(name) { if (MenuState.current === name) MenuState.close(); }
        // shell.qml's window rows and actions over the fixture's windows
        // (the hide/show owner below moves them between workspaces).
        readonly property var windowRows: root.toplevels.map(function (t) { return root.rowOf(t); })
        readonly property var mru: root.mru
        readonly property var hider: hiderStub
        readonly property var motion: motionStub
        function addressOf(t) { return t && t.lastIpcObject ? t.lastIpcObject.address : ""; }
        function rowOf(t) { return root.rowOf(t); }
        function rowFor(address) { const k = AppModel.key(address); return windowRows.find(function (r) { return r.address === k; }) || null; }
        function activate(address) { const i = root.indexOf(address); if (i >= 0) { root.focus(i); root.note("activate " + i); } }
        function closeWindow(address) { const i = root.indexOf(address); if (i >= 0) root.note("close " + i); }
        function moveToPage(address, page) { const i = root.indexOf(address); if (i < 0) return; root.note("move " + i + " " + page); const t = root.toplevels[i]; t.workspace = root.pageWs(page, t.workspace && t.workspace.monitor ? t.workspace.monitor.name : ""); }
        function pageIds() { return root.toplevels.map(function (t) { return t.workspace ? t.workspace.id : -1; }).filter(function (id) { return id > 0; }); }
        function shownPageOn(name) { return root.dd.showingPage; }
    }

    // ---- WindowMotion's public shape: the motion IPC below sends its events.
    QtObject {
        id: motionStub
        signal requested(var e)
        property real held: -1
        property real slow: 1
    }
    // A stand-in app window under the chrome, for the motion captures: a
    // Win98 window or a Platinum one at a client rect (Hyprland's at/size).
    property var fakeWindow: null
    PanelWindow {
        id: fakeWin
        readonly property real u: Win98Tokens.unitFor(fakeWin)
        readonly property var f: root.fakeWindow
        readonly property bool win98: Theme.name === "win98"
        // The frame around the client: Win98's 3-u frame and 18-u caption
        // with its seam, Platinum's 20-px title bar.
        readonly property var frame: !f ? null : win98
            ? { x: f.rect[0] - 3 * u, y: f.rect[1] - 22 * u, w: f.rect[2] + 6 * u, h: f.rect[3] + 25 * u }
            : { x: f.rect[0], y: f.rect[1] - 20, w: f.rect[2], h: f.rect[3] + 20 }
        screen: root.screen0
        visible: !!f
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "harness-app"
        color: "transparent"
        mask: Region {}
        Win98Window {
            visible: fakeWin.win98 && !!fakeWin.frame
            x: fakeWin.frame ? fakeWin.frame.x : 0
            y: fakeWin.frame ? fakeWin.frame.y : 0
            width: fakeWin.frame ? fakeWin.frame.w : 0
            height: fakeWin.frame ? fakeWin.frame.h : 0
            title: fakeWin.f ? fakeWin.f.title : ""
            active: !!fakeWin.f && fakeWin.f.active !== false
            margins: false
            Rectangle { width: parent ? parent.width : 0; height: parent ? parent.height : 0; color: Win98Tokens.win }
        }
        Rectangle {
            visible: !fakeWin.win98 && !!fakeWin.frame
            x: fakeWin.frame ? fakeWin.frame.x : 0
            y: fakeWin.frame ? fakeWin.frame.y : 0
            width: fakeWin.frame ? fakeWin.frame.w : 0
            height: fakeWin.frame ? fakeWin.frame.h : 0
            color: "#ffffff"
            border.width: PlatinumTokens.hair
            border.color: "#000000"
            Rectangle {
                width: parent.width; height: 20
                color: PlatinumTokens.menuSurface
                border.width: PlatinumTokens.hair
                border.color: "#000000"
                Text {
                    anchors.centerIn: parent
                    text: fakeWin.f ? fakeWin.f.title : ""
                    color: PlatinumTokens.menuText
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumSmall
                }
            }
        }
    }

    // ---- WindowHider's public shape, with window-hide.js's own rules; its
    // moves land on the fixture's windows instead of Hyprland.
    QtObject {
        id: hiderStub
        property var state: WindowHide.empty()
        readonly property int hiddenCount: WindowHide.hiddenRows(shellStub.windowRows).length
        function run(result, focusIndex) {
            const before = hiderStub.state;
            hiderStub.state = result.state;
            for (const m of result.moves) {
                const i = root.indexOf(m.address);
                if (i < 0) continue;
                const t = root.toplevels[i];
                const home = before.windows[WindowHide.key(m.address)];
                if (typeof m.workspace === "number") { t.workspace = root.pageWs(m.workspace, home ? home.screen : ""); root.note("show " + i + " " + m.workspace); }
                else { t.workspace = { id: -98, name: m.workspace, active: false, monitor: t.workspace ? t.workspace.monitor : root.monitor }; t.activated = false; root.note("hide " + i); }
            }
            if (focusIndex >= 0) root.focus(focusIndex);
            return result.moves.length;
        }
        function hideWindow(a) { return run(WindowHide.hideWindow(state, shellStub.windowRows, a), -1); }
        function hideApp(id) { return run(WindowHide.hideApp(state, shellStub.windowRows, id), -1); }
        function hideScreen(name) { return run(WindowHide.hideScreen(state, shellStub.windowRows, name), -1); }
        function hideOthers(id, name) { return run(WindowHide.hideOthers(state, shellStub.windowRows, id || "", name || ""), -1); }
        function showWindow(a, page, focus, after) {
            const n = run(WindowHide.showWindow(state, shellStub.windowRows, a, page), focus ? root.indexOf(a) : -1);
            if (after) root.note("after " + after);
            return n;
        }
        function showApp(id, page, a) { return run(WindowHide.showApp(state, shellStub.windowRows, id, page), a ? root.indexOf(a) : -1); }
        function showAll(page) { return run(WindowHide.showAll(state, shellStub.windowRows, page), -1); }
        function setHome(a, page) { state = WindowHide.setHome(state, shellStub.windowRows, a, page); root.note("home " + root.indexOf(a) + " " + page); }
        function homeOf(a) { return WindowHide.homeOf(state, a); }
        function isHidden(row) { return !!row && WindowHide.isHiddenWorkspace(row.workspace); }
    }

    // ---- windows: Hyprland toplevels' shape (lanes.js)
    property var toplevels: []
    property var monitor: ({ name: "" })
    property var monitors: ({})
    property var pages: ({})
    // The state's windows: the Find states' own lists, else the mock's.
    function windowList() { return FindStates.windowsFor(root.stateId) || root.dd.windows; }
    // Most recently used first: the focused window, then the fixture's order.
    property var mru: []
    function rowOf(t) {
        const ws = t.workspace;
        const o = t.lastIpcObject || {};
        return { address: AppModel.key(o.address), appId: t.wayland ? t.wayland.appId : "", title: t.title || "",
            page: ws ? ws.id : -1, workspace: ws ? ws.name : "", screen: ws && ws.monitor ? ws.monitor.name : "",
            x: o.at ? o.at[0] : undefined, y: o.at ? o.at[1] : undefined, toplevel: t };
    }
    function indexOf(address) {
        const k = AppModel.key(address);
        return root.toplevels.findIndex(function (t) { return AppModel.key(t.lastIpcObject.address) === k; });
    }
    // One workspace object per screen and page, as Hyprland has.
    function pageWs(page, screen) {
        const name = screen || root.monitor.name;
        if (!root.monitors[name]) {
            const m = Object.assign({}, root.monitors);
            m[name] = name === root.monitor.name ? root.monitor : { name: name };
            root.monitors = m;
        }
        const key = name + ":" + page;
        if (!root.pages[key]) {
            const next = Object.assign({}, root.pages);
            next[key] = { id: page, name: String(page), active: page === root.dd.showingPage, monitor: root.monitors[name] };
            root.pages = next;
        }
        return root.pages[key];
    }
    function focus(i) {
        root.toplevels.forEach(function (t, j) { t.activated = j === i; });
        if (root.toplevels[i]) root.mru = AppModel.touch(root.mru, root.toplevels[i].lastIpcObject.address);
    }
    function appId(icon) {
        return ({ term: "com.mitchellh.ghostty", chromium: "chromium-browser", signal: "signal", zed: "dev.zed.Zed",
            obs: "com.obsproject.Studio", tx: "transmission-gtk", firefox: "firefox", sun: "sunshine", sync: "syncthing" })[icon] || icon;
    }
    function buildWindows() {
        const name = root.screen0 ? root.screen0.name : "";
        root.monitor = { name: name };
        root.monitors = ({});
        root.pages = ({});
        hiderStub.state = WindowHide.empty();
        // Each window stands where its fixture says (Hyprland's at), or in
        // a column of the screen, 600 px wide, 40 px down, so the windows
        // IPC has a corner to use. A fixture may put a window on another
        // screen (the Find window's two-screen states).
        root.toplevels = root.windowList().map(function (w, i) {
            return root.obj({ title: w.title, activated: !!w.focused, urgent: !!w.urgent, workspace: root.pageWs(w.page, w.screen || name),
                lastIpcObject: { address: "0x" + (1000 + i), at: w.at || [4 + (i % 3) * 600, 40], size: w.size, fullscreen: w.max ? 1 : 0 },
                wayland: root.handle(w.appId || root.appId(w.icon), i) });
        });
        const order = root.toplevels.map(function (t) { return AppModel.key(t.lastIpcObject.address); });
        const f = root.windowList().findIndex(function (w) { return !!w.focused; });
        root.mru = f >= 0 ? [order[f]].concat(order.filter(function (k, j) { return j !== f; })) : order;
    }
    // A Wayland toplevel handle whose activate() and close() the log records.
    function handle(appId, i) {
        const o = root.obj({ appId: appId },
            "signal didActivate()\nsignal didClose()\nfunction activate() { didActivate(); }\nfunction close() { didClose(); }");
        o.didActivate.connect(function () { root.focus(i); root.note("activate " + i); });
        o.didClose.connect(function () { root.note("close " + i); });
        return o;
    }

    // ---- Bluetooth
    property var btAdapter: {
        const b = root.dd.bt;
        if (!b.adapter) return null;
        const devs = b.devices.map(function (d) {
            return root.obj({ name: d.name || "", address: d.address, connected: !!d.connected, paired: !!d.paired,
                pairing: !!d.pairing, trusted: false, state: d.connected ? BluetoothDeviceState.Connected : BluetoothDeviceState.Disconnected,
                batteryAvailable: d.battery !== undefined, battery: (d.battery || 0) / 100, pairFailed: !!d.pairFailed });
        });
        return root.obj({ enabled: b.enabled, discovering: !!b.discovering,
            state: b.astate === "blocked" ? BluetoothAdapterState.Blocked : b.enabled ? BluetoothAdapterState.Enabled : BluetoothAdapterState.Disabled,
            devices: { values: devs } });
    }

    // ---- Wi-Fi
    property var wifiDevice: {
        const w = root.dd.wifi;
        if (!w.device) return null;
        const nets = w.networks.map(function (n) {
            const sec = n.security === "open" ? WifiSecurityType.Open : n.security === "enterprise" ? WifiSecurityType.Wpa2Eap : WifiSecurityType.Wpa2Psk;
            return root.obj({ name: n.name, signalStrength: n.signal, connected: !!n.connected, known: !!n.known, security: sec,
                state: n.state === "connecting" ? ConnectionState.Connecting : n.connected ? ConnectionState.Connected : ConnectionState.Disconnected,
                stateChanging: n.state === "connecting" });
        });
        return root.obj({ scannerEnabled: !!w.scanning, networks: { values: nets } });
    }

    // ---- Sound: nodes whose volume the window really changes
    function node(n, sink) {
        return root.obj({ description: n.name, nickname: "", name: n.name, isSink: sink, isStream: false,
            audio: root.obj({ volume: n.vol, muted: !!n.muted }) });
    }
    property var outs: root.dd.sound.outputs.map(function (n) { return root.node(n, true); })
    property var ins: root.dd.sound.inputs.map(function (n) { return root.node(n, false); })

    // ---- the notification service's public shape
    QtObject {
        id: notes
        property var items: []
        property var view: ({ kind: "ready" })
        property var status: ({ server: "connected", outbox: 0, last_error: null })
        property int count: items.length
        property var expandedIds: ({})
        property string socketPath: "/run/user/1000/notify-sync/ui.sock"
        function dismissAll() { root.note("dismissAll"); }
        function dismiss(id) { root.note("dismiss " + id); }
        function invoke(id, key) { root.note("invoke " + id + " " + key); }
        function toggleExpanded(id) { root.note("expand " + id); }
        function reconnectNow() { root.note("reconnect"); }
        function takeFocusRequest() { return { kind: "none" }; }
    }

    QtObject {
        id: dict
        property string state: "idle"
        property bool barVisible: false
        property string statusText: ""
        property string backendLabel: ""
        property int queueCount: 0
        property string queueText: queueCount + " takes"
        property bool canRetry: false
        function retryFailed() { root.note("retry"); }
        function dismissFailure() { root.note("dismiss dictation"); }
    }

    // The omni service's public shape (OmniFixture.qml), fed by find-states.js.
    OmniFixture {
        id: omni
        screen0: root.screen0
        onNote: text => root.note(text)
    }
    // The service's rows for a Find state: the windows behind the focused
    // one, grouped by screen as OmniBar.windowRows; the mock's apps, recent
    // launches and open pages.
    function feedOmni() {
        const here = root.screen0 ? root.screen0.name : "";
        const out = [];
        root.toplevels.forEach(function (t, i) {
            if (t.activated) return;
            out.push({ kind: "window", label: t.title, detail: "", page: t.workspace.id, shown: !!t.workspace.active,
                appId: t.wayland.appId, order: i, screen: t.workspace.monitor.name, toplevel: t, entry: null });
        });
        omni.windowRows = Lanes.groupRows(out, here);
        omni.appRows = FindStates.APPS;
        Launcher._recent = root.findSt && root.findSt.noRecent ? [] : FindStates.RECENT;
        CdpBrowser.pages = FindStates.PAGES;
        const f = root.findSt;
        const caller = f && f.caller !== undefined ? f.caller : root.toplevels.findIndex(function (t) { return t.activated; });
        omni.active = caller >= 0 ? root.toplevels[caller] : null;
    }
    // Open the state's Find window or Open dialog, then set what the keys
    // and the pointer would have (Look in open, the drop-down, the tip).
    function playFind() {
        const f = root.findSt;
        if (!f) return;
        omni.dismiss();
        MenuState.close();
        Qt.callLater(function () {
            if (f.mode === "nav") omni.enterNavigate(f.typed || f.query || "");
            else omni.enterMode(f.mode, f.query || "");
            findLater.restart();
        });
    }
    Timer {
        id: findLater
        interval: 100
        repeat: true
        property int tries: 0
        onRunningChanged: if (running) tries = 0
        onTriggered: {
            const f = root.findSt, item = root.desktop ? root.desktop.openItem : null;
            tries++;
            const want = f && f.mode === "nav" ? "Win98OpenDialog" : "Win98FindWindow";
            if (!f || tries > 50) { stop(); return; }
            if (!item || String(item).indexOf(want) < 0) return;
            stop();
            if (f.drop !== undefined) { item.dropOpen = true; item.dropIndex = f.drop; }
            for (let i = 0; i < (f.steps || 0); i++) item.move(1);
            if (f.tip) item.tipIndex = item.current;
            if (f.list) { item.listOpen = true; item.pick = f.pick === undefined ? -1 : f.pick; }
            root.findReady = root.stateId;
        }
    }
    property string findReady: ""

    QtObject {
        id: gate
        property var sample: ({ kind: "loading" })
        property string pending: ""
        property var actionError: null
        readonly property bool enabled: sample.kind === "ready" || sample.kind === "error"
        function refresh() {}
        function run(command) { root.note("gate " + command); }
    }

    BluetoothPanel { id: bt; adapter: root.btAdapter; shown: MenuState.current === "bt" }
    WifiPanel {
        id: wifi
        device: root.wifiDevice
        radioEnabled: root.dd.wifi.enabled
        hardwareEnabled: root.dd.wifi.hw
        shown: MenuState.current === "wifi"
    }
    SoundPanel {
        id: sound
        shown: MenuState.current === "vol"
        pipewireReady: root.dd.sound.ready
        outputs: root.outs
        inputs: root.ins
        defaultSink: root.outs.find(function (n, i) { return root.dd.sound.outputs[i].def; }) || null
        defaultSource: root.ins.find(function (n, i) { return root.dd.sound.inputs[i].def; }) || null
    }
    BrightnessPanel { id: bri; shown: MenuState.current === "bri" }
    OciEgress { id: oci; enabled: root.dd.ociEnabled }
    StorageHealth {
        id: storage
        enabled: root.dd.diskEnabled
        // The real 30-second timer must not turn a shot stale mid-sweep.
        onNowChanged: {
            const fixed = new Date(2026, 9, 22, 16, 51).getTime();
            if (now !== fixed) now = fixed;
        }
    }
    BuilderPanel { id: builderPanel; gate: gate; shown: MenuState.current === "builder"; openedByKeyboard: shellStub.builderKeyboard }
    NotificationCentre { id: centre; service: notes; shown: MenuState.current === "ntf" }

    // The Fleet views' data: the production Beszel owner over the
    // beszel-status stand-in (beszel-stub.js), polling as shell.qml has it.
    Beszel {
        id: fleetData
        shown: !!root.desktop && root.desktop.fleetShown === true
        detailShown: !!root.desktop && root.desktop.fleetDetailShown === true
    }
    FileView {
        id: fleetFixtureFile
        path: Quickshell.env("XDG_STATE_HOME") + "/fleet-fixture"
        printErrors: false
    }
    // A fixture: written for the stand-in, then a refresh. Loading has no
    // answer; rakku-down and error have no sample; stale is a good sample
    // followed by a failed refresh, three minutes later.
    property string fleetFixture: ""
    function setFleet(name) {
        root.fleetFixture = name;
        fleetFixtureFile.setText(name + "\n");
        if (name === "loading") { fleetData.systems = null; fleetData.sampleState = "loading"; fleetData.details = ({}); return; }
        if (name === "rakku-down" || name === "error") { fleetData.systems = null; fleetData.details = ({}); }
        fleetLater.restart();
    }
    Timer {
        id: fleetLater
        interval: 150
        onTriggered: {
            fleetData.refresh();
            fleetData.refreshDetail();
            if (root.fleetFixture === "stale") staleLater.restart();
        }
    }
    Timer {
        id: staleLater
        interval: 800
        onTriggered: {
            fleetFixtureFile.setText("stale-fail\n");
            Qt.callLater(function () { fleetData.refresh(); fleetData.sampledAt = Date.now() - 192000; });
        }
    }

    QtObject {
        id: context
        readonly property var shell: shellStub
        readonly property var bluetooth: bt
        readonly property var wifi: wifi
        readonly property var sound: sound
        readonly property var brightness: bri
        readonly property var oci: oci
        readonly property var storage: storage
        readonly property var builder: builderPanel
        readonly property var centre: centre
        readonly property var notifications: notes
        readonly property var dictation: dict
        readonly property var omniBar: omni
        readonly property var builderGate: gate
        readonly property var beszel: fleetData
        readonly property var frontWindow: root.toplevels.find(function (t) { return t.activated; }) || null
        readonly property date now: new Date(2026, 9, 22, 16, 51)
    }

    ThemeDesktop {
        id: loader
        screen: root.screen0
        context: context
        // A new Desktop (a theme swap) gets the data, not the state's open
        // menus: a swap closes menus, and the checks open their own.
        onDesktopChanged: Qt.callLater(function () { root.apply(false); })
    }
    readonly property var desktop: loader.desktop
    readonly property var fixtureContext: context

    // A second screen (scales.sh adds one): its own Desktop, so each screen's
    // taskbar draws in its own unit.
    Loader {
        active: Quickshell.screens.length > 1
        sourceComponent: ThemeDesktop {
            screen: Quickshell.screens[1]
            context: root.fixtureContext
        }
    }

    // The mock's apps (data.js PROGRAMS), as DesktopEntries would list them.
    function apps() {
        const cat = { Accessories: "Utility", Development: "Development", Internet: "Network", Multimedia: "AudioVideo", System: "System" };
        if (root.dd.flatPrograms) return States.MANY_APPS.map(function (n) { return { id: n.toLowerCase(), name: n, categories: [] }; });
        const out = [];
        for (const folder in States.PROGRAMS)
            for (const app of States.PROGRAMS[folder]) out.push({ id: root.appId(app[1]), name: app[0], categories: [cat[folder]] });
        return out;
    }

    // Recent Applications (Launcher.recent's shape) and the pinned web apps
    // (desktop entries webapp-<id>), as the parity mock lists them.
    property bool recentEmpty: false
    readonly property var recentFixture: [
        { id: "dev.zed.Zed", name: "Zed", icon: "dev.zed.Zed", kind: "app", argv: ["zeditor"], lastLaunched: 5 },
        { id: "webapp-ytmusic", name: "YouTube Music", icon: "webapp-ytmusic", kind: "webapp", argv: ["chromium", "--app=https://music.youtube.com"], lastLaunched: 4 },
        { id: "signal", name: "Signal", icon: "signal", kind: "app", argv: ["signal-desktop"], lastLaunched: 3 },
        { id: "com.mitchellh.ghostty", name: "Ghostty", icon: "com.mitchellh.ghostty", kind: "app", argv: ["ghostty"], lastLaunched: 2 },
        { id: "com.obsproject.Studio", name: "OBS Studio", icon: "com.obsproject.Studio", kind: "app", argv: ["obs"], lastLaunched: 1 }
    ]
    readonly property var webAppFixture: [
        { id: "github", name: "GitHub", icon: "webapp-github", entry: { command: ["chromium", "--app=https://github.com"] } },
        { id: "ytmusic", name: "YouTube Music", icon: "webapp-ytmusic", entry: { command: ["chromium", "--app=https://music.youtube.com"] } },
        { id: "gmail", name: "Gmail", icon: "webapp-gmail", entry: { command: ["chromium", "--app=https://mail.google.com"] } }
    ]
    // App names for naming pages (the fixture's own; DesktopEntries in a
    // sandbox has none).
    function seedNames() {
        if (!root.desktop || !root.desktop.theme || root.desktop.theme.id !== "win98") return;
        const names = {};
        for (const w of root.windowList()) names[w.appId || root.appId(w.icon)] = w.app || w.title;
        root.desktop.appNames = names;
    }
    function seedLists() {
        root.seedNames();
        if (!root.desktop || !root.desktop.theme || root.desktop.theme.id !== "win98") return;
        root.desktop.recent = root.recentEmpty ? [] : root.recentFixture;
        root.desktop.webApps = root.recentEmpty ? [] : root.webAppFixture;
    }

    function apply(view) {
        const d = root.dd, p = root.st.p || {};
        root.buildWindows();
        root.seedLists();
        // notifications
        const now = new Date(2026, 9, 22, 16, 51).getTime();
        notes.items = d.ntf.items.map(function (it, i) {
            return Object.assign({ id: 100 + i, seq: "s" + i, app_icon: "", local_only: false, resident: false }, it,
                { created: now - it.updated * 60000, updated: now - it.updated * 60000,
                  // A real picture for the mock's image card.
                  image: it.image ? Qt.resolvedUrl("themes/win98/previews/light.png").toString() : null });
        });
        notes.status = d.ntf.status;
        notes.view = d.ntf.conn === "offline" ? { kind: "offline", retryInSeconds: d.ntf.retryIn }
            : d.ntf.conn !== "connected" ? { kind: "connecting" } : notes.items.length ? { kind: "ready" } : { kind: "empty" };
        // dictation
        const dd = d.dict;
        dict.state = dd.state;
        dict.barVisible = ["recording", "working", "failed"].indexOf(dd.state) >= 0;
        dict.statusText = dd.state === "recording" ? "Recording" : dd.state === "working" ? "Working"
            : dd.state === "failed" ? (dd.failureKind === "recorder" ? "Microphone failed" : "Dictation failed") : "";
        dict.backendLabel = dd.state === "recording" || !dd.backend ? "" : dd.backend === "zao" ? "Zao" : "Groq";
        dict.queueCount = dd.queue || 0;
        dict.canRetry = !!dd.canRetry;
        // builder
        gate.sample = d.builder.sample;
        gate.pending = d.builder.pending;
        gate.actionError = d.builder.actionError;
        shellStub.builderKeyboard = !!d.builder.keyboard;
        // brightness
        bri.level = d.bri.level;
        bri.panelFollows = d.bri.level >= 0;
        bri.monitors = d.bri.level >= 0 ? [{ manufacturer: "", model: "x" }] : [];
        bri.rows = d.bri.rows;
        // oci
        oci.rows = d.oci.rows;
        oci.state = d.oci.state;
        // storage
        storage.sampleState = d.disk.state === "stale" ? "ready" : d.disk.state;
        storage.checkedAt = d.disk.state === "stale" ? new Date(2026, 9, 22, 15, 20) : new Date(2026, 9, 22, 16, 47);
        storage.now = new Date(2026, 9, 22, 16, 51).getTime();
        storage.setFindings(d.disk.rows);
        // After the window opens: showing it clears both (WifiPanel).
        wifiLater.restart();
        root.findReady = "";
        root.feedOmni();
        shellStub.chromeAccessVisible = !!d.chord;
        if (!root.desktop) return;
        const desk = root.desktop;
        if (desk.preview === undefined || view === false) {
            if (desk.preview !== undefined) {
                desk.battery = { present: d.bat.present, percent: d.bat.pct, charging: !!d.bat.charging, full: !!d.bat.full, onBattery: d.bat.onBattery };
                desk.apps = root.apps();
            }
            return;
        }
        desk.battery = { present: d.bat.present, percent: d.bat.pct, charging: !!d.bat.charging, full: !!d.bat.full, onBattery: d.bat.onBattery };
        desk.apps = root.apps();
        root.seedNames();
        // The view's state: hover, press, focus, tooltip, flash, drag.
        const id = function (c) { return c === "win1" ? "win1" : c; };
        const preview = {};
        if (p.hov) preview.hover = id(p.hov);
        if (p.press) preview.press = id(p.press);
        if (p.focus) preview.focus = id(p.focus);
        if (p.tip) preview.tip = id(p.tip);
        if (p.flash) preview.flash = p.flash;
        if (p.drag) preview.drag = true;
        // A cursor in the Start menu (kc), and the open cascade.
        const parts = p.open ? String(p.open).split(":") : [];
        if (parts[0] === "start") {
            const path = [];
            let items = desk.startModel;
            for (const key of parts.slice(1)) {
                const k = key.toLowerCase();
                const i = items.findIndex(function (it) { return it.text && it.text.replace(/&/g, "").toLowerCase() === k
                    || (k === "scale" && it.text === "Interface scale"); });
                if (i < 0) break;
                path.push(i);
                items = items[i].submenu || [];
            }
            preview.startPath = path;
            if (p.kc !== undefined) {
                const sel = [];
                items.forEach(function (it, i) { if (!it.separator) sel.push(i); });
                preview.startCursor = Number(p.kc) >= 0 ? sel[Number(p.kc)] : -1;
            }
        }
        desk.preview = preview;
        MenuState.close();
        ThemePicker.close();
        if (parts[0]) Qt.callLater(function () {
            MenuState.open(parts[0], root.screen0, -1);
            if (p.anchor) desk.anchorId = p.anchor;
        });
        if (p.win === "logoff") Qt.callLater(function () { MenuState.open("logoff", root.screen0, -1); });
        if (root.findSt) root.playFind();
        if (p.win === "picker") Qt.callLater(function () {
            ThemePicker.open(root.screen0);
            root.pickerState = { theme: p.pt === "platinum" ? "platinum" : "win98", scheme: p.ps === "grey" ? "dark" : p.ps || undefined,
                drop: p.pdrop, applyFocus: !!p.pf };
        });
    }
    Timer {
        id: wifiLater
        interval: 200
        onTriggered: {
            const d = root.dd;
            if (root.st.p && root.st.p.section) sound.section = root.st.p.section;
            wifi.failureMessage = d.wifi.failure || "";
            wifi.passwordNetwork = d.wifi.password && root.wifiDevice
                ? root.wifiDevice.networks.values.find(function (n) { return n.name === d.wifi.password; }) || null : null;
        }
    }
    property real cycleSeq: 0
    function volumeNow() { return sound.defaultSink ? String(Math.round(sound.defaultSink.audio.volume * 100)) : "-"; }
    property var pickerState: null
    Timer {
        interval: 300
        running: root.pickerState !== null
        onTriggered: {
            const views = root.findPicker();
            if (views) views.show(root.pickerState);
            root.pickerState = null;
        }
    }
    // The picker's view object.
    function findPicker() { return root.desktop ? root.desktop.pickerView : null; }

    onStateIdChanged: Qt.callLater(apply)
    Component.onCompleted: Qt.callLater(apply)

    IpcHandler {
        target: "w98"
        function set(id: string): string { if (root.stateId === id) Qt.callLater(root.apply); else root.stateId = id; return id; }
        function theme(mode: string): void { Theme.mode = mode; }
        function current(): string {
            const d = root.desktop;
            const p = root.st.p || {};
            const want = p.open ? String(p.open).split(":")[0] : p.win === "logoff" ? "logoff" : "";
            const settled = root.findSt ? root.findReady === root.stateId : MenuState.current === want && (p.win !== "picker" || ThemePicker.visible);
            return JSON.stringify({ state: root.stateId, settled: settled, theme: Theme.name, loaded: loader.currentName, slots: loader.loadedCount, open: MenuState.current,
                picker: ThemePicker.visible, steps: d && d.taskbarPlan ? d.taskbarPlan().steps : [], log: root.log });
        }
        // The Start menu's open path and cursor, by name.
        function menu(): string {
            const m = root.desktop ? root.desktop.openItem : null;
            if (!m || m.path === undefined) return "path= cursor=- open=" + MenuState.current;
            const names = [];
            let items = m.model;
            for (const i of m.path) { names.push(Win98Tokens.plainText(items[i].text)); items = items[i].submenu || []; }
            const cur = m.cursor >= 0 && items[m.cursor] ? Win98Tokens.plainText(items[m.cursor].text) : "-";
            return "path=" + names.join("/") + " cursor=" + cur + " open=" + MenuState.current;
        }
        // The centre of a Start menu row, in screen logical px: "level text".
        function item(level: int, text: string): string {
            const m = root.desktop ? root.desktop.openItem : null;
            const panel = m && m.panelAt ? m.panelAt(level) : null;
            if (!panel) return "";
            const i = panel.items.findIndex(function (it) { return it.text && Win98Tokens.plainText(it.text) === text; });
            if (i < 0) return "";
            const p = panel.mapToItem(null, panel.rowX(i) + panel.columnWidth / 2, panel.rowY(i) + panel.rowH / 2);
            return Math.round(p.x) + " " + Math.round(p.y);
        }
        // The centre of a picker control by objectName, in screen logical px.
        function control(name: string): string {
            const find = function (item) {
                if (!item) return null;
                if (item.objectName === name) return item;
                for (let i = 0; i < item.children.length; i++) { const f = find(item.children[i]); if (f) return f; }
                return null;
            };
            const view = root.findPicker();
            const it = view ? find(view.contentItem) : null;
            if (!it) return "";
            const p = it.mapToItem(null, it.width / 2, it.height / 2);
            return Math.round(p.x) + " " + Math.round(p.y);
        }
        // Where everything stands, in screen logical px (geometry.sh).
        function geometry(): string {
            const d = root.desktop, scr = root.screen0;
            if (!d || !d.debugPlaces) return "{}";
            const rect = function (it) {
                const q = it.mapToItem(null, 0, 0);
                return { x: q.x, y: q.y, w: it.width, h: it.height };
            };
            const out = { w: scr.width, h: scr.height, places: d.debugPlaces(), plan: d.taskbarPlan(), panels: [], window: null, picker: null, openIs: String(d.openItem) };
            const m = d.openItem;
            if (m && m.panelAt) {
                for (let l = 0; l < 8; l++) { const p = m.panelAt(l); if (!p) break; const r = rect(p); r.scrolls = !!p.scrolls; r.scrollY = p.scrollY || 0; out.panels.push(r); }
            } else if (m) {
                out.window = rect(m);
                out.window.natural = m.implicitHeight;
                out.window.scrolls = !!m.scrolls;
            }
            // The Shut Down dialog and its buttons, the Cool Switch box,
            // the pop-up, and named controls inside the open window.
            const named = function (top, n) {
                if (!top) return null;
                if (top.objectName === n && top.visible !== false) return top;
                for (let i = 0; i < top.children.length; i++) { const f = named(top.children[i], n); if (f) return f; }
                return null;
            };
            if (d.shutDownItem) {
                out.shutdown = rect(d.shutDownItem);
                out.shutdown.scrolls = !!d.shutDownItem.scrolls;
                for (const n of ["shutDownOk", "shutDownCancel", "shutDown-standby", "shutDown-logoff"]) {
                    const it = named(d.shutDownItem, n);
                    out.shutdown[n] = it ? rect(it) : null;
                }
            }
            if (m && out.window) for (const n of ["systemOk", "systemCancel", "systemFacts"]) {
                const it = named(m, n);
                if (it) out.window[n] = rect(it);
            }
            if (d.coolSwitchItem) out.cool = rect(d.coolSwitchItem);
            if (d.popupItem) out.popup = rect(d.popupItem);
            const v = root.findPicker();
            if (v) {
                const find = function (item, name) {
                    if (!item) return null;
                    if (item.objectName === name) return item;
                    for (let i = 0; i < item.children.length; i++) { const f = find(item.children[i], name); if (f) return f; }
                    return null;
                };
                out.picker = { area: v.area };
                for (const n of ["pickerDialog", "pickerOk", "pickerCancel", "pickerApply", "pickerTheme", "pickerScheme", "tab0", "tab1", "tabLabel0", "tabLabel1"]) {
                    const it = find(v.contentItem, n);
                    if (it) out.picker[n] = rect(it);
                }
            }
            return JSON.stringify(out);
        }
        function focusApply(): string {
            const v = root.findPicker();
            if (!v) return "no picker";
            v.show({ applyFocus: true });
            return "ok";
        }
        // Open a menu or the picker under whichever theme is loaded.
        function openMenu(name: string): string { MenuState.open(name, root.screen0, -1); return MenuState.current; }
        function openPicker(): string { ThemePicker.open(root.screen0); return String(ThemePicker.visible); }
        function closeAll(): string { MenuState.close(); ThemePicker.close(); return "closed"; }
        function volume(): string { return root.volumeNow(); }
        function picker(): string { return ThemePicker.visible ? "open" : "closed"; }
        function commands(): string { return root.log.join("|"); }
        // The Fleet views: a fixture, a Desktop method, a view setting, and
        // where everything stands.
        function fleetFixture(name: string): string { root.setFleet(name); return name; }
        function fleetCall(method: string): string {
            const d = root.desktop;
            if (!d || typeof d[method] !== "function") return "no " + method;
            d[method]();
            return "ok";
        }
        function fleetSet(key: string, value: string): string {
            const d = root.desktop, c = d && d.fleetGlance ? d.fleetGlance : null;
            if (key === "expanded" && value !== "") { fleetData.selected = value; fleetData.expanded = value; }
            else if (key === "selected" || key === "expanded" || key === "sort") fleetData[key] = value;
            else if (c && key === "view") c.view = value;
            else if (c && key === "tab") c.tab = Number(value);
            else if (c && key === "minimized") c.minimized = value === "true";
            else if (key === "reduced") GlanceState.reducedMotion = value === "true";
            else if (key === "enabled") { const kv = value.split(":"); GlanceState.setEnabled(kv[0], kv[1] === "true"); }
            else if (key === "place") { const kv = value.split(":"); GlanceState.place(kv[0], Number(kv[1]), Number(kv[2])); }
            else if (key === "cleanup") GlanceState.cleanUp();
            else return "unknown " + key;
            return "ok";
        }
        function seek(ms: int, direction: string): string { GlanceState.hold(ms, direction); return "ok"; }
        function fleet(): string {
            const d = root.desktop;
            const c = d && d.fleetGlance ? d.fleetGlance.debug() : null;
            return JSON.stringify({
                state: fleetData.state, tone: fleetData.fleet.tone, hosts: fleetData.fleet.hosts.length,
                problems: fleetData.fleet.problems.map(function (v) { return v.name; }), stale: fleetData.stale,
                selected: fleetData.selected, expanded: fleetData.expanded, sort: fleetData.sort,
                details: Object.keys(fleetData.details), shown: fleetData.shown, detailShown: fleetData.detailShown,
                open: MenuState.current, tip: d ? d.tipId : "", tooltip: d && d.tipId ? d.tooltip(d.tipId) : "",
                glanceScreen: GlanceState.glanceScreen ? GlanceState.glanceScreen.name : "", fleetScreen: GlanceState.fleetScreen ? GlanceState.fleetScreen.name : "",
                places: GlanceState.saved.places, enabled: GlanceState.saved.enabled,
                views: c, taskbar: d && d.debugPlaces ? d.debugPlaces() : null, plan: d && d.taskbarPlan ? d.taskbarPlan() : null
            });
        }
        // The centre of an item by objectName in a Fleet surface, in screen
        // logical px: "<window|glance|menu> <name>".
        function fleetItem(where: string, wanted: string): string {
            let name = wanted;
            const d = root.desktop;
            if (!d || !d.fleetGlance) return "";
            const host = where === "window" ? d.fleetGlance.fleetWindow : where === "glance" ? d.fleetGlance.glanceSpace : null;
            const top = where === "menu" ? (d.openItem || null) : host ? host.contentItem : null;
            const find = function (item) {
                if (!item) return null;
                if (item.objectName === name && item.visible !== false) return item;
                for (let i = 0; i < item.children.length; i++) { const f = find(item.children[i]); if (f) return f; }
                return null;
            };
            // "menu:<row>": a row of the surface's own open menu (View, the
            // control menu).
            const inMenu = name.indexOf("menu:") === 0;
            const rowText = inMenu ? name.slice(5) : name;
            if (inMenu) name = "fleetMenu";
            const it = where === "menu" ? top : find(top);
            if (!it) return "";
            if (where === "menu" || inMenu) {
                name = rowText;
                const panel = it.panelAt ? it.panelAt(0) : null;
                if (!panel) return "";
                const i = panel.items.findIndex(function (x) { return x.text && Win98Tokens.plainText(x.text) === name; });
                if (i < 0) return "";
                const p = panel.mapToItem(null, panel.rowX(i) + panel.columnWidth / 2, panel.rowY(i) + panel.rowH / 2);
                return Math.round(p.x) + " " + Math.round(p.y);
            }
            const p = it.mapToItem(null, it.width / 2, it.height / 2);
            return Math.round(p.x) + " " + Math.round(p.y);
        }
        function places(): string {
            const d = root.desktop;
            return d ? JSON.stringify(d.debugPlaces()) : "{}";
        }
        // ---- the Find window and Open dialog (find.sh)
        // The service and the open view: what the keys and clicks changed.
        function find(): string {
            const item = root.desktop ? root.desktop.openItem : null;
            const kind = item ? String(item).replace(/_QML.*|\(.*/, "") : "";
            const out = { shown: omni.shown, mode: omni.mode, query: omni.query, views: omni.views.length,
                caller: omni.caller ? omni.caller.title : "", open: MenuState.current, item: kind,
                claimed: root.desktop ? !!root.desktop.omniClaimed : false };
            if (kind.indexOf("Win98FindWindow") === 0) {
                const r = item.rows[item.current];
                Object.assign(out, { scope: item.scope, rows: item.rows.length, current: r ? r.label : "-",
                    drop: item.dropOpen, dropIndex: item.dropIndex, tip: item.tipIndex, steps: item.plan.steps,
                    inView: item.currentInView, scrollY: item.scrollY,
                    status: item.statusInfo.count + " | " + item.statusInfo.detail });
            } else if (kind.indexOf("Win98OpenDialog") === 0) {
                Object.assign(out, { list: item.listOpen, pick: item.pick, address: item.address,
                    pages: item.shownPages.length, dest: item.dest.text + " " + item.dest.title, plan: item.plan.steps });
            }
            return JSON.stringify(out);
        }
        // Drive the service as the IPC targets and Start do.
        function omniCall(verb: string, arg: string): string {
            if (verb === "root") omni.enterRoot();
            else if (verb === "mode") omni.enterMode(arg);
            else if (verb === "nav") omni.enterNavigate(arg);
            else if (verb === "dismiss") omni.dismiss();
            else if (verb === "active") omni.active = root.toplevels[Number(arg)] || null;
            return verb;
        }
        // Rectangles in screen logical px of the open Find or Open's parts
        // (visible items with these objectNames), and the room.
        function findGeometry(): string {
            const item = root.desktop ? root.desktop.openItem : null;
            const out = { w: root.screen0.width, h: root.screen0.height, bar: root.desktop ? root.desktop.debugPlaces().barHeight : 0, parts: {} };
            if (!item) return JSON.stringify(out);
            const rect = function (it) { const q = it.mapToItem(null, 0, 0); return { x: q.x, y: q.y, w: it.width, h: it.height }; };
            out.window = rect(item);
            out.plan = item.plan;
            const walk = function (it) {
                if (!it || !it.visible) return;
                if (it.objectName && !out.parts[it.objectName]) out.parts[it.objectName] = rect(it);
                for (let i = 0; i < it.children.length; i++) walk(it.children[i]);
            };
            walk(item);
            return JSON.stringify(out);
        }
        // The centre of a visible part of the open Find or Open, by objectName.
        function findControl(name: string): string {
            const g = JSON.parse(findGeometry());
            const r = g.parts[name];
            return r ? Math.round(r.x + r.w / 2) + " " + Math.round(r.y + r.h / 2) : "";
        }

        // ---- the taskbar's windows, the window and taskbar menus, the
        // session dialogs, the Cool Switch and the pop-up
        function tasks(): string {
            const d = root.desktop;
            if (!d || !d.laneEntries) return "[]";
            return JSON.stringify(d.laneEntries.map(function (e) {
                return { i: root.indexOf(e.row.address), title: e.row.title, page: e.home, min: e.minimized, active: !!e.row.toplevel.activated };
            }));
        }
        // shell.qml windowMenu's routing, for one screen at 0, 0.
        function windowMenu(address: string, x: int, y: int): string {
            const d = root.desktop;
            if (address !== "" && !/^(0x)?[0-9a-fA-F]+$/.test(address)) return "invalid";
            const t = address === "" ? root.toplevels.find(function (w) { return w.activated; }) : null;
            const r = shellStub.rowFor(t ? t.lastIpcObject.address : address);
            if (!r || !d) return "none";
            d.windowMenu(r.address, x < 0 && y < 0 ? r.x : x, x < 0 && y < 0 ? r.y : y);
            return "ok " + r.address;
        }
        function taskbarMenu(x: int): string { if (root.desktop) root.desktop.taskbarMenu(x, root.screen0.height - 28 * Win98Tokens.u); return MenuState.current; }
        // shell.qml cycleChrome: numbered messages, stale ones dropped.
        function cycle(action: string, position: int, seqText: string): string {
            const seq = Number(seqText);
            if (!AppModel.accept(root.cycleSeq, seq)) return "stale";
            root.cycleSeq = seq;
            if (root.desktop && typeof root.desktop.cycle === "function") root.desktop.cycle(action, position);
            return root.desktop && root.desktop.cycleState ? "cycling " + root.desktop.cycleTarget : "idle";
        }
        function cycleState(): string {
            const d = root.desktop;
            const b = d ? d.coolSwitchItem : null;
            return JSON.stringify({ target: d ? d.cycleTarget : "", open: !!(d && d.cycleState), order: d && d.cycleState ? d.cycleState.order : [],
                box: b ? { x: b.mapToItem(null, 0, 0).x, y: b.mapToItem(null, 0, 0).y, w: b.width, h: b.height } : null });
        }
        function setVolume(v: int): string { const n = sound.defaultSink; if (n) n.audio.volume = v / 100; return root.volumeNow(); }
        function setMuted(m: bool): string { const n = sound.defaultSink; if (n) n.audio.muted = m; return root.volumeNow(); }
        function setBrightness(v: int): string { bri.level = v; return String(bri.level); }
        function popup(): string {
            const d = root.desktop;
            const b = d ? d.popupItem : null;
            const q = b ? b.mapToItem(null, 0, 0) : null;
            return JSON.stringify({ id: d ? d.popupId : "", armed: d ? [d.volArmed, d.briArmed] : [],
                box: b ? { x: q.x, y: q.y, w: b.width, h: b.height } : null });
        }
        function lists(which: string): string { root.recentEmpty = which === "empty"; root.seedLists(); return which; }
        // The centre (or, with "rect:", the bounds) of an item by
        // objectName on one of the Desktop's surfaces: menu (the open menu
        // or window), shutdown, cool, popup.
        function at(where: string, wanted: string): string {
            const d = root.desktop;
            if (!d) return "";
            const rect = wanted.indexOf("rect:") === 0;
            const name = rect ? wanted.slice(5) : wanted;
            const top = where === "shutdown" ? d.shutDownItem : where === "cool" ? d.coolSwitchItem : where === "popup" ? d.popupItem : d.openItem;
            const find = function (item) {
                if (!item) return null;
                if ((item.objectName === name || name === "") && item.visible !== false) return item;
                for (let i = 0; i < item.children.length; i++) { const f = find(item.children[i]); if (f) return f; }
                return null;
            };
            const it = find(top);
            if (!it) return "";
            const p = it.mapToItem(null, 0, 0);
            if (rect) return JSON.stringify({ x: p.x, y: p.y, w: it.width, h: it.height, text: it.text !== undefined ? String(it.text) : "" });
            return Math.round(p.x + it.width / 2) + " " + Math.round(p.y + it.height / 2);
        }
        // A Desktop action by name (captures): minimizeAll, minimizeOthers,
        // restoreAll; and the Shut Down dialog's choice.
        function perform(act: string): string { if (root.desktop) root.desktop.perform(act, 0, root.desktop.menuAddress); return act; }
        function setShutChoice(id: string): string { if (root.desktop) root.desktop.shutChoice = id; return id; }
        // Open the open menu's cascade at a top-level index (geometry.sh).
        function cascade(index: int): string {
            const m = root.desktop ? root.desktop.openItem : null;
            if (!m || !m.setState) return "no menu";
            m.setState([index], 0);
            return "ok";
        }
        function reduced(on: bool): string { Win98Tokens.reducedMotion = on; return String(Win98Tokens.reducedMotion); }
        // Window motion (WindowMotion's events), for the motion captures:
        // {"kind", "index" (a fixture window), "rect": [x, y, w, h], "to": [...]}.
        function motion(json: string): string {
            const a = JSON.parse(json);
            const t = root.toplevels[a.index];
            const r = function (v) { return v ? { x: v[0], y: v[1], w: v[2], h: v[3] } : null; };
            const e = { kind: a.kind, address: t ? AppModel.key(t.lastIpcObject.address) : "", screen: root.screen0.name,
                rect: r(a.rect), to: r(a.to), title: a.title || (t ? t.title : ""), appId: "", active: a.active !== false, theme: Theme.name };
            motionStub.requested(e);
            return JSON.stringify(e);
        }
        function motionHold(ms: int): string { motionStub.held = ms; return String(ms); }
        function motionDebug(): string {
            const m = root.desktop ? root.desktop.motionLayer : null;
            return JSON.stringify(m ? { visible: m.visible, flights: m.debug() } : null);
        }
        // The stand-in app window: {"rect": [x, y, w, h], "title", "active"}, or "" for none.
        function app(json: string): string { root.fakeWindow = json === "" ? null : JSON.parse(json); return json; }
        // Every string the Win98 Desktop draws now (the taskbar, the open
        // menu or window and its whole model, the Shut Down dialog, the Cool
        // Switch, the pop-up, every taskbar control's tooltip), any page head
        // (there must be none) and the text drawn on each page divider (none).
        function strings(): string {
            const d = root.desktop;
            if (!d) return "{}";
            const out = [];
            const walk = function (item) {
                if (!item) return;
                if (item.plain !== undefined && item.visible !== false && typeof item.plain === "string" && item.plain !== "") out.push(item.plain);
                for (let i = 0; i < item.children.length; i++) walk(item.children[i]);
            };
            for (const top of [d.taskbarItem, d.openItem, d.shutDownItem, d.coolSwitchItem, d.popupItem]) walk(top);
            const model = function (items) {
                for (const it of items || []) {
                    if (!it || it.separator) continue;
                    out.push(Win98Tokens.plainText(it.text || ""));
                    if (it.shortcut) out.push(it.shortcut);
                    model(it.submenu);
                }
            };
            if (d.openItem && d.openItem.model) model(d.openItem.model);
            model(d.startModel);
            model(d.windowMenuItems);
            model(d.taskbarMenuItems);
            const places = d.debugPlaces();
            const tips = [];
            for (const id in places) if (/^(win|page)\d|^[a-z]+$/.test(id) && typeof places[id] === "object" && "w" in places[id]) tips.push(d.tooltip(id));
            const tb = d.taskbarItem;
            // Page heads must be gone: no place, so no hit target or tooltip.
            const pages = Object.keys(places).filter(function (id) { return /^page/.test(id); });
            // Text drawn over a page divider, from the taskbar's items.
            const dividers = [];
            for (const p of places.dividers || []) {
                const inBox = [];
                const look = function (item) {
                    if (!item) return;
                    if (item.plain !== undefined && item.visible !== false && item.plain !== "") {
                        const q = item.mapToItem(null, 0, 0);
                        const top = tb.mapToItem(null, 0, 0);
                        if (q.x + item.width > p.x + 0.5 && q.x < p.x + p.w - 0.5 && q.y >= top.y + tb.height - places.barHeight - 0.5) inBox.push(item.plain);
                    }
                    for (let i = 0; i < item.children.length; i++) look(item.children[i]);
                };
                look(tb);
                dividers.push({ x: p.x, w: p.w, text: inBox });
            }
            return JSON.stringify({ drawn: out, tips: tips, pages: pages, dividers: dividers });
        }
        function shutChoice(): string { return root.desktop ? root.desktop.shutChoice : ""; }
        // The items under a point of the open menu's window, top first (development).
        function probe(x: int, y: int): string {
            const m = root.desktop ? root.desktop.openItem : null;
            const w = m ? m.Window.window : null;
            if (!w) return "no window";
            const out = [];
            const walk = function (item, depth) {
                for (let i = item.children.length - 1; i >= 0; i--) {
                    const c = item.children[i];
                    if (!c.visible) continue;
                    const p = c.mapFromItem(null, x, y);
                    if (p.x >= 0 && p.y >= 0 && p.x < c.width && p.y < c.height) out.push(depth + ":" + (c.objectName || String(c).split("(")[0]) + " z=" + c.z + " en=" + c.enabled);
                    walk(c, depth + 1);
                }
            };
            walk(w.contentItem, 0);
            return out.join("\n");
        }
    }
}
