.pragma library
.import "../../page-names.js" as PageNames
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

// A tile is wider than tall, as a Mac OS 8 Control Strip module: the icon,
// then a column for the ▴ (tileGeometry). Logical px; even, so every edge
// is a whole device pixel at scale 1.5.
var TILE_W = 40, TILE_H = 32, GROOVE = 10, GAP = 2, PAD = 2;
var CAP = 12, ARROW = 15, TAB = 18;
var HEIGHT = 38, BOTTOM = 6, BAND = HEIGHT + BOTTOM;
var RIGHT_EDGE = 6;          // the strip stops this far short of the right edge
var MIN_AREA = TILE_W + 2 * PAD;
// The icon's optical padding: logical px from the inside of the bevel to
// the icon's opaque bounds (outline, depth and shadow included), top, left
// and bottom. The icon's optical size is what is left (tileGeometry). And
// the ▴ (7 x 5 logical).
var ICON_PAD = 6, POP_W = 7, POP_H = 5;
// The least gap, in device px, between the icon's box and the ▴, pressed in
// (the icon one device px down and right) included.
var MIN_POP_GAP = 2;

// The Platinum token renderer's margin (scripts/platinum_icons.py margin)
// and the smallest token canvas whose inner box is box px (canvas_for).
function tokenMargin(size) { return Math.max(2, Math.floor(size / 16)); }
function canvasFor(box) {
    for (var s = box; s < 2 * box + 8; s++) if (s - 2 * tokenMargin(s) === box) return s;
    return box + 4;
}

// One tile's parts in whole device px from its top-left corner, at device
// pixel ratio dpr. Every icon has one optical size: its opaque bounds fill
// the box, extent px on their longest side, centred in it by those bounds.
// The strip's icons are Platinum tokens rendered to that extent
// (platinum_icons.py render_extent): at run time for a Chromium window's
// site icon, at build time for every app (platinum-app-tokens.py, the
// mountainous.strip.<name> icons). Each is a canvas px image with the
// renderer's margin clear around the box, drawn 1:1 at canvas.
//
//   bevel   the raised or sunken edge, one hair (2 px at 1.5)
//   pad     from the inside of the bevel to the box: top, left and bottom
//   extent  the box's size: every icon's opaque size (26 px at 1.5)
//   pop     the ▴, one hair inside the bevel at the bottom right
//   gap     from the box's right edge to the ▴, at rest; pressed in, one less
function tileGeometry(dpr) {
    var d = dpr > 0 ? dpr : 1;
    var w = Math.round(TILE_W * d), h = Math.round(TILE_H * d);
    var bevel = Math.max(1, Math.round(d));
    var pad = Math.round(ICON_PAD * d);
    var size = h - 2 * bevel - 2 * pad;
    var canvas = canvasFor(size);
    var margin = (canvas - size) / 2;
    var box = { x: bevel + pad, y: bevel + pad, size: size };
    var pop = { w: Math.round(POP_W * d), h: Math.round(POP_H * d) };
    pop.x = w - 2 * bevel - pop.w;
    pop.y = h - 2 * bevel - pop.h;
    return {
        dpr: d, w: w, h: h, bevel: bevel, pad: pad, margin: margin, sunk: 1, extent: size,
        inner: { x: bevel, y: bevel, w: w - 2 * bevel, h: h - 2 * bevel },
        canvas: { x: box.x - margin, y: box.y - margin, size: canvas },
        box: box, pop: pop,
        gap: pop.x - (box.x + box.size)
    };
}

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
        out.push({ kind: "tile", x: x, w: TILE_W, index: i, page: r.page });
        x += TILE_W + GAP;
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
    var n = Math.max(1, Math.round((raw - 2 * PAD + GAP) / (TILE_W + GAP)));
    return Math.max(MIN_AREA, n * (TILE_W + GAP) - GAP + 2 * PAD);
}

// What dropping one tile on another means, and the label the drag shows.
// A move names the target page by its apps ("Move beside Signal and Zed"),
// never by number. names maps an app id to its name.
function drop(rows, from, to, names) {
    var a = rows[from], b = rows[to];
    if (!a || !b || from === to || !(a.page > 0) || !(b.page > 0)) return { kind: "none", label: "" };
    if (a.page === b.page)
        return { kind: "swap", label: "Swap with " + appName(b, names) };
    var there = [];
    for (var i = 0; i < rows.length; i++) if (i !== from && rows[i].page === b.page) there.push(appName(rows[i], names));
    return { kind: "move", page: b.page, label: PageNames.moveBeside(there) };
}

function appName(r, names) { return (names && names[r.appId]) || r.appId || "window"; }

// The tile menu's Move to page ▸ rows (page-names.js): every page this
// screen has and the one it shows, each named by its apps, the window's own
// page checked; then a new page, numbered after every page on every screen
// (Hyprland numbers pages globally). The numbers stay in `page`, for the
// move; no label shows one.
function movePages(rows, address, windowPage, shownPage, allPageIds, names) {
    var windows = (rows || []).map(function (r) { return { page: r.page, name: appName(r, names), address: r.address }; });
    return PageNames.movePages(windows, address, windowPage, shownPage, allPageIds);
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
