import Quickshell
import Quickshell.Io
import QtQuick
import "../beszel-model.js" as Model

// The fleet's health from the read-only Beszel MCP server, for every Fleet
// view: the bar's readout, the Fleet window and the glance space. One owner
// for the shell: the views share its data and its view state (sort, the
// selected and the expanded host).
//
// The helper (beszel-status, modules/beszel-desktop.nix) holds the token and
// makes the request; this owner never sees the credential. It refreshes
// while a Fleet view shows: every 60 s, and at once when a window opens.
// A failed refresh keeps the last good sample; every host then ages into the
// model's three-minute stale warning on its own.
Scope {
    id: root

    // Any Fleet view on screen, the bar's readout included.
    property bool shown: false
    // A Fleet window or the glance space on screen: the drill-down runs
    // only then, and only for the expanded host.
    property bool detailShown: false
    // Without a token the helper would only answer "unavailable".
    property bool enabled: Quickshell.env("BESZEL_MCP_TOKEN_FILE") !== ""

    // The last attempt: loading, ready, unavailable or error.
    property string sampleState: enabled ? "loading" : "unavailable"
    // The last good sample and when it arrived (epoch ms; 0 = none).
    property var systems: null
    property double sampledAt: 0
    // Host name -> earlier rows, for the five-minute CPU and memory rule.
    property var history: ({})
    property double now: Date.now()

    // Shared view state.
    property string sort: "name"
    property string expanded: ""
    property string selected: ""
    // Host name -> {state, metrics, failed, smart, at}
    property var details: ({})

    readonly property string state: root.systems !== null ? "ready" : root.sampleState
    // The last refresh failed while an older sample is still shown.
    readonly property string failing: root.systems !== null && root.sampleState !== "ready"
        && root.sampleState !== "loading" ? root.sampleState : ""
    readonly property bool stale: root.state === "ready"
        && (root.failing !== "" || root.now - root.sampledAt > 180000)
    readonly property var smartDevices: {
        let out = [];
        for (const name of Object.keys(root.details)) {
            const d = root.details[name];
            if (d && Array.isArray(d.smart)) out = out.concat(d.smart);
        }
        return out;
    }
    readonly property var fleet: Model.fleetView(root.state === "ready" ? root.systems : root.state,
        root.history, root.now, root.smartDevices)
    readonly property var readout: Model.barReadout(root.fleet)
    readonly property bool refreshing: systemsProcess.running

    function refresh() {
        if (!root.enabled) { root.sampleState = "unavailable"; return; }
        if (systemsProcess.running) return;
        systemsProcess.running = true;
    }

    function refreshDetail() {
        if (!root.enabled || !root.detailShown || root.expanded === "") return;
        if (detailProcess.running) { detailProcess.again = true; return; }
        detailProcess.host = root.expanded;
        detailProcess.command = ["beszel-status", "host", root.expanded];
        detailProcess.running = true;
    }

    function toggleExpanded(name) {
        root.selected = name;
        root.expanded = root.expanded === name ? "" : name;
    }

    function accept(text) {
        const value = text.trim();
        const t = Date.now();
        root.now = t;
        if (value === "unavailable" || value === "error") { root.sampleState = value; return; }
        let rows;
        try { rows = JSON.parse(value); } catch (e) { rows = null; }
        if (!Array.isArray(rows)) { root.sampleState = "error"; return; }
        const next = {};
        for (const row of rows) {
            if (!row || typeof row.name !== "string") continue;
            next[row.name] = Model.trimHistory((root.history[row.name] || []).concat([row]), t);
        }
        root.history = next;
        root.systems = rows;
        root.sampledAt = t;
        root.sampleState = "ready";
    }

    function acceptDetail(name, text) {
        const parsed = Model.parseDetail(text, name);
        const next = Object.assign({}, root.details);
        const old = next[name];
        // A failed drill-down keeps what the last one showed.
        if (parsed.state !== "ready" && old && old.state === "ready") next[name] = Object.assign({}, old, {failing: parsed.state});
        else next[name] = Object.assign(parsed, {at: Date.now()});
        root.details = next;
    }

    onShownChanged: if (shown) refresh()
    onDetailShownChanged: if (detailShown) { refresh(); refreshDetail(); }
    onExpandedChanged: refreshDetail()

    Timer {
        interval: 60000
        running: root.enabled && root.shown
        repeat: true
        onTriggered: { root.refresh(); root.refreshDetail(); }
    }

    // Ages the sample between refreshes, so staleness shows on time.
    Timer {
        interval: 30000
        running: root.shown
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // stdout completion and process exit may arrive in either order
    // (StorageHealth): settle once both are in.
    Process {
        id: systemsProcess
        command: ["beszel-status"]
        property var pending: ({output: null, code: null})
        function settle() {
            if (pending.output === null || pending.code === null) return;
            const done = pending;
            pending = {output: null, code: null};
            if (done.code !== 0) root.sampleState = "error";
            else root.accept(done.output);
        }
        stdout: StdioCollector { onStreamFinished: { systemsProcess.pending.output = this.text; systemsProcess.settle(); } }
        stderr: StdioCollector { }
        onStarted: pending = {output: null, code: null}
        onExited: function (code) { pending.code = code; settle(); }
    }

    Process {
        id: detailProcess
        property string host: ""
        property bool again: false
        property var pending: ({output: null, code: null})
        function settle() {
            if (pending.output === null || pending.code === null) return;
            const done = pending;
            pending = {output: null, code: null};
            root.acceptDetail(host, done.code === 0 ? done.output : "error");
            if (again || (root.expanded !== "" && root.expanded !== host)) {
                again = false;
                Qt.callLater(root.refreshDetail);
            }
        }
        stdout: StdioCollector { onStreamFinished: { detailProcess.pending.output = this.text; detailProcess.settle(); } }
        stderr: StdioCollector { }
        onStarted: pending = {output: null, code: null}
        onExited: function (code) { pending.code = code; settle(); }
    }
}
