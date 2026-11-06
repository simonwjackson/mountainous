import Quickshell
import Quickshell.Io
import QtQuick
import "show-desktop.js" as Rule
import "window-hide.js" as WindowHide

// Show Desktop, for every theme. One owner at the shell root (shell.qml
// `showDesktop`): it parks the shown page's windows on the screen's own
// special workspace and brings them back (show-desktop.js), and keeps each
// parked window's page in $XDG_STATE_HOME/mountainous/show-desktop.json so
// a Quickshell restart still restores them to their pages.
//
//   shell.showDesktop.toggle(screenName)   Super+D, Quick Launch,
//                                          Platinum's Application menu
//   shell.showDesktop.active(screenName)   bindable: the desktop is shown
Scope {
    id: owner

    // shell.qml's windowRows.
    required property var rows
    // The page a screen shows: function (name) -> id, or -1.
    property var shownPageOn: null
    // The output names present.
    property var screens: []

    property var state: Rule.empty()

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/mountainous"
    FileView {
        id: file
        path: owner.stateDir + "/show-desktop.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
        onLoaded: owner.state = Rule.parse(file.text())
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", owner.stateDir])

    function save() { file.setText(Rule.serialize(owner.state)); }

    function active(screenName) { return Rule.active(owner.rows, screenName || ""); }
    // Where a parked window came from (the Memphis taskbar's bands).
    function homeOf(address) { return Rule.homeOf(owner.state, address); }
    function screenOf(row) { return Rule.screenOf(owner.state, row); }
    function isParked(row) { return Rule.isParked(row); }

    function pageOf(screenName) {
        const p = typeof owner.shownPageOn === "function" ? owner.shownPageOn(screenName) : -1;
        return p > 0 ? p : 1;
    }

    function run(result) {
        owner.state = result.state;
        owner.save();
        if (result.moves.length === 0) return result.action;
        let batch = WindowHide.command(result.moves);
        if (result.focus) batch += ' ; dispatch hl.dsp.focus({ window = "address:0x' + result.focus + '" })';
        SoundEvents.requested(result.action === "show" ? "minimize" : "restore");
        Quickshell.execDetached(["hyprctl", "--instance", "0", "--batch", batch]);
        return result.action;
    }

    // Returns "show", "restore" or "none".
    function toggle(screenName) {
        const name = screenName || "";
        if (name === "") return "none";
        return owner.run(Rule.toggle(owner.state, owner.rows, name, owner.pageOf(name), { screens: owner.screens }));
    }
    function restoreWindow(address, screenName) {
        return owner.run(Rule.restoreWindow(owner.state, owner.rows, address, owner.pageOf(screenName || "")));
    }
}
