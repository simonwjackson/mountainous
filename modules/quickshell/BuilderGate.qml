import Quickshell
import Quickshell.Io
import QtQuick
import "builder-gate.js" as Gate

// One owner for the remote-builder gate on this machine. The gate itself is
// nix-builder-gate (modules/build-federation.nix); this side only asks it and
// draws the answer. The bar control and the panel on every screen read the
// public state below, so one poll serves them all.
//
// The control exists only where `command -v nix-builder-gate` succeeds. The
// gate rewrites its state file on every change, so a watch on that file gives
// instant updates. A poll every 10 s catches what changes without a write:
// the running count and the power source.
Scope {
    id: root

    // Development only: builder-dev/capture.sh points this at a temp file.
    readonly property string stateFile: Quickshell.env("NIX_BUILDER_GATE_STATE")
        || "/run/nix-builder-gate/state.json"

    // Public state.
    property var sample: Gate.loading()
    // The command that runs now: "on", "off", "default", "stop" or "".
    property string pending: ""
    // The last command that failed: {command, detail}, or null.
    property var actionError: null
    readonly property bool enabled: sample.kind === "ready" || sample.kind === "error"

    function refresh() {
        // A probe is in flight until its output, error and exit have all
        // arrived, not only until the process exits. A stuck one is given
        // up after 15 s.
        if (root.probeStarted > 0 && Date.now() - root.probeStarted < 15000) {
            root.again = true;
            return;
        }
        root.probeStarted = Date.now();
        root.probeResult = {output: null, code: null, error: null};
        probe.running = true;
    }

    // One click on the bar: a manual choice the other way.
    function toggle() {
        const action = Gate.clickAction(root.sample, root.pending);
        if (action === "on" || action === "off") root.run(action);
    }

    // command: "on", "off", "default" or "stop".
    function run(command) {
        if (root.pending !== "" || !root.enabled) return;
        root.actionError = null;
        root.pending = command;
        root.actionResult = {code: null, error: null};
        act.command = command === "stop"
            ? ["timeout", "20", "nix-builder-gate", "stop"]
            : ["timeout", "20", "nix-builder-gate", "set", command];
        act.running = true;
    }

    property bool again: false
    property double probeStarted: 0
    property var probeResult: ({output: null, code: null, error: null})
    property var actionResult: ({code: null, error: null})

    function firstLine(text) {
        const line = String(text || "").trim().split("\n")[0];
        return line.length > 160 ? line.slice(0, 159) + "…" : line;
    }

    function settleProbe() {
        // stdout completion and process exit may arrive in either order.
        const r = root.probeResult;
        if (r.output === null || r.code === null || r.error === null) return;
        root.probeStarted = 0;
        if (r.code === 127) root.sample = Gate.absent();
        else if (r.code === 124) root.sample = Gate.failure("no answer within 5 s");
        else if (r.code !== 0) root.sample = Gate.failure("status exited " + r.code
            + (r.error ? " (" + root.firstLine(r.error) + ")" : ""));
        else root.sample = Gate.parse(r.output);
        if (root.again) {
            root.again = false;
            Qt.callLater(root.refresh);
        }
    }

    function settleAction() {
        const r = root.actionResult;
        if (r.code === null || r.error === null) return;
        const command = root.pending;
        root.pending = "";
        if (r.code !== 0) {
            root.actionError = {
                command: command,
                detail: r.code === 124 ? "no answer within 20 s"
                    : root.firstLine(r.error) || "exit " + r.code
            };
        }
        root.refresh();
    }

    Component.onCompleted: refresh()

    // A failed command shows for half a minute, then the bar shows the
    // state again. The panel keeps nothing stale either: a new command or a
    // write by the gate clears it sooner.
    Timer {
        interval: 30000
        running: root.actionError !== null
        onTriggered: root.actionError = null
    }

    Timer {
        // Hosts without the gate ask once a minute, so a deploy that adds
        // it shows up without a restart.
        interval: root.sample.kind === "absent" ? 60000 : 10000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: probe
        // Exit 127 means the CLI is missing: the control hides.
        command: ["sh", "-c",
            "command -v nix-builder-gate >/dev/null 2>&1 || exit 127; "
            + "exec timeout 5 nix-builder-gate status --json"]
        stdout: StdioCollector {
            onStreamFinished: { root.probeResult.output = this.text; root.settleProbe(); }
        }
        stderr: StdioCollector {
            onStreamFinished: { root.probeResult.error = this.text; root.settleProbe(); }
        }
        onExited: function (code) { root.probeResult.code = code; root.settleProbe(); }
    }

    Process {
        id: act
        stdout: StdioCollector { }
        stderr: StdioCollector {
            onStreamFinished: { root.actionResult.error = this.text; root.settleAction(); }
        }
        onExited: function (code) { root.actionResult.code = code; root.settleAction(); }
    }

    // A write by the gate. Only changes count: the file on disk can be older
    // than the last poll, because running and power change without a write.
    // A half-written or bad file is ignored here; the next poll decides.
    FileView {
        id: stateView
        path: root.enabled ? root.stateFile : ""
        watchChanges: true
        printErrors: false
        property bool armed: false
        onFileChanged: { armed = true; reload(); }
        onLoaded: {
            if (!armed || root.pending !== "") return;
            armed = false;
            const next = Gate.parse(text());
            if (next.kind === "ready") {
                root.sample = next;
                root.actionError = null;
            }
        }
    }
}
