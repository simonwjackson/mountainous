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

ShellRoot {
    id: root

    property string stateId: "tb-normal"
    property var st: States.stateById(stateId) || { p: {} }
    property var dd: States.dataFor(stateId)
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
        const monitor = { name: name };
        const pages = {};
        root.toplevels = root.dd.windows.map(function (w, i) {
            const ws = pages[w.page] || (pages[w.page] = { id: w.page, active: w.page === root.dd.showingPage, monitor: monitor });
            return root.obj({ title: w.title, activated: !!w.focused, urgent: !!w.urgent, workspace: ws,
                lastIpcObject: { address: "0x" + (1000 + i) },
                wayland: root.handle(root.appId(w.icon), i) });
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

    QtObject {
        id: omni
        // OmniBar.commandRows, as written in OmniBar.qml.
        readonly property var commandRows: [
            { kind: "cmd", label: "New terminal", detail: "Super+N", act: "term" },
            { kind: "cmd", label: "Go to address", detail: "Ctrl+L", act: "mode:nav" },
            { kind: "cmd", label: "Go to window", detail: "mode", act: "mode:window" },
            { kind: "cmd", label: "Close window", detail: "Super+C", act: "close" },
            { kind: "cmd", label: "Monocle", detail: "Super+M", act: "monocle" },
            { kind: "cmd", label: "Zen", detail: "Super+Shift+M", act: "zen" },
            { kind: "cmd", label: "Mirror workspace", detail: "Super+Shift+G", act: "mirror" },
            { kind: "cmd", label: "Even / golden split", detail: "Super+G", act: "split" },
            { kind: "cmd", label: "Interface scale up", detail: "Super+=", act: "scaleup" },
            { kind: "cmd", label: "Interface scale down", detail: "Super+-", act: "scaledown" },
            { kind: "cmd", label: "Interface scale 100%", detail: "Super+0", act: "scalereset" },
            { kind: "cmd", label: "Toggle bars", detail: "Super+I", act: "chrome" },
            { kind: "cmd", label: "Dark appearance", detail: "Super+D", act: "theme:dark" },
            { kind: "cmd", label: "Light appearance", detail: "Super+D", act: "theme:light" },
            { kind: "cmd", label: "Desktop theme\u2026", detail: "Appearance", act: "theme:picker" },
            { kind: "cmd", label: "Extra dark appearance", detail: "off", act: "theme:extra" },
            { kind: "cmd", label: "Screenshot", detail: "Super+S", act: "shot" }
        ]
        function enterRoot() { root.note("omni root"); }
        function enterMode(m) { root.note("omni mode " + m); }
        function run(row) { root.note("omni run " + (row ? row.act : "")); }
    }

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
        readonly property var frontWindow: null
        readonly property date now: new Date(2026, 9, 22, 16, 51)
    }

    ThemeDesktop {
        id: loader
        screen: root.screen0
        context: context
        onDesktopChanged: Qt.callLater(root.apply)
    }
    readonly property var desktop: loader.desktop

    // The mock's apps (data.js PROGRAMS), as DesktopEntries would list them.
    function apps() {
        const cat = { Accessories: "Utility", Development: "Development", Internet: "Network", Multimedia: "AudioVideo", System: "System" };
        if (root.dd.flatPrograms) return States.MANY_APPS.map(function (n) { return { id: n.toLowerCase(), name: n, categories: [] }; });
        const out = [];
        for (const folder in States.PROGRAMS)
            for (const app of States.PROGRAMS[folder]) out.push({ id: root.appId(app[1]), name: app[0], categories: [cat[folder]] });
        return out;
    }

    function apply() {
        const d = root.dd, p = root.st.p || {};
        root.buildWindows();
        // notifications
        const now = new Date(2026, 9, 22, 16, 51).getTime();
        notes.items = d.ntf.items.map(function (it, i) {
            return Object.assign({ id: 100 + i, seq: "s" + i, app_icon: "", local_only: false, resident: false }, it,
                { created: now - it.updated * 60000, updated: now - it.updated * 60000, image: null });
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
        shellStub.chromeAccessVisible = !!d.chord;
        if (!root.desktop) return;
        const desk = root.desktop;
        if (desk.preview === undefined) return;
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
            return JSON.stringify({ state: root.stateId, theme: Theme.name, loaded: loader.currentName, open: MenuState.current,
                picker: ThemePicker.visible, steps: d ? d.taskbarPlan().steps : [], log: root.log });
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
        function volume(): string { return sound.defaultSink ? String(Math.round(sound.defaultSink.audio.volume * 100)) : "-"; }
        function picker(): string { return ThemePicker.visible ? "open" : "closed"; }
        function commands(): string { return root.log.join("|"); }
        function places(): string {
            const d = root.desktop;
            return d ? JSON.stringify(d.debugPlaces()) : "{}";
        }
    }
}
