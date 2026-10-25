import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import "media-hold.js" as MediaHold

// One owner for a take from Right Alt press through insertion.
//
// The public state is a tagged value: idle, recording, working, done, or
// failed. Capture and delivery are separate internal state machines because a
// new take can be recorded while an older one is still with a backend.
//
// The bar and the taskbar show the state. There is no separate overlay.
//
// While a take records, the media that was playing is paused. When capture
// ends for any reason, only those players resume (see media-hold.js).
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
    readonly property bool barVisible: state === "recording"
        || state === "working"
        || state === "failed"
    // Retry resends the take that failed in the backend. A microphone
    // failure has no take to resend, so it offers Dismiss only, even when
    // an older backend failure still holds a take.
    readonly property bool canRetry: failedTake !== null && failureKind === "backend"
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
    // One wording for the queue, in the bar and in the taskbar.
    readonly property string queueText: queueCount + " takes"

    // The players this take paused, in resume order. Empty outside a take.
    property var heldPlayers: []
    // Reading the model starts Quickshell's MPRIS watcher at shell start, so
    // the first take already sees the players that are running.
    readonly property int mediaPlayerCount: Mpris.players.values.length

    onStateChanged: console.log("[dictation] state " + state)
    onCaptureStateChanged: {
        if (captureState === "recording") holdMedia();
        else releaseMedia();
    }
    onBackendChanged: {
        if (backend !== "") console.log("[dictation] backend " + backend);
    }

    function describePlayer(player) {
        const state = player.playbackState === MprisPlaybackState.Playing ? "playing"
            : player.playbackState === MprisPlaybackState.Paused ? "paused" : "stopped";
        return {
            key: player,
            dbusName: player.dbusName || "",
            state: state,
            canPause: player.canControl && player.canPause,
            canPlay: player.canControl && player.canPlay,
            title: player.trackTitle || "",
            artist: player.trackArtist || ""
        };
    }

    function mediaPlayers() {
        return Mpris.players.values.map(root.describePlayer);
    }

    function holdMedia() {
        if (root.heldPlayers.length > 0) return;
        const held = MediaHold.toPause(root.mediaPlayers());
        for (const player of held) player.pause();
        root.heldPlayers = held;
        if (held.length > 0) {
            console.log("[dictation] paused " + held.map(p => p.dbusName).join(" "));
        }
    }

    function releaseMedia() {
        const held = root.heldPlayers;
        if (held.length === 0) return;
        root.heldPlayers = [];
        const resumed = MediaHold.toResume(held, root.mediaPlayers());
        for (const player of resumed) player.play();
        console.log("[dictation] resumed " + resumed.map(p => p.dbusName).join(" ")
            + " of " + held.length);
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
        // pw-record exits 1 when SIGINT stops a capture: pw-cat returns 0 only
        // after draining a playback stream. The stop signal is how every take
        // ends, so exit 1 is the normal outcome and the file is still whole.
        // Any other code means the recorder never ran or died on its own.
        if (exitCode !== 0 && exitCode !== 1) {
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
        // A microphone failure on top of an older backend failure: clear
        // the microphone message and show the older failure again, so its
        // take can still be retried rather than deleted unseen.
        if (root.failureKind === "recorder" && root.failedTake !== null) {
            root.failureKind = "backend";
            return;
        }
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
}
