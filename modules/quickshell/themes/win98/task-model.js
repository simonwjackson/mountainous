.pragma library
// The Win98 taskbar's windows and the two menus that act on them, as pure
// functions of plain values (shell.qml's windowRows and WindowHider's
// state), so node can test them.
//
// Win98 kept a minimized window's button on the taskbar, raised. Here a
// minimized window is the shared hide (window-hide.js): it sits on its
// app's special workspace, which lanes.js leaves off every taskbar and
// strip. So the Win98 taskbar reads its own list: every window shown on
// this screen, plus every hidden window whose home screen is this one, each
// in its home page's band. lanes.js and the Platinum strip are unchanged.
//
// A row is { address, appId, title, page, workspace, screen, toplevel }
// (shell.qml rowOf); an address has no "0x".

var HIDDEN = "special:hidden-";

function key(address) { return String(address || "").replace(/^0x/, ""); }
function isHidden(row) { return !!row && typeof row.workspace === "string" && row.workspace.indexOf(HIDDEN) === 0; }

// rows: windowRows in Hyprland's order; hidden: WindowHider.state;
// screen: this screen's output name; opts: { screens (output names; the
// first is the primary), fallbackPage (the page this screen shows) }.
// Returns [{ row, home, minimized }]: by home page, Hyprland's order inside
// a page (so a button keeps its place when its window is minimized).
// A hidden window whose home screen is gone (the tablet left) shows on the
// primary screen; one with no known page, on fallbackPage.
function lane(rows, hidden, screen, opts) {
    var o = opts || {}, out = [];
    if (!screen) return out;
    var screens = o.screens || [];
    var fallback = o.fallbackPage > 0 ? o.fallbackPage : 1;
    var entries = (hidden && hidden.windows) || {};
    var list = rows || [];
    for (var i = 0; i < list.length; i++) {
        var r = list[i];
        if (!r) continue;
        if (!isHidden(r)) {
            if (r.page > 0 && r.screen === screen) out.push({ row: r, home: r.page, minimized: false, at: i });
            continue;
        }
        var e = entries[key(r.address)] || null;
        var where = (e && e.screen) || r.screen || "";
        if (screens.length && screens.indexOf(where) < 0) where = screens[0];
        if (where !== screen) continue;
        out.push({ row: r, home: e && e.page > 0 ? e.page : fallback, minimized: true, at: i });
    }
    out.sort(function (a, b) { return a.home - b.home || a.at - b.at; });
    return out.map(function (x) { return { row: x.row, home: x.home, minimized: x.minimized }; });
}

// Pages are never numbered on screen (Simon: pages are ephemeral, not
// places); a page is named by the apps on it. names(page, exceptAddress):
// the app names on a page, left to right; label: page-names.js pageLabel.

// The app names on one page of the lane, left to right, without one window.
function pageApps(entries, page, appName, exceptAddress) {
    var out = [];
    for (var i = 0; i < (entries || []).length; i++) {
        var e = entries[i];
        if (e.home !== page || (exceptAddress && key(e.row.address) === key(exceptAddress))) continue;
        out.push(appName ? appName(e.row.appId) : e.row.appId);
    }
    return out;
}

// Move to ▸: every page on this screen in order (its windows' home pages
// and the page it shows), each named by the apps on it without the window
// being moved; the window's own page checked and disabled ("On its own"
// when it is alone there); an empty page "Empty page"; then New Page,
// numbered after every page on every screen (Hyprland numbers pages
// globally; the number never shows).
// o: { entries (lane), address, page (the window's), shownPage, pageIds,
//      appName (id -> name), label (pageLabel) }
function movePages(o) {
    var seen = {}, pages = [];
    var add = function (p) { if (p > 0 && !seen[p]) { seen[p] = true; pages.push(p); } };
    for (var i = 0; i < (o.entries || []).length; i++) add(o.entries[i].home);
    add(o.shownPage);
    pages.sort(function (a, b) { return a - b; });
    var top = 0;
    for (var j = 0; j < (o.pageIds || []).length; j++) if (o.pageIds[j] > top) top = o.pageIds[j];
    for (var k = 0; k < pages.length; k++) if (pages[k] > top) top = pages[k];
    var label = o.label || function (n) { return n.join(", "); };
    return {
        pages: pages.map(function (p) {
            var names = pageApps(o.entries, p, o.appName, o.address);
            var current = p === o.page;
            var text = names.length ? label(names) : current ? "On its own" : "Empty page";
            return { page: p, current: current, label: text };
        }),
        newPage: top + 1
    };
}

// The window menu: a taskbar button's right click, the caption icon and
// Alt+Space (windows menu IPC). Win98's system menu less Move and Size
// (Hyprland tiles), plus Move to ▸. o: { minimized, maximized,
// move (movePages) }. Each item's act names the Desktop's action. Page
// labels are data: a literal "&" stays one.
function windowMenu(o) {
    var m = o.move || { pages: [], newPage: 1 };
    var sub = m.pages.map(function (p) {
        return { text: String(p.label).replace(/&/g, "&&"), checked: p.current, enabled: !p.current, act: "move", page: p.page };
    });
    if (sub.length) sub.push({ separator: true });
    sub.push({ text: "&New Page", act: "move", page: m.newPage });
    return [
        { text: "&Restore", icon: "restore", enabled: !!(o.minimized || o.maximized), act: "restore" },
        { text: "&Move to", submenu: sub },
        { text: "Mi&nimize", icon: "minimize", enabled: !o.minimized, act: "minimize" },
        { text: "Ma&ximize", icon: "maximize", enabled: !o.maximized, act: "maximize" },
        { separator: true },
        { text: "&Close", icon: "close", bold: true, shortcut: "Alt+F4", act: "close" }
    ];
}

// The taskbar's own menu (a right click where no button is). o: { shown
// (windows shown on this screen), others (of those, not the front
// window's app), hidden (hidden windows anywhere) }. Restore All is the
// shared Show All, so it acts on every screen, as Platinum's does.
function taskbarMenu(o) {
    return [
        { text: "&Minimize All Windows", enabled: o.shown > 0, act: "minimizeAll" },
        { text: "Minimize &Other Windows", enabled: o.others > 0, act: "minimizeOthers" },
        { text: "&Restore All Windows", enabled: o.hidden > 0, act: "restoreAll" },
        { separator: true },
        { text: "&Find...", shortcut: "Super+P", act: "find" }
    ];
}

// The Cool Switch box (held Super+Tab): 32-u icons in 43-u cells, up to 7
// a row, fewer when the screen is narrow. Rows past the room scroll to keep
// the current one in view, with "N more rows above/below". Sizes in units.
var COOL = { cell: 43, cols: 7, pad: 8, title: 20, gap: 6, more: 13 };
function coolPlan(count, current, widthU, heightU) {
    var n = Math.max(0, count);
    if (n === 0) return { cols: 0, rows: 0, shown: 0, first: 0, above: 0, below: 0, width: 0, height: 0 };
    var cols = Math.max(1, Math.min(COOL.cols, n, Math.floor((widthU - 4 - 2 * COOL.pad) / COOL.cell)));
    var rows = Math.ceil(n / cols);
    var fixed = 2 * COOL.pad + COOL.gap + COOL.title;
    var room = Math.max(1, Math.floor((heightU - 4 - fixed) / COOL.cell));
    var shown = Math.min(rows, room);
    if (shown < rows) shown = Math.max(1, Math.min(rows, Math.floor((heightU - 4 - fixed - COOL.gap - COOL.more) / COOL.cell)));
    var cur = Math.max(0, Math.min(n - 1, current));
    var row = Math.floor(cur / cols);
    var first = Math.max(0, Math.min(rows - shown, row - shown + 1));
    var more = rows > shown;
    var width = Math.min(cols * COOL.cell + 2 * COOL.pad, Math.max(0, widthU - 4));
    return {
        cols: cols, rows: rows, shown: shown, first: first,
        above: first, below: rows - first - shown,
        width: width,
        height: 2 * COOL.pad + shown * COOL.cell + COOL.gap + COOL.title + (more ? COOL.gap + COOL.more : 0)
    };
}
function moreText(above, below) {
    var part = function (n, where) { return n ? n + " more row" + (n > 1 ? "s" : "") + " " + where : ""; };
    var a = part(above, "above"), b = part(below, "below");
    return a && b ? a + ", " + b : a || b;
}
