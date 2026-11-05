.pragma library
// Show Desktop, for every theme: Super+Shift+D, the Memphis Quick Launch
// button and the taskbar menu, Platinum's Application menu (Show Desktop,
// and Hide Others while the desktop is in front). The windows of the page
// a screen shows move, silently, to that screen's own special workspace
// (special:desktop-<output>), which no strip or taskbar lists; running it
// again brings them back to their pages.
//
// One rule decides what a toggle does, from what is on the screen now,
// never from a remembered mode, so windows that open or close in between
// cannot confuse it:
//   - windows cover the page             park them (beside any already
//                                        parked): the desktop shows;
//   - nothing covers it, some are parked bring every parked window back to
//                                        the page it left, and focus the
//                                        window that had focus;
//   - nothing covers it, none parked     nothing.
// A window that opened while the desktop showed stays where it opened; one
// that closed is simply gone (its entry is forgotten). A parked window
// whose page is unknown (the state file was lost) returns to the page the
// screen shows. A parked window of a screen that left (the tablet) comes
// back with the next restore on any screen.
//
// Plain functions over shell.qml's window rows, so node tests them:
//   { address (no "0x"), appId, title, page, workspace, screen, active }
// The state: { version: 1, screens: { <output>: { focus, windows: { <address>: page } } } }.

var PREFIX = "special:desktop-";

function key(address) { return String(address || "").replace(/^0x/, ""); }

function workspaceFor(screen) {
    var safe = String(screen || "").replace(/[^A-Za-z0-9._-]/g, "_");
    return PREFIX + (safe === "" ? "screen" : safe);
}
function isParkedWorkspace(name) { return typeof name === "string" && name.indexOf(PREFIX) === 0; }
function isParked(row) { return !!row && isParkedWorkspace(row.workspace); }

function empty() { return { version: 1, screens: {} }; }

function parse(text) {
    try {
        var v = JSON.parse(text);
        var out = empty();
        if (!v || typeof v !== "object" || !v.screens || typeof v.screens !== "object") return out;
        for (var s in v.screens) {
            var e = v.screens[s];
            if (!e || typeof e !== "object") continue;
            var windows = {};
            for (var a in (e.windows || {})) {
                var p = e.windows[a];
                windows[key(a)] = typeof p === "number" && isFinite(p) && p > 0 ? Math.floor(p) : null;
            }
            out.screens[String(s)] = { focus: key(e.focus || ""), windows: windows };
        }
        return out;
    } catch (error) {
        return empty();
    }
}
function serialize(state) { return JSON.stringify(state || empty(), null, 1) + "\n"; }

function clone(state) {
    var out = empty(), screens = (state && state.screens) || {};
    for (var s in screens) out.screens[s] = { focus: screens[s].focus || "", windows: Object.assign({}, screens[s].windows || {}) };
    return out;
}

// The rows parked for one screen.
function parkedOn(rows, screen) {
    var ws = workspaceFor(screen);
    return (rows || []).filter(function (r) { return r && r.workspace === ws; });
}

// The rows that cover the desktop on a screen: on the page it shows.
function covering(rows, screen, page) {
    return (rows || []).filter(function (r) { return r && r.page > 0 && r.page === page && r.screen === screen && key(r.address) !== ""; });
}

// True while the desktop of `screen` is shown by Show Desktop: some window
// of that screen is parked.
function active(rows, screen) { return parkedOn(rows, screen).length > 0; }

// Forget windows that closed and screens with nothing parked; adopt
// parked windows the state does not know (page unknown).
function reconcile(state, rows) {
    var live = {}, out = empty(), src = (state && state.screens) || {};
    (rows || []).forEach(function (r) { if (r) live[key(r.address)] = r; });
    for (var s in src) {
        var windows = {};
        for (var a in src[s].windows) if (live[a] && isParked(live[a])) windows[a] = src[s].windows[a];
        if (Object.keys(windows).length) out.screens[s] = { focus: live[src[s].focus] ? src[s].focus : "", windows: windows };
    }
    (rows || []).forEach(function (r) {
        if (!isParked(r)) return;
        var k = key(r.address);
        for (var s2 in out.screens) if (k in out.screens[s2].windows) return;
        var name = null;
        for (var s3 in src) if (workspaceFor(s3) === r.workspace) name = s3;
        if (name === null) name = r.workspace.slice(PREFIX.length);
        if (!out.screens[name]) out.screens[name] = { focus: "", windows: {} };
        out.screens[name].windows[k] = null;
    });
    return out;
}

// Toggle one screen. page: the page it shows; opts: { screens: the
// output names present (a parked window of any other screen comes back
// too) }. Returns { action: "show" | "restore" | "none", state, moves,
// focus } where moves are window-hide.js moves ({ address, workspace })
// and focus is the address to focus after a restore, or "".
function toggle(state, rows, screen, page, opts) {
    var o = opts || {};
    var next = reconcile(state, rows);
    var cover = covering(rows, screen, page);
    if (cover.length > 0) {
        var entry = next.screens[screen] || { focus: "", windows: {} };
        var focused = cover.filter(function (r) { return r.active; })[0];
        if (focused && !entry.focus) entry.focus = key(focused.address);
        var ws = workspaceFor(screen);
        var moves = cover.map(function (r) {
            entry.windows[key(r.address)] = r.page;
            return { address: key(r.address), workspace: ws };
        });
        next.screens[screen] = entry;
        return { action: "show", state: next, moves: moves, focus: "" };
    }
    var present = o.screens || [];
    var back = (rows || []).filter(function (r) {
        if (!isParked(r)) return false;
        if (r.workspace === workspaceFor(screen)) return true;
        if (!present.length) return false;
        return !present.some(function (s) { return workspaceFor(s) === r.workspace; });
    });
    if (!back.length) return { action: "none", state: next, moves: [], focus: "" };
    var fallback = page > 0 ? page : 1;
    var focus = "";
    var restoreMoves = back.map(function (r) {
        var k = key(r.address), home = null;
        for (var s in next.screens) {
            if (k in next.screens[s].windows) {
                home = next.screens[s].windows[k];
                if (next.screens[s].focus === k) focus = k;
                delete next.screens[s].windows[k];
            }
        }
        return { address: k, workspace: home > 0 ? home : fallback };
    });
    for (var s4 in next.screens) if (!Object.keys(next.screens[s4].windows).length) delete next.screens[s4];
    return { action: "restore", state: next, moves: restoreMoves, focus: focus };
}

// One parked window back on its page (a Memphis taskbar button), or
// nothing when it is not parked. The rest stay parked.
function restoreWindow(state, rows, address, fallbackPage) {
    var k = key(address);
    var next = reconcile(state, rows);
    var row = (rows || []).filter(function (r) { return r && key(r.address) === k && isParked(r); })[0];
    if (!row) return { action: "none", state: next, moves: [], focus: "" };
    var home = null;
    for (var s in next.screens) {
        if (k in next.screens[s].windows) {
            home = next.screens[s].windows[k];
            delete next.screens[s].windows[k];
            if (next.screens[s].focus === k) next.screens[s].focus = "";
            if (!Object.keys(next.screens[s].windows).length) delete next.screens[s];
        }
    }
    return { action: "restore", state: next, moves: [{ address: k, workspace: home > 0 ? home : (fallbackPage > 0 ? fallbackPage : 1) }], focus: k };
}

// A parked window's page, for the Memphis taskbar's band, or null.
function homeOf(state, address) {
    var k = key(address), screens = (state && state.screens) || {};
    for (var s in screens) if (k in screens[s].windows) return screens[s].windows[k] > 0 ? screens[s].windows[k] : null;
    return null;
}
// A parked window's screen (the output whose workspace holds it), or "".
function screenOf(state, row) {
    if (!isParked(row)) return "";
    var screens = (state && state.screens) || {};
    for (var s in screens) if (workspaceFor(s) === row.workspace) return s;
    return row.workspace.slice(PREFIX.length);
}
