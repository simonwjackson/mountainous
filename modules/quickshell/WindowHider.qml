import Quickshell
import Quickshell.Io
import QtQuick
import "window-hide.js" as WindowHide

// Hide and Show, for every theme. One owner, at the shell root: it moves
// windows to their app's special workspace and back, and keeps each
// hidden window's home page in $XDG_STATE_HOME/mountainous/hidden-windows.json
// so Show still knows it after Quickshell restarts. See window-hide.js.
Scope {
    id: hider

    // shell.qml's windowRows: every toplevel as a plain row.
    required property var rows

    property var state: WindowHide.empty()
    property bool loaded: false

    readonly property var hiddenApps: WindowHide.hiddenApps(hider.rows)
    readonly property int hiddenCount: WindowHide.hiddenRows(hider.rows).length

    // A batch about to run: window-hide.js moves, the state before it, and
    // the address it focuses ("" for none). WindowMotion draws from it.
    signal moving(var moves, var state, string focus)
    // How long a show waits before its windows move back (WindowMotion's
    // revealDelay: the restore motion lands first). Hides never wait.
    property int showDelay: 0

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/mountainous"

    FileView {
        id: file
        path: hider.stateDir + "/hidden-windows.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
        onLoaded: { hider.state = WindowHide.parse(file.text()); hider.loaded = true; reconcileSoon.restart(); }
        onLoadFailed: { hider.loaded = true; reconcileSoon.restart(); }
    }

    // After a restart the toplevels arrive a moment after the file. Forget
    // windows that closed while Quickshell was away; adopt hidden windows
    // the file does not know.
    Timer {
        id: reconcileSoon
        interval: 1500
        onTriggered: {
            const next = WindowHide.reconcile(hider.state, hider.rows);
            if (JSON.stringify(next) !== JSON.stringify(hider.state)) { hider.state = next; hider.save(); }
        }
    }
    onRowsChanged: if (hider.loaded && !reconcileSoon.running) reconcileSoon.restart()

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", hider.stateDir])

    function save() {
        file.setText(WindowHide.serialize(hider.state));
    }

    function run(result, extra, focus) {
        const shows = result.moves.some(function (m) { return typeof m.workspace === "number"; });
        hider.moving(result.moves, hider.state, focus ? WindowHide.key(focus) : "");
        hider.state = result.state;
        hider.save();
        let batch = WindowHide.command(result.moves);
        if (extra) batch = batch === "" ? extra : batch + " ; " + extra;
        if (result.moves.length > 0)
            SoundEvents.requested(typeof result.moves[0].workspace === "number" ? "restore" : "minimize");
        if (batch === "") return result.moves.length;
        // Batches keep their order: a waiting show goes before anything new.
        if (!(shows && hider.showDelay > 0)) hider.flush();
        if (shows && hider.showDelay > 0) {
            later.batches = later.batches.concat([batch]);
            if (!later.running) later.start();
        } else {
            Quickshell.execDetached(["hyprctl", "--instance", "0", "--batch", batch]);
        }
        return result.moves.length;
    }
    // Shows that wait for their motion. A restart while one waits leaves the
    // window hidden with no entry; reconcile adopts it, and Show still works.
    Timer {
        id: later
        interval: hider.showDelay
        property var batches: []
        onTriggered: hider.flush()
    }
    function flush() {
        later.stop();
        const all = later.batches;
        later.batches = [];
        for (const b of all) Quickshell.execDetached(["hyprctl", "--instance", "0", "--batch", b]);
    }

    function hideApp(appId) {
        if (!appId) return 0;
        return hider.run(WindowHide.hideApp(hider.state, hider.rows, appId));
    }

    // One window: the Platinum title bar's collapse box (windows IPC).
    function hideWindow(address) {
        if (!address) return 0;
        return hider.run(WindowHide.hideWindow(hider.state, hider.rows, address));
    }

    // Every other app's windows on one screen.
    function hideOthers(appId, screenName) {
        return hider.run(WindowHide.hideOthers(hider.state, hider.rows, appId || "", screenName || ""));
    }

    // Show an app's hidden windows on their home pages. focusAddress, when
    // given, is focused in the same batch, so it is never focused before
    // it has arrived.
    function showApp(appId, fallbackPage, focusAddress) {
        const focus = focusAddress ? 'dispatch hl.dsp.focus({ window = "address:0x' + WindowHide.key(focusAddress) + '" })' : "";
        return hider.run(WindowHide.showApp(hider.state, hider.rows, appId, fallbackPage), focus, focusAddress || "");
    }

    function showAll(fallbackPage) {
        return hider.run(WindowHide.showAll(hider.state, hider.rows, fallbackPage));
    }

    // Win98: Minimize All Windows on one screen; Restore one window (its
    // app's other windows stay hidden), focused in the same batch when
    // focus is true, then `after` (one more dispatch, such as maximize); a
    // minimized window's Move to Page changes only where Restore will put
    // it.
    function hideScreen(screenName) {
        if (!screenName) return 0;
        return hider.run(WindowHide.hideScreen(hider.state, hider.rows, screenName));
    }
    function showWindow(address, fallbackPage, focus, after) {
        if (!address) return 0;
        let f = focus ? 'dispatch hl.dsp.focus({ window = "address:0x' + WindowHide.key(address) + '" })' : "";
        if (after) f = f === "" ? "dispatch " + after : f + " ; dispatch " + after;
        return hider.run(WindowHide.showWindow(hider.state, hider.rows, address, fallbackPage), f, focus ? address : "");
    }
    function setHome(address, page) {
        hider.state = WindowHide.setHome(hider.state, hider.rows, address, page);
        hider.save();
    }
    function homeOf(address) { return WindowHide.homeOf(hider.state, address); }

    function isHidden(row) {
        return !!row && WindowHide.isHiddenWorkspace(row.workspace);
    }
}
