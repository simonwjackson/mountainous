import Quickshell
import Quickshell.Io
import QtQuick

// Brightness: the bar control's state and its menu, reached from the bar
// or with SUPER+O then L. This Scope owns the state; MenuHost shows the
// menu.
//
// There is one level for every screen. modules/brightness.py owns it:
//   ~/.local/state/mountainous/brightness      the level, a percentage
//   $XDG_RUNTIME_DIR/mountainous-brightness.json
//       { "panel": bool, "monitors": [{ "manufacturer", "model" }] }
//       the screens that follow the level, rewritten at each rescan
// This panel only reads those files. Every change goes through
// `mountainous-brightness`, the same command the brightness keys run, so the
// keys, the bar and the panel cannot disagree.
Scope {
    id: root

    property bool shown: false

    // modules/brightness.py: MINIMUM and MAXIMUM.
    readonly property int minimum: 5
    readonly property int maximum: 100

    // The stored level, as the level file says. Every screen follows it.
    property int level: -1

    // What the bar and the slider draw. While a drag is held, or while a
    // value it sent is still on its way to the file, that is the value the
    // user asked for, not the file: the file lags the pointer, and drawing it
    // made the fill jump back and forth during a drag.
    readonly property int shownLevel:
        (root.dragging || root.sending || settle.running) && root.requested >= 0
            ? root.requested : root.level

    // The last write lands in the file a moment after its process exits.
    // Hold the requested value until the file has caught up, so the fill
    // does not flick back to an older step on release.
    Timer {
        id: settle
        interval: 400
    }
    onLevelChanged: if (root.level === root.requested) settle.stop()

    property bool panelFollows: false
    property var monitors: []

    // What the top bar reads. Hidden only when no screen can be dimmed,
    // because then the control has nothing to do.
    readonly property bool available: root.level >= 0
        && (root.panelFollows || root.monitors.length > 0)

    readonly property string stateDir: {
        const x = Quickshell.env("XDG_STATE_HOME");
        return (x && x !== "") ? x : Quickshell.env("HOME") + "/.local/state";
    }

    FileView {
        path: root.stateDir + "/mountainous/brightness"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const value = parseInt(text().trim(), 10);
            if (!isNaN(value)) root.level = value;
        }
    }

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/mountainous-brightness.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            // A read can land mid-write. Keep the last good value.
            try {
                const status = JSON.parse(text());
                root.panelFollows = status.panel === true;
                root.monitors = Array.isArray(status.monitors) ? status.monitors : [];
            } catch (e) {}
        }
    }

    function run(args) {
        Quickshell.execDetached(["mountainous-brightness"].concat(args));
    }

    function step(direction) { root.run([direction > 0 ? "up" : "down"]); }

    // A drag sends its values through one process at a time. A value that
    // arrives while one is running waits, and only the newest waiting value
    // is sent next. Separate processes for each step could finish out of
    // order, so the level could end on a step the pointer had already left.
    property bool dragging: false
    property int requested: -1
    property int pending: -1
    readonly property bool sending: setter.running || root.pending >= 0

    Process {
        id: setter
        onExited: {
            root.flush();
            if (!root.sending) settle.restart();
        }
    }

    function flush() {
        if (setter.running || root.pending < 0) return;
        setter.command = ["mountainous-brightness", "set", String(root.pending)];
        root.pending = -1;
        setter.running = true;
    }

    function setLevel(value) {
        const v = Math.max(root.minimum, Math.min(root.maximum, Math.round(value)));
        if (v === root.requested && root.sending) return;
        root.requested = v;
        root.pending = v;
        root.flush();
    }

    // The laptop panel is an eDP output. An external screen follows when the
    // daemon reached a monitor with its model over DDC/CI.
    function follows(screen) {
        if (!screen) return false;
        if (screen.name.startsWith("eDP")) return root.panelFollows;
        return root.monitors.some(function (m) { return m.model !== "" && m.model === screen.model; });
    }

    function screenLabel(screen) {
        if (screen.name.startsWith("eDP")) return "Laptop screen";
        return screen.model !== "" ? screen.model : screen.name;
    }

    // Every connected screen, plus any monitor the daemon reaches that is
    // not a screen here, such as one showing another computer's input.
    property var rows: {
        const list = Quickshell.screens.map(function (s) {
            return { label: root.screenLabel(s), detail: s.name, follows: root.follows(s) };
        });
        for (const m of root.monitors) {
            const shownHere = Quickshell.screens.some(function (s) { return s.model === m.model; });
            if (!shownHere) list.push({
                label: m.model || "Monitor",
                detail: "not showing this computer",
                follows: true
            });
        }
        return list;
    }
}
