.pragma library
// Hide and Show for every theme. Hyprland has no minimise, so a hidden
// window moves, silently, to a special workspace of its own app
// (special:hidden-<app>). Special workspaces have negative ids, so
// lanes.js leaves hidden windows off every strip and taskbar.
//
// A window's home page is written to a state file when it hides, so Show
// returns it to that page even after Quickshell restarts. Hyprland keeps a
// window's address for the window's life, which is what the file is keyed
// by. Show cannot return a window to its old slot in the layout: the layout
// inserts it again where it inserts any arrival.
//
// Plain functions over plain rows, so they run under node. A row is
//   { address: "55d0e1a2b3c0", appId, title, page, workspace, screen }
// where page is the workspace id (negative for a special workspace),
// workspace is its name and screen is the output name. An address is kept
// without its "0x"; command() adds it back.

var PREFIX = "special:hidden-";

function key(address) {
    return String(address || "").replace(/^0x/, "");
}

// The special workspace that holds one app's hidden windows. Hyprland
// accepts any name; the app id is reduced to characters that need no
// quoting inside the Lua dispatcher string.
function workspaceFor(appId) {
    var safe = String(appId || "app").replace(/[^A-Za-z0-9._-]/g, "_");
    return PREFIX + (safe === "" ? "app" : safe);
}

function isHiddenWorkspace(name) {
    return typeof name === "string" && name.indexOf(PREFIX) === 0;
}

function empty() {
    return { version: 1, windows: {} };
}

function parse(text) {
    try {
        var value = JSON.parse(text);
        if (!value || typeof value !== "object" || !value.windows || typeof value.windows !== "object") return empty();
        var out = empty();
        for (var k in value.windows) {
            var e = value.windows[k];
            if (!e || typeof e !== "object") continue;
            var page = typeof e.page === "number" && isFinite(e.page) && e.page > 0 ? Math.floor(e.page) : null;
            out.windows[key(k)] = { app: String(e.app || ""), page: page, screen: String(e.screen || ""), title: String(e.title || "") };
        }
        return out;
    } catch (error) {
        return empty();
    }
}

function serialize(state) {
    return JSON.stringify(state || empty(), null, 1) + "\n";
}

function clone(state) {
    var out = empty();
    var windows = (state && state.windows) || {};
    for (var k in windows) out.windows[k] = Object.assign({}, windows[k]);
    return out;
}

function hidden(row) {
    return !!row && isHiddenWorkspace(row.workspace);
}

// Which rows count as hidden: on a hidden workspace.
function hiddenRows(rows) {
    return (rows || []).filter(hidden);
}

// The app ids that have at least one hidden window.
function hiddenApps(rows) {
    var seen = {}, out = [];
    for (var i = 0; i < (rows || []).length; i++) {
        var r = rows[i];
        if (hidden(r) && !seen[r.appId]) { seen[r.appId] = true; out.push(r.appId); }
    }
    return out;
}

// Forget windows that closed, and adopt windows found on a hidden
// workspace with no entry (hidden before the file existed, or the file was
// lost). An adopted window has no known page; Show sends it to the
// fallback page. An entry for a live window that is not hidden (yet: the
// move is in flight, or someone moved it back by hand) is kept; the next
// hide overwrites it and Show only moves hidden windows.
function reconcile(state, rows) {
    var out = empty(), live = {};
    for (var i = 0; i < (rows || []).length; i++) live[key(rows[i].address)] = rows[i];
    var windows = (state && state.windows) || {};
    for (var k in windows) {
        if (live[k]) out.windows[k] = Object.assign({}, windows[k]);
    }
    for (var a in live) {
        var r = live[a];
        if (hidden(r) && !out.windows[a])
            out.windows[a] = { app: r.appId || "", page: null, screen: r.screen || "", title: r.title || "" };
    }
    return out;
}

// Hide every shown row that `pick` accepts. Returns the new state and the
// moves to dispatch. A window that is between pages (page -1) or already
// hidden is left alone.
function hide(state, rows, pick) {
    var out = clone(state), moves = [];
    for (var i = 0; i < (rows || []).length; i++) {
        var r = rows[i];
        if (!r || !(r.page > 0) || hidden(r) || !pick(r)) continue;
        var k = key(r.address);
        if (k === "") continue;
        out.windows[k] = { app: r.appId || "", page: r.page, screen: r.screen || "", title: r.title || "" };
        moves.push({ address: k, workspace: workspaceFor(r.appId) });
    }
    return { state: out, moves: moves };
}

function hideApp(state, rows, appId) {
    return hide(state, rows, function (r) { return r.appId === appId; });
}

// One window: a Platinum title bar's collapse box. Show brings it back with
// the rest of its app, as for Hide.
function hideWindow(state, rows, address) {
    var k = key(address);
    return hide(state, rows, function (r) { return k !== "" && key(r.address) === k; });
}

// Every shown window on one screen: Win98's Minimize All Windows.
function hideScreen(state, rows, screen) {
    return hide(state, rows, function (r) { return r.screen === screen; });
}

// Mac OS "Hide Others", per screen: every other app's windows on `screen`.
// The same app's windows on another screen, and other screens, stay.
function hideOthers(state, rows, appId, screen) {
    return hide(state, rows, function (r) { return r.appId !== appId && r.screen === screen; });
}

// Show every hidden row that `pick` accepts, on its home page, or on
// `fallbackPage` when the home page is unknown.
function show(state, rows, pick, fallbackPage) {
    var out = clone(state), moves = [];
    var fallback = fallbackPage > 0 ? fallbackPage : 1;
    for (var i = 0; i < (rows || []).length; i++) {
        var r = rows[i];
        if (!hidden(r) || !pick(r)) continue;
        var k = key(r.address);
        var entry = out.windows[k];
        var page = entry && entry.page > 0 ? entry.page : fallback;
        moves.push({ address: k, workspace: page });
        delete out.windows[k];
    }
    return { state: out, moves: moves };
}

function showApp(state, rows, appId, fallbackPage) {
    return show(state, rows, function (r) { return r.appId === appId; }, fallbackPage);
}

function showAll(state, rows, fallbackPage) {
    return show(state, rows, function () { return true; }, fallbackPage);
}

// One window: Win98's Restore (a minimized window's taskbar button). The
// rest of its app stays hidden.
function showWindow(state, rows, address, fallbackPage) {
    var k = key(address);
    return show(state, rows, function (r) { return k !== "" && key(r.address) === k; }, fallbackPage);
}

// Where a window goes when it is shown: its recorded page, or null.
function homeOf(state, address) {
    var e = state && state.windows ? state.windows[key(address)] : null;
    return e && e.page > 0 ? e.page : null;
}

// Give a hidden window another home page without showing it (Win98's
// Move to Page on a minimized window). A window the state does not know
// gets an entry. Returns the new state; nothing moves.
function setHome(state, rows, address, page) {
    var out = clone(state), k = key(address);
    if (k === "" || !(page > 0)) return out;
    var row = null;
    for (var i = 0; i < (rows || []).length; i++) if (key(rows[i].address) === k) row = rows[i];
    if (!row || !hidden(row)) return out;
    var e = out.windows[k] || { app: row.appId || "", page: null, screen: row.screen || "", title: row.title || "" };
    e.page = Math.floor(page);
    out.windows[k] = e;
    return out;
}

// One hyprctl --batch string for a list of moves. follow = false keeps the
// focus where it is (Hyprland's old movetoworkspacesilent).
function command(moves) {
    return (moves || []).map(function (m) {
        var target = typeof m.workspace === "number" ? String(m.workspace) : '"' + m.workspace + '"';
        return 'dispatch hl.dsp.window.move({ window = "address:0x' + key(m.address) + '", workspace = '
            + target + ', follow = false })';
    }).join(" ; ");
}
