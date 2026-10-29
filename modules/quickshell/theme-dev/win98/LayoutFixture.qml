// DEV HARNESS (not delivered): PageLayout's public shape
// (panels/PageLayout.qml, Contract 3 in docs/plans/page-layout-control.md)
// for the Win98 harness. The harness runs under sway, where Quickshell's
// Hyprland module has no monitors and no workspaces, so the real Scope
// would never show a page. This twin reads the same state file
// ($XDG_RUNTIME_DIR/mountainous-page-layout.json) through the same
// page-layout-model.js, takes the page this screen shows from the harness,
// and sends every change through the same `mountainous-page-layout`
// command (the session's stand-in, page-layout-stub.js, edits the file).
// Staged at the shell root.
import Quickshell
import Quickshell.Io
import QtQuick
import "page-layout-model.js" as Model

Scope {
    id: root

    // The harness's screen name for the file (the headless output stands
    // in for Myoko's eDP-1), the page it shows and its pages.
    property string monitorName: "eDP-1"
    property int pageId: -1
    property var pageIds: []
    property bool shown: false

    property string tab: "page"
    onShownChanged: if (root.shown) root.tab = "page"

    property var state: null
    readonly property var view: Model.view(root.state, root.monitorName, root.pageId, root.pageIds)

    readonly property bool available: root.view.available
    readonly property string glyph: root.view.glyph
    readonly property var page: root.view.page
    readonly property var def: root.view.def
    readonly property var shownValues: root.tab === "page" ? root.page : root.def
    readonly property int shownGap: (root.dragging || root.sending || settle.running) && root.requestedGap >= 0
        ? root.requestedGap : root.shownValues.gap
    readonly property int pageIndex: root.view.pageIndex
    readonly property int pageCount: root.view.pageCount
    readonly property int ownCount: root.view.ownCount
    readonly property string title: root.view.title
    readonly property int capMax: Model.CAP_MAX
    readonly property int gapMax: Model.GAP_MAX
    readonly property int gapStep: Model.GAP_STEP

    // The harness hands over what it just wrote, so the state is there
    // before the state's menu opens (a late tray change rebuilds the
    // taskbar's plan and closes an open Start cascade). The file is read
    // once more to start watching it, if it did not exist before; the same
    // text twice changes nothing.
    property string lastText: ""
    property bool watching: false
    function take(text) {
        if (text === root.lastText) return;
        root.lastText = text;
        // An empty file is the harness's "no file" (unavailable).
        if (text.trim() === "") { root.state = null; return; }
        const parsed = Model.parse(text);
        if (parsed) root.state = parsed;
    }
    function load(text) {
        root.take(text);
        if (!root.watching) file.reload();
    }
    FileView {
        id: file
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/mountainous-page-layout.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { root.watching = true; root.take(text()); }
    }

    function run(args) { Quickshell.execDetached(["mountainous-page-layout"].concat(args)); }
    function target() {
        if (root.tab === "page") return root.pageId > 0 ? ["page", String(root.pageId)] : [];
        return root.monitorName !== "" ? ["default", root.monitorName] : [];
    }
    function send(values) {
        const t = root.target();
        if (t.length > 0) root.run(t.concat(values));
    }
    function setArrange(floating) { root.send(["floating=" + (floating ? "true" : "false")]); }
    function setCap(n) { root.send(["cap=" + n]); }
    function toggleZen() { if (root.pageId > 0) root.run(["page", String(root.pageId), "zen=" + (root.page.zen ? "false" : "true")]); }
    function useDefault(field) { if (root.pageId > 0) root.run(["page-default", String(root.pageId), field]); }
    function resetPages() { root.run(["reset", root.monitorName]); }
    function stepGap(direction) { root.setGap(root.shownGap + (direction > 0 ? root.gapStep : -root.gapStep)); }

    property bool dragging: false
    property int requestedGap: -1
    property var pendingArgs: null
    readonly property bool sending: setter.running || root.pendingArgs !== null

    Timer { id: settle; interval: 400 }
    onShownValuesChanged: if (root.shownValues.gap === root.requestedGap) settle.stop()

    Process {
        id: setter
        onExited: {
            root.flush();
            if (!root.sending) settle.restart();
        }
    }
    function flush() {
        if (setter.running || root.pendingArgs === null) return;
        setter.command = ["mountainous-page-layout"].concat(root.pendingArgs);
        root.pendingArgs = null;
        setter.running = true;
    }
    function setGap(value) {
        if (root.target().length === 0) return;
        const v = Model.clampGap(value);
        if (v === root.requestedGap && root.sending) return;
        root.requestedGap = v;
        root.pendingArgs = root.target().concat(["gap=" + v]);
        root.flush();
    }

    function word(n) { return Model.word(n); }
    function capNote() { return Model.capNote(root.page); }
}
