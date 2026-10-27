// DEV HARNESS (not delivered): the omni service's public shape
// (OmniBar.qml) for the Win98 harness, fed from find-states.js instead of
// Hyprland, DesktopEntries and the browser. The entry rules are the real
// ones (find-model.js enter/back/close); a run, a navigation or a launch is
// written to the harness log instead of done. Staged at the shell root.
import Quickshell
import QtQuick
import "find-model.js" as FindModel

Scope {
    id: root

    // The harness's screen and its fixture rows.
    property var screen0: null
    property var windowRows: []
    property var appRows: []
    // The window that "had focus" when the service was summoned.
    property var active: null
    signal note(string text)

    property bool shown: false
    property string mode: "root"
    property string query: ""
    property var caller: null
    property var screen: null

    property var views: []
    readonly property bool themed: root.views.length > 0
    function claimView(owner) {
        if (owner && root.views.indexOf(owner) < 0) root.views = root.views.concat([owner]);
        root.note("omni claim " + root.views.length);
    }
    function releaseView(owner) {
        const i = root.views.indexOf(owner);
        if (i >= 0) { const next = root.views.slice(); next.splice(i, 1); root.views = next; }
        root.note("omni release " + root.views.length);
    }

    readonly property var state: ({ shown: root.shown, mode: root.mode, query: root.query, caller: root.caller })
    function apply(next) {
        root.caller = next.caller;
        root.mode = next.mode;
        root.query = next.query;
        root.shown = next.shown;
    }
    function enter(m, text) {
        if (!root.shown) root.screen = root.screen0;
        root.apply(FindModel.enter(root.state, m, root.active, typeof text === "string" ? text : ""));
    }
    function enterRoot() { root.enter("root"); }
    function enterMode(m, text) { root.enter(m, text); }
    function enterNavigate(text) { root.enter("nav", text); }
    function back() { root.apply(FindModel.back(root.state)); }
    function dismiss() { if (root.shown) root.apply(FindModel.close(root.state)); }

    // OmniBar.commandRows, as written in OmniBar.qml.
    readonly property var commandRows: [
        { kind: "cmd", label: "New terminal", detail: "Super+N", act: "term" },
        { kind: "cmd", label: "Go to address", detail: "Ctrl+L", act: "mode:nav" },
        { kind: "cmd", label: "Go to window", detail: "mode", act: "mode:window" },
        { kind: "cmd", label: "Close window", detail: "Super+C", act: "close" },
        { kind: "cmd", label: "Monocle", detail: "Super+M", act: "monocle" },
        { kind: "cmd", label: "Zen", detail: "Super+Shift+M", act: "zen" },
        { kind: "cmd", label: "Mirror workspace", detail: "Super+Shift+G", act: "mirror" },
        { kind: "cmd", label: "Even / golden split", detail: "Super+G", act: "split" },
        { kind: "cmd", label: "Interface scale up", detail: "Super+=", act: "scaleup" },
        { kind: "cmd", label: "Interface scale down", detail: "Super+-", act: "scaledown" },
        { kind: "cmd", label: "Interface scale 100%", detail: "Super+0", act: "scalereset" },
        { kind: "cmd", label: "Toggle bars", detail: "Super+I", act: "chrome" },
        { kind: "cmd", label: "Dark appearance", detail: "Super+D", act: "theme:dark" },
        { kind: "cmd", label: "Light appearance", detail: "Super+D", act: "theme:light" },
        { kind: "cmd", label: "Desktop theme\u2026", detail: "Appearance", act: "theme:picker" },
        { kind: "cmd", label: "Extra dark appearance", detail: "off", act: "theme:extra" },
        { kind: "cmd", label: "Screenshot", detail: "Super+S", act: "shot" }
    ]

    // As OmniBar.run: a window, an app, a recent launch, or a command.
    function run(row) {
        if (!row) return;
        if (row.kind === "window") { root.note("omni activate " + row.label); root.dismiss(); return; }
        if (row.kind === "app") { root.note("omni launch " + row.label); root.dismiss(); return; }
        if (row.kind === "recent") { root.note("omni recent " + (row.entry ? row.entry.name : "")); root.dismiss(); return; }
        const a = row.act;
        if (a === "mode:nav") { root.enterNavigate(); return; }
        if (a === "mode:window") { root.enterMode("window"); return; }
        if (a === "mode:app") { root.enterMode("app"); return; }
        if (a === "mode:cmd") { root.enterMode("cmd"); return; }
        if (a === "mode:root") { root.enterRoot(); return; }
        root.note("omni run " + a);
        root.dismiss();
    }
    function navigateTo(text) {
        const t = (text || "").trim();
        if (t === "") return;
        root.note("omni navigate " + t + (root.caller ? " caller=" + root.caller.title : ""));
        root.dismiss();
    }
}
