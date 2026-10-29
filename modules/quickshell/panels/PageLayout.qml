import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "../page-layout-model.js" as Model

// Layout: the bar control's state and its menu (Platinum) or window (Win98)
// for one screen. This Scope owns the state; each theme draws it.
//
// The Hyprland page-layout module (modules/hyprland/page-layout.lua) owns
// every value. It writes $XDG_RUNTIME_DIR/mountainous-page-layout.json after
// each change (format: page-layout-model.js). This Scope only reads that
// file. Every change goes through `mountainous-page-layout`, the command the
// keys use too, so the keys, the bar and the menu cannot disagree.
//
// Two scopes, as tabs: "page" edits the page this screen shows; "default"
// edits what a new page on this screen starts with.
Scope {
    id: root

    required property var screen
    property bool shown: false

    // "page" or "default". Opening the control always starts on This page.
    property string tab: "page"
    onShownChanged: if (root.shown) root.tab = "page"

    readonly property string monitorName: root.screen ? root.screen.name : ""
    readonly property var monitor: Hyprland.monitors.values.find(function (m) { return m.name === root.monitorName; }) || null
    readonly property int pageId: root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
    readonly property var pageIds: Hyprland.workspaces.values
        .filter(function (w) { return w.id > 0 && w.monitor && w.monitor.name === root.monitorName; })
        .map(function (w) { return w.id; })

    property var state: null
    readonly property var view: Model.view(root.state, root.monitorName, root.pageId, root.pageIds)

    // What the bar reads.
    readonly property bool available: root.view.available
    readonly property string glyph: root.view.glyph          // tile-1, tile-2, tile-3, float

    // What the menu reads. "shownValues" is the tab's target: the page or
    // the screen default. While a gap drag is held, or a sent gap has not
    // reached the file yet, gap is the value asked for, not the file's.
    readonly property var page: root.view.page               // cap, floating, gap, zen, own
    readonly property var def: root.view.def                 // cap, floating, gap
    readonly property var shownValues: root.tab === "page" ? root.page : root.def
    readonly property int shownGap: (root.dragging || root.sending || settle.running) && root.requestedGap >= 0
        ? root.requestedGap : root.shownValues.gap
    readonly property int pageIndex: root.view.pageIndex
    readonly property int pageCount: root.view.pageCount
    readonly property int ownCount: root.view.ownCount
    readonly property string title: root.view.title         // "Built-in Display"
    readonly property int capMax: Model.CAP_MAX
    readonly property int gapMax: Model.GAP_MAX
    readonly property int gapStep: Model.GAP_STEP

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/mountainous-page-layout.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const parsed = Model.parse(text());
            if (parsed) root.state = parsed;
        }
    }

    function run(args) {
        Quickshell.execDetached(["mountainous-page-layout"].concat(args));
    }

    // The tab's target. A page id while on This page; the connector name
    // while on Default.
    // Empty while the screen shows no page yet: nothing is sent then.
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
    // This page only: put one field (cap, floating, gap) or "all" back to
    // the screen default.
    function useDefault(field) { if (root.pageId > 0) root.run(["page-default", String(root.pageId), field]); }
    // Default tab only: every page on this screen back to the default.
    function resetPages() { root.run(["reset", root.monitorName]); }
    function stepGap(direction) { root.setGap(root.shownGap + (direction > 0 ? root.gapStep : -root.gapStep)); }

    // A gap drag sends one value at a time, and only the newest waiting
    // value next (as BrightnessPanel does), so it cannot end on a stale step.
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

    // Words the menus share, so both themes say the same thing.
    function word(n) { return Model.word(n); }
    function capNote() { return Model.capNote(root.page); }
}
