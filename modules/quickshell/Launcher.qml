pragma Singleton

import Quickshell
import Quickshell.Io
import "launcher-model.js" as Model

Singleton {
    id: root

    readonly property string stateDirectory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/mountainous"
    property var _recent: Model.readRecent(stateFile.text())
    readonly property var recent: _recent
    property bool dirty: false
    property bool directoryReady: false
    property int serial: 0

    // A synchronous first read means an early launch cannot overwrite history
    // while an asynchronous initial read is still in flight.
    FileView {
        id: stateFile
        path: root.stateDirectory + "/recent-apps.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onSaveFailed: console.warn("[launcher] could not save recent apps: " + path)
    }

    Process {
        command: ["mkdir", "-p", "--", root.stateDirectory]
        running: true
        onExited: function (code) {
            root.directoryReady = code === 0;
            if (code !== 0) console.warn("[launcher] could not create state directory");
            else root.persist();
        }
    }

    function persist() {
        if (!root.dirty || !root.directoryReady) return;
        stateFile.setText(JSON.stringify(root._recent) + "\n");
        root.dirty = false;
    }

    function launch(argv: list<string>, meta) {
        // Validate before constructing either the scope or the history record.
        const args = Array.from(argv);
        if (!Model.validArgv(args) || !Model.validMeta(meta)) {
            console.warn("[launcher] invalid argv or metadata");
            return;
        }
        const nonce = Date.now().toString(36) + "-" + (++root.serial) + "-" + Math.random().toString(36).slice(2, 10);
        Quickshell.execDetached(Model.scopeCommand(args, meta.id, nonce));
        if (meta.kind === "app" || meta.kind === "webapp") {
            root._recent = Model.record(root._recent, args, meta, Date.now());
            root.dirty = true;
            root.persist();
        }
    }

    function launchEntry(entry) {
        if (!entry) return;
        root.launch(Model.entryArgv(entry), {id: entry.id, name: entry.name, icon: entry.icon, kind: Model.entryKind(entry)});
    }
}
