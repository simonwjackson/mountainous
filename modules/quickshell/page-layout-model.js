.pragma library
// The Layout control's model: what one screen's bar shows about the page it
// shows, read from the state file the Hyprland page-layout module writes.
// Plain functions, so page-layout-model.test.js runs them under node.
//
// The file ($XDG_RUNTIME_DIR/mountainous-page-layout.json), version 1:
//   {
//     "version": 1,
//     "fallback": { "cap": 1, "floating": false, "gap": 8 },
//     "defaults": { "<connector>": { "cap", "floating", "gap" } },
//     "pages": { "<id>": { "monitor": "<connector>", "cap", "floating",
//                          "gap", "zen", "own" } }
//   }
// "own" is true when the page differs from its screen's default in cap,
// floating or gap. Zen does not count.

var FALLBACK = { cap: 1, floating: false, gap: 8 };
var CAP_MAX = 3;
var GAP_MAX = 48;
var GAP_STEP = 4;

function settings(v, base) {
    var b = base || FALLBACK;
    var o = v && typeof v === "object" ? v : {};
    var cap = Number.isInteger(o.cap) && o.cap >= 1 && o.cap <= CAP_MAX ? o.cap : b.cap;
    var gap = typeof o.gap === "number" && isFinite(o.gap) ? clampGap(o.gap) : b.gap;
    return { cap: cap, floating: typeof o.floating === "boolean" ? o.floating : b.floating, gap: gap };
}

// A read can land mid-write: null means keep the last good state.
function parse(text) {
    var raw;
    try { raw = JSON.parse(text); } catch (e) { return null; }
    if (!raw || typeof raw !== "object" || raw.version !== 1) return null;
    var fallback = settings(raw.fallback, FALLBACK);
    var defaults = {};
    var d = raw.defaults && typeof raw.defaults === "object" ? raw.defaults : {};
    for (var name in d) defaults[name] = settings(d[name], fallback);
    var pages = {};
    var p = raw.pages && typeof raw.pages === "object" ? raw.pages : {};
    for (var id in p) {
        var page = p[id] || {};
        var monitor = typeof page.monitor === "string" ? page.monitor : "";
        var s = settings(page, defaults[monitor] || fallback);
        s.monitor = monitor;
        s.zen = page.zen === true;
        s.own = page.own === true;
        pages[id] = s;
    }
    return { fallback: fallback, defaults: defaults, pages: pages };
}

function clampGap(v) {
    var n = Math.round(Number(v) / GAP_STEP) * GAP_STEP;
    if (!isFinite(n)) return FALLBACK.gap;
    return Math.max(0, Math.min(GAP_MAX, n));
}

// The bar glyph: the tile shape of the page, or two overlapping windows.
function glyphOf(page) {
    if (!page) return "tile-1";
    return page.floating ? "float" : "tile-" + page.cap;
}

// What a person calls a screen in this control.
function screenTitle(name) {
    if (!name) return "this screen";
    if (name.indexOf("eDP") === 0) return "Built-in Display";
    if (name === "SUNSHINE") return "Tablet"; // modules/second-screen.py OUTPUT
    return name;
}

var WORDS = ["", "One", "Two", "Three"];
var ORDINALS = ["", "first", "second", "third", "fourth"];
function word(n) { return WORDS[n] || String(n); }
function ordinal(n) { return ORDINALS[n] || n + "th"; }

// One screen's view. pageIds: the page ids on this screen, any order.
// pageId: the page the screen shows, or -1 while Hyprland has not said.
function view(state, monitor, pageId, pageIds) {
    var ids = (pageIds || []).filter(function (id) { return id > 0; }).sort(function (a, b) { return a - b; });
    var def = state ? (state.defaults[monitor] || state.fallback) : FALLBACK;
    var stored = state && pageId > 0 ? state.pages[String(pageId)] : null;
    var page = stored || { cap: def.cap, floating: def.floating, gap: def.gap, zen: false, own: false, monitor: monitor };
    var own = 0;
    if (state) {
        for (var id in state.pages) {
            var p = state.pages[id];
            if (p.monitor === monitor && p.own) own += 1;
        }
    }
    var index = ids.indexOf(pageId);
    return {
        available: !!state && pageId > 0,
        pageId: pageId,
        pageIndex: index >= 0 ? index + 1 : 0,
        pageCount: ids.length,
        page: page,
        def: def,
        ownCount: own,
        glyph: glyphOf(page),
        title: screenTitle(monitor)
    };
}

// The line under the capacity buttons on the This page tab.
function capNote(page) {
    if (page.floating) return "Floating windows do not count. Nothing moves to a new page.";
    return "A " + ordinal(page.cap + 1) + " window opens on the next page.";
}
