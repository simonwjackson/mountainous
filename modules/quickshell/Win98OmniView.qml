import Quickshell
import QtQuick
import "find-model.js" as FindModel

// The Win98 Desktop's view of the omni service (OmniBar.qml): the Find
// window (Super+P, F1, Start ▸ Find, Start ▸ Run…) and Internet Explorer's
// Open dialog (Ctrl+L). The same contract as the Platinum Desktop's: while its
// Desktop is active it claims the view, so the service's unthemed card
// stays hidden, and it releases the view when the Desktop goes inactive or
// is destroyed. The service's screen picks which Desktop draws it. Both
// are entries in the shared MenuState ("find", "address"), so one menu or
// window is open at a time and a click outside closes it; closing either
// closes the service.
Scope {
    id: view

    required property var desktop
    readonly property var omni: view.desktop.context.omniBar
    readonly property var screen: view.desktop.screen
    property bool claimed: false

    function claim() {
        const o = view.omni;
        if (!o || typeof o.claimView !== "function") return;
        if (view.desktop.active && !view.claimed) { o.claimView(view.desktop); view.claimed = true; }
        else if (!view.desktop.active && view.claimed) {
            o.releaseView(view.desktop);
            view.claimed = false;
            if (o.shown && o.screen === view.screen) o.dismiss();
        }
    }
    Connections {
        target: view.desktop
        function onActiveChanged() { view.claim(); }
    }
    Component.onCompleted: view.claim()
    Component.onDestruction: {
        const o = view.omni;
        if (o && view.claimed && typeof o.releaseView === "function") o.releaseView(view.desktop);
    }

    // Which of the two the service wants on this screen, read when asked
    // (not a binding: the window and the service move each other).
    function want() {
        const o = view.omni;
        if (!view.desktop.active || !view.claimed || !o || o.shown !== true || o.screen !== view.screen) return "";
        return o.mode === "nav" ? "address" : "find";
    }
    // The service changed: open or close the window on the next turn of the
    // event loop, once the service's own change has finished.
    property bool syncing: false
    Timer {
        id: omniSync
        interval: 0
        onTriggered: view.sync()
    }
    function sync() {
        const name = view.want();
        view.syncing = true;
        if (name !== "") {
            if (MenuState.current !== name || MenuState.screen !== view.screen) {
                view.desktop.shell.chromeAccessVisible = false;
                view.desktop.taskbarFocus = "";
                MenuState.open(name, view.screen, -1);
            }
        } else if (MenuState.screen === view.screen && (MenuState.current === "find" || MenuState.current === "address")) {
            MenuState.close();
        }
        view.syncing = false;
    }
    Connections {
        target: view.omni
        ignoreUnknownSignals: true
        function onShownChanged() { omniSync.restart(); }
        function onModeChanged() { omniSync.restart(); }
        function onScreenChanged() { omniSync.restart(); }
    }
    // Another menu, or a click outside, closed the window: the service
    // closes with it.
    Connections {
        target: MenuState
        function onCurrentChanged() {
            if (view.syncing) return;
            const w = view.want();
            if (w !== "" && (MenuState.current !== w || MenuState.screen !== view.screen)) view.omni.dismiss();
        }
    }

    // A chosen row or a request from the window, run on the next turn of
    // the event loop: the window that emitted it may be replaced (Find →
    // Open) or closed by what it runs.
    Timer {
        id: actionDispatch
        interval: 0
        property var pending: null
        onTriggered: {
            const action = actionDispatch.pending;
            actionDispatch.pending = null;
            view.perform(action.kind, action.arg);
        }
    }
    function findAction(kind, arg) {
        actionDispatch.pending = {kind: kind, arg: arg};
        actionDispatch.restart();
    }
    function perform(kind, arg) {
        const o = view.omni;
        if (!o) return;
        if (kind === "close") { o.dismiss(); return; }
        if (kind === "address") { o.enterNavigate(arg || ""); return; }
        if (kind === "go") { o.navigateTo(arg || ""); return; }
        if (kind === "find") { o.enterRoot(); return; }
        if (kind !== "row" || !arg) return;
        switch (arg.k) {
        case "win": case "app": case "cmd": o.run(arg.ref); break;
        case "recent": o.run({ kind: "recent", entry: arg.entry }); break;
        case "scope": o.enterMode(FindModel.modeOf(arg.to), arg.keep ? o.query : ""); break;
        case "addr": o.enterNavigate(arg.text || ""); break;
        }
    }
    // Start ▸ Find ▸ <scope>, Start ▸ Run… (all) and Start ▸ Find ▸ Address….
    function openScope(scope) {
        const o = view.omni;
        if (!o) return;
        if (scope === "address") o.enterNavigate("");
        else if (scope === "all" || !scope) o.enterRoot();
        else o.enterMode(FindModel.modeOf(scope));
    }
}
