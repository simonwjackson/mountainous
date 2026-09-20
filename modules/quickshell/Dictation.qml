import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// One owner for a take from Right Alt press through insertion.
//
// The public state is a tagged value: idle, recording, working, done, or
// failed. Capture and delivery are separate internal state machines because a
// new take can be recorded while an older one is still with a backend.
Scope {
    id: root

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID") || ""

    property string captureState: "idle"       // idle | recording | stopping
    property string deliveryState: "idle"      // idle | working | done | failed
    property var activeTake: null
    property string captureStopReason: ""
    property int takeSerial: 0

    property var queue: []
    property var workerTake: null
    property bool workerSucceeded: false
    property bool workerCancelled: false
    property var failedTake: null
    property string failureKind: ""
    property string backend: ""
    property bool sessionLocked: sessionId === ""

    readonly property bool hasPendingWork: captureState !== "idle"
        || workerTake !== null
        || queue.length > 0
    readonly property string state: captureState === "idle"
        ? deliveryState
        : "recording"
    readonly property bool overlayVisible: state !== "idle"
    readonly property bool barVisible: state === "recording"
        || state === "working"
        || state === "failed"
    readonly property bool canRetry: failedTake !== null
    readonly property int queueCount: queue.length
        + (workerTake !== null ? 1 : 0)
        + (activeTake !== null ? 1 : 0)

    readonly property string statusText: {
        if (state === "recording") return "Recording";
        if (state === "working") return "Working";
        if (state === "done") return "Done";
        if (state === "failed") return failureKind === "recorder"
            ? "Microphone failed" : "Dictation failed";
        return "";
    }
    readonly property string backendLabel: state === "recording" || backend === ""
        ? ""
        : backend === "zao" ? "Zao" : "Groq";
    readonly property string overlayText: {
        let text = statusText;
        if (backendLabel !== "") text += " · " + backendLabel;
        if (queueCount > 1) text += " · " + queueCount + " takes";
        return text;
    }
    readonly property color accentColor: state === "recording" || state === "failed"
        ? Theme.danger
        : Theme.accent

    onStateChanged: console.log("[dictation] state " + state)
    onBackendChanged: {
        if (backend !== "") console.log("[dictation] backend " + backend);
    }

    function audioPath() {
        root.takeSerial += 1;
        return root.runtimeDir + "/dictation-" + Date.now() + "-" + root.takeSerial + ".wav";
    }

    function removeAudio(path) {
        if (!path) return;
        Quickshell.execDetached(["rm", "-f", "--", path]);
    }

    function failRecorder() {
        doneTimer.stop();
        root.captureState = "idle";
        root.activeTake = null;
        root.captureStopReason = "";
        root.deliveryState = "failed";
        root.failureKind = "recorder";
        root.backend = "";
    }

    function press(sendEnter) {
        if (root.captureState !== "idle" || root.sessionLocked) return;
        doneTimer.stop();
        if (root.deliveryState === "done") {
            root.deliveryState = "idle";
            root.backend = "";
            root.maybeStartWorker();
        }
        if (root.runtimeDir === "") {
            root.failRecorder();
            return;
        }

        const take = {
            path: root.audioPath(),
            startedAt: Date.now(),
            sendEnter: sendEnter === true
        };
        root.activeTake = take;
        root.captureStopReason = "";
        root.captureState = "recording";
        maxTakeTimer.restart();
        recorder.exec([
            "pw-record",
            "--rate", "16000",
            "--channels", "1",
            "--channel-map", "MONO",
            "--format", "s16",
            take.path
        ]);
    }

    function finishCapture(reason) {
        if (root.captureState !== "recording") return;
        root.captureStopReason = reason;
        root.captureState = "stopping";
        maxTakeTimer.stop();
        if (recorder.running) recorder.signal(2);
        else root.captureExited(-1);
    }

    function release() {
        if (root.captureState !== "recording" || root.activeTake === null) return;
        const elapsed = Date.now() - root.activeTake.startedAt;
        root.finishCapture(elapsed < 250 ? "short" : "complete");
    }

    function cancel() {
        if (root.captureState === "recording") {
            root.finishCapture("cancel");
            return;
        }
        if (root.captureState === "stopping") {
            root.captureStopReason = "cancel";
            return;
        }
        if (worker.running) {
            root.workerCancelled = true;
            worker.signal(15);
        }
    }

    function captureExited(exitCode) {
        const take = root.activeTake;
        const reason = root.captureStopReason;
        root.activeTake = null;
        root.captureState = "idle";
        root.captureStopReason = "";
        maxTakeTimer.stop();

        if (take === null) return;
        if (reason === "short" || reason === "cancel") {
            root.removeAudio(take.path);
            return;
        }
        if (reason !== "complete" && reason !== "limit") {
            root.removeAudio(take.path);
            root.failRecorder();
            return;
        }
        if (exitCode !== 0) {
            root.removeAudio(take.path);
            root.failRecorder();
            return;
        }

        const next = root.queue.slice();
        next.push(take);
        root.queue = next;
        root.maybeStartWorker();
    }

    function maybeStartWorker() {
        if (worker.running || root.workerTake !== null || root.sessionLocked) return;
        if (root.deliveryState === "failed" || root.queue.length === 0) return;

        doneTimer.stop();
        const next = root.queue.slice();
        const take = next.shift();
        root.queue = next;
        root.workerTake = take;
        root.workerSucceeded = false;
        root.workerCancelled = false;
        root.failureKind = "";
        root.backend = "";
        root.deliveryState = "working";
        worker.exec([
            "dictation-submit", take.path, take.sendEnter ? "1" : "0",
            root.sessionId
        ]);
    }

    function handleWorkerLine(data) {
        const line = data.trim();
        if (line.startsWith("backend ")) {
            const value = line.slice(8);
            if (value === "zao" || value === "groq") root.backend = value;
            return;
        }
        if (line.startsWith("done ")) {
            const value = line.slice(5);
            if (value === "zao" || value === "groq") root.backend = value;
            root.workerSucceeded = true;
        }
    }

    function workerExited(exitCode) {
        const take = root.workerTake;
        root.workerTake = null;
        doneTimer.stop();

        if (take === null) return;
        if (root.workerCancelled) {
            root.workerCancelled = false;
            root.removeAudio(take.path);
            root.deliveryState = "idle";
            root.backend = "";
            root.maybeStartWorker();
            return;
        }

        if (exitCode === 21) {
            const next = root.queue.slice();
            next.unshift(take);
            root.queue = next;
            root.sessionLocked = true;
            root.deliveryState = "idle";
            root.backend = "";
            return;
        }

        if (exitCode === 0 && root.workerSucceeded) {
            root.removeAudio(take.path);
            root.deliveryState = "done";
            root.failureKind = "";
            doneTimer.interval = root.queue.length > 0 ? 800 : 2500;
            doneTimer.restart();
            return;
        }

        if (root.failedTake !== null) root.removeAudio(root.failedTake.path);
        root.failedTake = take;
        root.deliveryState = "failed";
        root.failureKind = "backend";
    }

    function retryFailed() {
        if (root.deliveryState !== "failed" || root.failedTake === null
                || worker.running || root.sessionLocked) return;
        doneTimer.stop();
        const take = root.failedTake;
        root.failedTake = null;
        root.workerTake = take;
        root.workerSucceeded = false;
        root.workerCancelled = false;
        root.failureKind = "";
        root.backend = "";
        root.deliveryState = "working";
        worker.exec([
            "dictation-submit", take.path, take.sendEnter ? "1" : "0",
            root.sessionId
        ]);
    }

    function updateSessionLock(locked) {
        root.sessionLocked = locked;
        if (locked && root.captureState === "recording") root.cancel();
        if (!locked) root.maybeStartWorker();
    }

    function dismissFailure() {
        if (root.deliveryState !== "failed") return;
        doneTimer.stop();
        if (root.failedTake !== null) root.removeAudio(root.failedTake.path);
        root.failedTake = null;
        root.failureKind = "";
        root.backend = "";
        root.deliveryState = "idle";
        root.maybeStartWorker();
    }

    Process {
        id: recorder
        stdout: StdioCollector { }
        stderr: StdioCollector { }
        onExited: function (exitCode, exitStatus) { root.captureExited(exitCode); }
    }

    Timer {
        id: maxTakeTimer
        interval: 180000
        repeat: false
        onTriggered: {
            if (root.captureState !== "recording") return;
            root.captureStopReason = "limit";
            root.captureState = "stopping";
            if (recorder.running) recorder.signal(2);
            else root.captureExited(-1);
        }
    }

    Process {
        id: worker
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (data) { root.handleWorkerLine(data); }
        }
        // The helper guarantees generic errors, but the UI needs only the exit
        // status. Discard stderr instead of copying it into the journal.
        stderr: StdioCollector { }
        onExited: function (exitCode, exitStatus) { root.workerExited(exitCode); }
    }

    Timer {
        id: doneTimer
        interval: 2500
        repeat: false
        onTriggered: {
            root.deliveryState = "idle";
            root.backend = "";
            root.maybeStartWorker();
        }
    }

    // Hyprland blocks a new press while locked. This poll covers a lock that
    // arrives during capture, backend work, or a queued take. An empty or
    // failed result stays locked so an uncertain state cannot paste text.
    Timer {
        interval: 500
        repeat: true
        running: root.sessionId !== ""
            && (root.hasPendingWork || root.sessionLocked)
        triggeredOnStart: true
        onTriggered: {
            if (!lockProbe.running) {
                lockProbe.exec([
                    "loginctl", "show-session", root.sessionId,
                    "--property=LockedHint", "--value"
                ]);
            }
        }
    }

    Process {
        id: lockProbe
        stdout: StdioCollector {
            onStreamFinished: root.updateSessionLock(this.text.trim() !== "no")
        }
        stderr: StdioCollector { }
    }

    // Shipped voice surfaces use one compact status pill. Keep the same shape,
    // but omit their waveform, timer, and transcript because this surface
    // reports state only.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay

            required property var modelData
            screen: modelData
            visible: root.overlayVisible
                && Hyprland.monitorFor(modelData) === Hyprland.focusedMonitor
            anchors { bottom: true; left: true; right: true }
            margins { bottom: 56; left: 12; right: 12 }
            implicitHeight: 38
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            // The overlay has no controls. Every pointer event goes to the
            // application below it, including events over the visible pill.
            mask: Region { width: 0; height: 0 }

            Rectangle {
                id: pill
                anchors.centerIn: parent
                width: Math.min(parent.width, contents.implicitWidth + 20)
                height: 36
                radius: 18
                color: Theme.bgPanel
                border.width: 1
                border.color: root.accentColor

                RowLayout {
                    id: contents
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: root.accentColor
                    }

                    Text {
                        Layout.maximumWidth: Math.max(0, overlay.width - 52)
                        text: root.overlayText
                        elide: Text.ElideRight
                        color: Theme.textPrimary
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                    }
                }
            }
        }
    }
}
