// strip-plan.js at each boundary: one px either side of every threshold.
// Run: node strip-plan.test.js strip-plan.js page-names.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
// strip-plan.js .imports page-names.js as PageNames, as QML does.
const lib = (file) => fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
const PageNames = {};
vm.runInNewContext(lib(process.argv[3] || __dirname + "/../../page-names.js"), PageNames);
const P = { PageNames };
vm.runInNewContext(lib(process.argv[2] || __dirname + "/strip-plan.js").replace(/^\.import "\.\.\/\.\.\/page-names\.js" as PageNames\s*$/m, ""), P);
const plain = (v) => JSON.parse(JSON.stringify(v));
const row = (id, page, x, y, appId) => ({ id, address: "w" + id, page, x, y, appId: appId || "app" + id });
const NUMBER = /\bpage\s*\d/i;

// ---- order: by page, then by screen position; unknown positions keep order
const ordered = P.order([row(1, 2, 900, 40), row(2, 1, 960, 40), row(3, 1, 8, 40), row(4, 2, 8, 40), row(5, 2, 900, 600)]);
assert.deepEqual(plain(ordered.map((r) => r.id)), [3, 2, 4, 1, 5]);
// A swap in a master layout exchanges the two windows' positions; the tiles follow.
const swapped = P.order([row(1, 1, 960, 40), row(2, 1, 8, 40)]);
assert.deepEqual(plain(swapped.map((r) => r.id)), [2, 1]);
assert.deepEqual(plain(P.order([{ id: 1, page: 1 }, { id: 2, page: 1 }, { id: 3, page: 1, x: 5 }]).map((r) => r.id)), [1, 2, 3],
    "rows without a position keep the compositor's order");

// ---- slots: tiles 40, grooves 10, gaps 2, end padding 2
const s = P.slots([row(1, 1), row(2, 1), row(3, 2), row(4, 4)]);
assert.deepEqual(plain(s.slots.map((x) => [x.kind, x.x])), [["tile", 2], ["tile", 44], ["groove", 86], ["tile", 98], ["groove", 140], ["tile", 152]]);
assert.equal(s.content, 194);
assert.equal(P.slots([]).content, 0);
assert.equal(P.slots([row(1, 1)]).content, 44);
assert.equal(P.slots([row(1, 1), row(2, -1)]).slots.filter((x) => x.kind === "groove").length, 0, "no groove beside a window between pages");

// ---- plan at full width: as long as the windows need
let p = P.plan(1920, s.content, null, 0);
assert.deepEqual(plain(p), { area: 194, arrows: false, maxScroll: 0, total: 12 + 194 + 18, empty: false, fullLength: true });

// The boundary where the strip stops fitting: CAP + content + TAB = screen - 6.
const content = 400;
const fitW = 12 + content + 18 + 6;               // 436
p = P.plan(fitW, content, null, 0);
assert.equal(p.arrows, false);
assert.equal(p.total, fitW - 6);
p = P.plan(fitW - 1, content, null, 0);
assert.equal(p.arrows, true, "one px short: arrows");
assert.equal(p.area, fitW - 1 - 6 - 12 - 30 - 18);
assert.equal(p.total, fitW - 1 - 6, "the strip still ends 6 px from the right edge");
assert.equal(p.maxScroll, content - p.area);

// A saved length shorter than the content scrolls; at or past it, it does not.
p = P.plan(1920, content, 200, 0);
assert.deepEqual([p.arrows, p.area, p.maxScroll, p.fullLength], [true, 200, 200, false]);
p = P.plan(1920, content, content, 0);
assert.deepEqual([p.arrows, p.area, p.fullLength], [false, content, true]);
p = P.plan(1920, content, content - 1, 0);
assert.equal(p.arrows, true);
p = P.plan(1920, content, 5, 0);
assert.equal(p.area, 44, "never below one tile");

// 600 and 360 wide: every window stays reachable by scrolling
for (const w of [600, 360, 100, 0]) {
    p = P.plan(w, 1600, null, 0);
    assert.equal(p.arrows, true, String(w));
    assert.ok(p.area >= 44, String(w));
    assert.equal(p.maxScroll, 1600 - p.area, "the whole track is reachable at " + w);
}
assert.equal(P.plan(360, 1600, null, 0).total, 354);

// ---- empty strip: the "No windows" label, never wider than the screen
p = P.plan(1920, 0, null, 80);
assert.deepEqual(plain(p), { area: 80, arrows: false, maxScroll: 0, total: 110, empty: true, fullLength: true });
assert.equal(P.plan(60, 0, null, 80).area, 24);
assert.equal(P.plan(20, 0, null, 80).area, 0);

// ---- scrolling
const many = P.slots(Array.from({ length: 20 }, (_, i) => row(i, 1 + Math.floor(i / 5))));
const mp = P.plan(400, many.content, null, 0);
assert.equal(P.scrollStep(many.slots, 0, 1, mp.maxScroll), 42, "next slot edge");
assert.equal(P.scrollStep(many.slots, 42, -1, mp.maxScroll), 0);
assert.equal(P.scrollStep(many.slots, mp.maxScroll, 1, mp.maxScroll), mp.maxScroll);
assert.equal(P.scrollStep(many.slots, 0, -1, mp.maxScroll), 0);
const last = many.slots[many.slots.length - 1];
assert.equal(P.scrollToShow(last, 0, mp.area, mp.maxScroll), mp.maxScroll);
assert.equal(P.scrollToShow(many.slots[0], mp.maxScroll, mp.area, mp.maxScroll), 0);
assert.equal(P.scrollToShow(many.slots[1], 0, mp.area, mp.maxScroll), 0, "already visible: no change");
assert.equal(P.clampScroll(-5, 10), 0);
assert.equal(P.clampScroll(50, 10), 10);

// ---- dragging the tab: whole tiles, full length past the content
assert.equal(P.dragLength(194, 0, 194), null);
assert.equal(P.dragLength(194, -60, 194), 2 + 3 * 42 - 2 + 2);
assert.equal(P.dragLength(194, -1000, 194), 44);
assert.equal(P.dragLength(100, 1000, 194), null);
assert.equal(P.dragLength(44, 20, 400), 44, "half a tile less one px: one tile");
assert.equal(P.dragLength(44, 21, 400), 86, "half a tile: two");

// ---- drop meaning and label: a page is named by its apps, never its number
const lane = [row(1, 1, 0, 0, "firefox"), row(2, 1, 900, 0, "ghostty"), row(3, 3, 0, 0, "gh")];
const names = { ghostty: "Ghostty", gh: "GitHub", firefox: "Firefox", signal: "Signal", zed: "Zed" };
assert.deepEqual(plain(P.drop(lane, 0, 1, { ghostty: "Ghostty" })), { kind: "swap", label: "Swap with Ghostty" });
assert.deepEqual(plain(P.drop(lane, 0, 2, names)), { kind: "move", page: 3, label: "Move beside GitHub" });
assert.deepEqual(plain(P.drop(lane, 2, 0, names)), { kind: "move", page: 1, label: "Move beside Firefox and Ghostty" });
assert.deepEqual(plain(P.drop(lane, 0, 2, {})), { kind: "move", page: 3, label: "Move beside gh" }, "an unnamed app falls back to its id");
assert.equal(P.drop(lane, 1, 1, {}).kind, "none");
assert.equal(P.drop(lane, 0, 9, {}).kind, "none");
assert.equal(P.drop([row(1, -1), row(2, 1)], 0, 1, {}).kind, "none");
const busy = lane.concat([row(4, 3, 900, 0, "signal"), row(5, 3, 0, 900, "zed"), row(6, 3, 900, 900, "ghostty")]);
assert.equal(P.drop(busy, 0, 2, names).label, "Move beside GitHub, Signal, Zed…");

// ---- move to page: every page of this screen by its apps, own page checked
let mv = P.movePages(lane, "w1", 1, 1, [1, 2, 3, 6], names);
assert.deepEqual(plain(mv.pages), [
    { page: 1, current: true, label: "Beside Ghostty" },
    { page: 3, current: false, label: "Beside GitHub" }]);
assert.equal(mv.newPage, 7, "after every page on every screen");
mv = P.movePages(lane, "w3", 3, 4, [], names);
assert.deepEqual(plain(mv.pages.map((x) => [x.label, x.current])),
    [["Beside Firefox and Ghostty", false], ["On its own", true], ["Empty page", false]]);
assert.equal(mv.newPage, 5);
for (const p of P.movePages(busy, "w1", 1, 7, [1, 3, 7, 12], names).pages) assert.doesNotMatch(p.label, NUMBER, p.label);
for (let from = 0; from < busy.length; from++)
    for (let to = 0; to < busy.length; to++) assert.doesNotMatch(P.drop(busy, from, to, names).label, NUMBER);

// ---- saved state per screen
let st = P.parseState('{"eDP-1": {"collapsed": true, "length": 130}, "DP-2": {"length": 3}, "x": 4}');
assert.deepEqual(plain(st), { "eDP-1": { collapsed: true, length: 130 }, "DP-2": { collapsed: false, length: null } });
assert.deepEqual(plain(P.screenState(st, "eDP-1")), { collapsed: true, length: 130 });
assert.deepEqual(plain(P.screenState(st, "HDMI-A-1")), { collapsed: false, length: null });
st = P.withScreen(st, "DP-2", { collapsed: true, length: null });
assert.deepEqual(plain(P.screenState(st, "DP-2")), { collapsed: true, length: null });
assert.equal(P.screenState(st, "eDP-1").length, 130, "other screens are kept");
for (const bad of ["", "[]", "null", "{"]) assert.deepEqual(plain(P.parseState(bad)), {}, bad);

assert.equal(P.BAND, 44);
assert.equal(P.HEIGHT - P.TILE_H, 6, "3 px above and below a tile");

// ---- one tile's parts, in device px (PlatinumStripTile draws these)
// Every edge on a whole device pixel; the icon's box the same distance
// from the inside of the bevel on the top, left and bottom; at least
// MIN_POP_GAP px between the box and the ▴, pressed in too; the ▴ inside
// the bevel; the box is a token's inner box (platinum_icons.py margin).
const margin = (S) => Math.max(2, Math.floor(S / 16));
for (const dpr of [1, 1.25, 1.5, 2, 3]) {
    const g = P.tileGeometry(dpr), at = "at " + dpr;
    for (const v of [g.w, g.h, g.bevel, g.pad, g.box.x, g.box.y, g.box.size, g.pop.x, g.pop.y, g.pop.w, g.pop.h, g.canvas.x, g.canvas.y])
        assert.ok(Number.isInteger(v), "whole device px " + at);
    assert.equal(g.w, P.TILE_W * dpr, at);
    assert.equal(g.h, P.TILE_H * dpr, at);
    assert.equal(g.canvas.size, Math.ceil(P.ICON * dpr), "the token canvas WindowIcon asks for " + at);
    assert.equal(g.box.size, g.canvas.size - 2 * margin(g.canvas.size), "a token's inner box " + at);
    assert.equal(g.box.x - g.inner.x, g.pad, "left padding " + at);
    assert.equal(g.box.y - g.inner.y, g.pad, "top padding " + at);
    const bottom = g.inner.y + g.inner.h - (g.box.y + g.box.size);
    assert.ok(bottom === g.pad || bottom === g.pad + 1, "bottom padding " + at + ": " + bottom);
    assert.ok(g.pad >= 4 * dpr - 1, "breathing room " + at + ": " + g.pad);
    assert.ok(g.gap - g.sunk >= P.MIN_POP_GAP, "▴ gap, pressed in, " + at + ": " + (g.gap - g.sunk));
    assert.ok(g.pop.x + g.pop.w <= g.inner.x + g.inner.w - g.bevel && g.pop.y + g.pop.h <= g.inner.y + g.inner.h - g.bevel,
        "the ▴ one hair inside the bevel " + at);
    assert.ok(g.box.y + g.box.size + g.sunk <= g.inner.y + g.inner.h, "pressed in, the box stays inside " + at);
}
// The numbers at Myoko's scale 1.5, as reported.
const g15 = P.tileGeometry(1.5);
assert.deepEqual(plain([g15.w, g15.h, g15.bevel, g15.pad, g15.box, g15.gap, g15.pop]),
    [60, 48, 2, 6, { x: 8, y: 8, size: 32 }, 5, { w: 11, h: 8, x: 45, y: 36 }]);
assert.deepEqual(plain(g15.canvas), { x: 6, y: 6, size: 36 }, "the token canvas at (4, 4) logical");
console.log("strip-plan: order, slots, fit and scroll boundaries, tab drag, drop, pages and state pass");
