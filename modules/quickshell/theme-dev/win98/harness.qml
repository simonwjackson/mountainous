// DEV HARNESS (not delivered): the real Win98Desktop, loaded by the real
// ThemeDesktop, with the production data owners (panels/) fed from the
// approved mock's state catalogue instead of D-Bus, PipeWire and Hyprland.
// Staged as shell.qml in a copy of modules/quickshell; win98-dev/ holds
// this folder. See capture.sh and behaviour.test.js.
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import QtQuick
import "panels"
import "lanes.js" as Lanes
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
        function showPage(page) { root.note("page " + page); }
        function openMenu(name, screen) { MenuState.open(name, screen, -1); }
        function toggleMenu(name, screen) { MenuState.toggle(name, screen, -1); }
        function closeMenu(name) { if (MenuState.current === name) MenuState.close(); }
    }

    // ---- windows: Hyprland toplevels' shape (lanes.js)
    property var toplevels: []
    function appId(icon) {
        return ({ term: "com.mitchellh.ghostty", chromium: "chromium-browser", signal: "signal", zed: "dev.zed.Zed",
            obs: "com.obsproject.Studio", tx: "transmission-gtk", firefox: "firefox", sun: "sunshine", sync: "syncthing" })[icon] || icon;
    }
    function buildWindows() {
        const name = root.screen0 ? root.screen0.name : "";
        const monitors = {};
        const pages = {};
        root.toplevels = (FindStates.windowsFor(root.stateId) || root.dd.windows).map(function (w, i) {
            const screen = w.screen || name;
            const monitor = monitors[screen] || (monitors[screen] = { name: screen });
            const key = screen + ":" + w.page;
            const ws = pages[key] || (pages[key] = { id: w.page, active: w.page === root.dd.showingPage, monitor: monitor });
            return root.obj({ title: w.title, activated: !!w.focused, urgent: !!w.urgent, workspace: ws,
                lastIpcObject: { address: "0x" + (1000 + i), at: w.at, size: w.size },
                wayland: root.handle(w.appId || root.appId(w.icon), i) });
        });
    }
    // A Wayland toplevel handle whose activate() and close() the log records.
    function handle(appId, i) {
        const o = root.obj({ appId: appId },
            "signal didActivate()\nsignal didClose()\nfunction activate() { didActivate(); }\nfunction close() { didClose(); }");
        o.didActivate.connect(function () { root.note("activate " + i); });
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
            out.push({ kind: "window", label: t.title, detail: "page " + t.workspace.id, page: t.workspace.id,
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
        readonly property var frontWindow: null
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

    function apply(view) {
        const d = root.dd, p = root.st.p || {};
        root.buildWindows();
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
        function volume(): string { return sound.defaultSink ? String(Math.round(sound.defaultSink.audio.volume * 100)) : "-"; }
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
    }
}
