.pragma library
// The Platinum Control Strip: one screen's windows across all of its pages,
// as square tiles at the bottom left, grouped by page with an engraved
// groove between pages. A pure function of the strip's inputs, so the
// drawn strip and its tests make the same decision.
//
//   [cap][◂][ tile tile | tile tile tile | tile ][▸][tab)
//
// The cap collapses the strip; the tab collapses and expands it, and
// dragging the tab sets the strip's length in whole tiles. When the
// windows do not fit the length (or the screen), the scroll arrows appear
// and the track scrolls. The band the strip sits in is reserved at its
// full width, and collapsing never changes it, so windows never resize.

var TILE = 30, GROOVE = 10, GAP = 2, PAD = 2;
var CAP = 12, ARROW = 15, TAB = 18;
var HEIGHT = 36, BOTTOM = 6, BAND = HEIGHT + BOTTOM;
var RIGHT_EDGE = 6;          // the strip stops this far short of the right edge
var MIN_AREA = TILE + 2 * PAD;

// Window order inside a page. "position" sorts by where the window sits on
// screen (left to right, then top to bottom), so a swap moves the tiles
// with the windows. Rows without a position keep the compositor's order.
function order(rows) {
    var list = (rows || []).slice();
    var at = list.slice();
    list.sort(function (a, b) {
        if (a.page !== b.page) return a.page - b.page;
        var ax = typeof a.x === "number", bx = typeof b.x === "number";
        if (ax && bx) {
            if (a.x !== b.x) return a.x - b.x;
            if (a.y !== b.y) return (a.y || 0) - (b.y || 0);
        }
        return at.indexOf(a) - at.indexOf(b);
    });
    return list;
}

// Tiles and grooves along the track. x is the slot's left edge inside the
// track; content is the track's whole width with its end padding.
function slots(rows) {
    var out = [], x = PAD;
    for (var i = 0; i < (rows || []).length; i++) {
        var r = rows[i];
        if (i > 0 && rows[i - 1].page !== r.page && rows[i - 1].page > 0 && r.page > 0) {
            out.push({ kind: "groove", x: x, w: GROOVE, page: r.page });
            x += GROOVE + GAP;
        }
        out.push({ kind: "tile", x: x, w: TILE, index: i, page: r.page });
        x += TILE + GAP;
    }
    return { slots: out, content: out.length === 0 ? 0 : x - GAP + PAD };
}

// length is the saved track length (null: as long as the windows need).
// emptyWidth is the "No windows" label's width when there is no tile.
function plan(screenWidth, content, length, emptyWidth) {
    var maxTotal = Math.max(0, screenWidth - RIGHT_EDGE);
    if (content <= 0) {
        var ew = Math.max(0, Math.min(emptyWidth || 0, maxTotal - CAP - TAB));
        return { area: ew, arrows: false, maxScroll: 0, total: CAP + ew + TAB, empty: true, fullLength: true };
    }
    var want = length === null || length === undefined ? content : Math.max(MIN_AREA, Math.min(length, content));
    var area = want, arrows = false;
    if (CAP + area + TAB > maxTotal || want < content) {
        arrows = true;
        area = Math.max(MIN_AREA, Math.min(want, maxTotal - CAP - 2 * ARROW - TAB));
    }
    if (area >= content) { arrows = false; area = content; }
    var total = CAP + area + TAB + (arrows ? 2 * ARROW : 0);
    return { area: area, arrows: arrows, maxScroll: Math.max(0, content - area), total: total, empty: false,
             fullLength: length === null || length === undefined || length >= content };
}

function clampScroll(scroll, maxScroll) {
    return Math.max(0, Math.min(scroll || 0, maxScroll || 0));
}

// One arrow click moves to the next slot edge in that direction.
function scrollStep(list, scroll, dir, maxScroll) {
    var edges = list.map(function (s) { return s.x - PAD; });
    var next;
    if (dir > 0) {
        next = maxScroll;
        for (var i = 0; i < edges.length; i++) if (edges[i] > scroll + 1) { next = edges[i]; break; }
        return Math.min(maxScroll, next);
    }
    next = 0;
    for (var j = edges.length - 1; j >= 0; j--) if (edges[j] < scroll - 1) { next = edges[j]; break; }
    return Math.max(0, next);
}

// The scroll that brings a slot fully into view, changing as little as
// possible (keyboard focus and a new focused window use it).
function scrollToShow(slot, scroll, area, maxScroll) {
    if (!slot) return clampScroll(scroll, maxScroll);
    var s = scroll;
    if (slot.x - PAD < s) s = slot.x - PAD;
    else if (slot.x + slot.w + PAD > s + area) s = slot.x + slot.w + PAD - area;
    return clampScroll(s, maxScroll);
}

// Dragging the tab: the length follows the pointer in whole tiles. Past
// the content it means "full length" (null), which then grows with new
// windows; below one tile it stays one tile.
function dragLength(startArea, dx, content) {
    var raw = startArea + dx;
    if (content > 0 && raw >= content - GAP) return null;
    var n = Math.max(1, Math.round((raw - 2 * PAD + GAP) / (TILE + GAP)));
    return Math.max(MIN_AREA, n * (TILE + GAP) - GAP + 2 * PAD);
}

// What dropping one tile on another means, and the label the drag shows.
function drop(rows, from, to, names) {
    var a = rows[from], b = rows[to];
    if (!a || !b || from === to || !(a.page > 0) || !(b.page > 0)) return { kind: "none", label: "" };
    if (a.page === b.page)
        return { kind: "swap", label: "Swap with " + ((names && names[b.appId]) || b.appId || "window") };
    return { kind: "move", page: b.page, label: "Move to page " + b.page };
}

// The tile menu's Move to page ▸ rows: every page this screen has (and the
// one it shows), then a new page, numbered after every page on every
// screen (Hyprland numbers pages globally).
function movePages(rows, windowPage, shownPage, allPageIds) {
    var seen = {}, pages = [];
    var add = function (p) { if (p > 0 && !seen[p]) { seen[p] = true; pages.push(p); } };
    for (var i = 0; i < (rows || []).length; i++) add(rows[i].page);
    add(shownPage);
    pages.sort(function (a, b) { return a - b; });
    var top = 0;
    for (var j = 0; j < (allPageIds || []).length; j++) if (allPageIds[j] > top) top = allPageIds[j];
    for (var k = 0; k < pages.length; k++) if (pages[k] > top) top = pages[k];
    return {
        pages: pages.map(function (p) {
            return { page: p, label: "Page " + p + (p === shownPage ? " (showing)" : ""), current: p === windowPage };
        }),
        newPage: top + 1,
    };
}

// The saved strip, per screen: { "<output>": { collapsed, length } }.
function parseState(text) {
    var out = {};
    try {
        var v = JSON.parse(text);
        if (!v || typeof v !== "object" || Array.isArray(v)) return out;
        for (var name in v) {
            var e = v[name];
            if (!e || typeof e !== "object") continue;
            var len = typeof e.length === "number" && isFinite(e.length) && e.length >= MIN_AREA ? Math.round(e.length) : null;
            out[name] = { collapsed: e.collapsed === true, length: len };
        }
    } catch (error) {}
    return out;
}

function screenState(all, name) {
    var e = all && all[name];
    return e ? { collapsed: !!e.collapsed, length: e.length === undefined ? null : e.length } : { collapsed: false, length: null };
}

function withScreen(all, name, entry) {
    var out = {};
    for (var k in (all || {})) out[k] = all[k];
    out[name] = { collapsed: !!entry.collapsed, length: entry.length === undefined ? null : entry.length };
    return out;
}
