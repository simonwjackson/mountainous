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

    function run(result, extra) {
        hider.state = result.state;
        hider.save();
        let batch = WindowHide.command(result.moves);
        if (extra) batch = batch === "" ? extra : batch + " ; " + extra;
        if (batch !== "") Quickshell.execDetached(["hyprctl", "--instance", "0", "--batch", batch]);
        return result.moves.length;
    }

    function hideApp(appId) {
        if (!appId) return 0;
        return hider.run(WindowHide.hideApp(hider.state, hider.rows, appId));
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
        return hider.run(WindowHide.showApp(hider.state, hider.rows, appId, fallbackPage), focus);
    }

    function showAll(fallbackPage) {
        return hider.run(WindowHide.showAll(hider.state, hider.rows, fallbackPage));
    }

    function isHidden(row) {
        return !!row && WindowHide.isHiddenWorkspace(row.workspace);
    }
}
