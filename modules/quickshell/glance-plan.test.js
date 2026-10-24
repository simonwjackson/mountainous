const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const load = file => {
    const out = {};
    vm.runInNewContext(fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, ""), out);
    return out;
};
const g = load(process.argv[2] || __dirname + "/glance-plan.js");
const reg = load(process.argv[3] || __dirname + "/glance-registry.js");
const same = (a, b, m) => assert.equal(JSON.stringify(a), JSON.stringify(b), m);
const GP = g.GP;

// ---------------------------------------------------------------- layout
const fleet = {id: "fleet", w: 690, h: 252};
const disks = {id: "disks", w: 300, h: 180};
const items = [fleet, disks];

// 1920 x 1172: one right-hand column; Fleet in the standalone window's place.
let p = g.plan(1920, 1172, items);
assert.equal(p.cols, 1);
assert.equal(p.gap, 12);
assert.equal(p.scroll, false);
same(p.rects.fleet, {x: 1920 - 8 - 690, y: 6, w: 690, h: 252});
same(p.rects.disks, {x: 1920 - 8 - 300, y: 6 + 252 + 12, w: 300, h: 180});

// Gaps yield at 600 wide and 400 tall, both sides of the boundary.
const tall = 2000;
assert.equal(g.plan(GP.TIGHT_W + GP.LEFT + GP.RIGHT, tall, items).gap, 12);
assert.equal(g.plan(GP.TIGHT_W + GP.LEFT + GP.RIGHT - 1, tall, items).gap, 6);
assert.equal(g.plan(1920, GP.TIGHT_H + GP.TOP + GP.BOTTOM, items).gap, 12);
assert.equal(g.plan(1920, GP.TIGHT_H + GP.TOP + GP.BOTTOM - 1, items).gap, 6);

// Short: the second widget starts the next column to the left.
p = g.plan(1920, 300, items);
assert.equal(p.cols, 2);
assert.equal(p.scroll, false);
assert.equal(p.rects.disks.y, GP.TOP);
assert.equal(p.rects.disks.x, 1920 - 8 - 690 - p.gap - 300);

// Narrow and short: no width for a second column, so it goes under the
// shortest column and the space scrolls, with the scroll bar's width paid.
p = g.plan(360, 400, items);
assert.equal(p.scroll, true);
assert.equal(p.sb, GP.SB);
assert.equal(p.cols, 1);
for (const id of ["fleet", "disks"]) {
    assert.ok(p.rects[id].w <= 360 - GP.LEFT - GP.RIGHT - GP.SB, id + " fits the width");
    assert.ok(p.rects[id].x >= GP.LEFT - 1e-9, id + " stays inside on the left");
}
assert.ok(p.contentH > 400);
assert.equal(p.rects.disks.y, p.rects.fleet.y + p.rects.fleet.h + p.gap);

// Each widget is at most the space's size.
p = g.plan(200, 120, [{id: "fleet", w: 690, h: 900}]);
assert.ok(p.rects.fleet.w <= 200 - 16);
assert.equal(p.scroll, false, "a widget capped to the space never scrolls it");
assert.ok(p.rects.fleet.h <= 120 - 14);

// Zero and one widget.
same(g.plan(1920, 1172, []).rects, {});
assert.equal(g.plan(1920, 1172, []).scroll, false);
assert.equal(g.plan(1920, 1172, [disks]).rects.disks.y, GP.TOP);

// Many widgets: columns fill right to left, then overflow scrolls.
const many = Array.from({length: 9}, (_, i) => ({id: "w" + i, w: 300, h: 260}));
p = g.plan(1280, 800, many);
assert.equal(p.scroll, true);
const xs = [...new Set(Object.values(p.rects).map(r => r.x))].sort((a, b) => b - a);
assert.ok(xs.length >= 3, "several columns");
for (const r of Object.values(p.rects)) assert.ok(r.x >= 0 && r.x + r.w <= 1280 - p.sb);
// No two widgets overlap.
const rects = Object.values(p.rects);
for (let i = 0; i < rects.length; i++) for (let j = i + 1; j < rects.length; j++) {
    const a = rects[i], b = rects[j];
    assert.ok(a.x + a.w <= b.x || b.x + b.w <= a.x || a.y + a.h <= b.y || b.y + b.h <= a.y, "no overlap " + i + "," + j);
}

// Remembered places apply only while nothing scrolls, and stay inside.
const places = {disks: {r: 400, t: 300}};
let placed = g.place(g.plan(1920, 1172, items), places, 1920, 1172);
same(placed.disks, {x: 1920 - 400 - 300, y: 300, w: 300, h: 180, remembered: true});
assert.equal(placed.fleet.remembered, undefined);
placed = g.place(g.plan(360, 400, items), places, 360, 400);
assert.equal(placed.disks.remembered, undefined, "Clean Up order wins while the space scrolls");
placed = g.place(g.plan(1920, 1172, items), {disks: {r: -5000, t: 99999}}, 1920, 1172);
assert.ok(placed.disks.x >= 0 && placed.disks.x + 300 <= 1920);
assert.ok(placed.disks.y <= 1172 - 18, "the title bar stays on screen");
same(g.remember(1000, 200, 300, 1920, 0), {r: 620, t: 200});
same(g.place(g.plan(1920, 1172, items), {disks: {r: NaN, t: 1}}, 1920, 1172).disks, g.plan(1920, 1172, items).rects.disks);

// ---------------------------------------------------------------- motion
const F = g.FRAME;
// Zoom summon: the background at frame 0, outlines in frames 0-8, the
// widgets at frame 9 (150 ms). No frame has alpha: only presence.
let f = g.frameAt("zoom", "in", 0, false);
assert.equal(f.background, true);
assert.equal(f.widgets, false);
same(Array.from(f.outlines), [0]);
f = g.frameAt("zoom", "in", 4 * F, false);
assert.equal(f.outlines.length, 4, "four trailing outlines");
assert.ok(f.outlines.every((v, i, a) => i === 0 || v > a[i - 1]), "the newest outline is furthest along");
assert.equal(g.frameAt("zoom", "in", 8 * F, false).widgets, false);
f = g.frameAt("zoom", "in", 9 * F, false);
assert.equal(f.widgets, true);
assert.equal(f.done, true);
assert.equal(f.outlines, null);
assert.equal(g.frameAt("zoom", "in", 150, false).k, 9, "150 ms is frame 9");
assert.equal(g.frameAt("zoom", "in", 149, false).done, false);
// Ease out: big steps first.
const steps = Array.from({length: 9}, (_, k) => g.frameAt("zoom", "in", k * F, false).outlines.slice(-1)[0]);
for (let k = 2; k < steps.length; k++) assert.ok(steps[k] - steps[k - 1] <= steps[k - 1] - steps[k - 2] + 1e-9, "decelerates");
assert.ok(Math.abs(g.frameAt("zoom", "in", 8 * F, false).outlines.slice(-1)[0] - (1 - (1 / 9) ** 2)) < 1e-9);
// The mirror: widgets gone at frame 0, outlines shrink to the origin, the
// background goes at frame 9.
f = g.frameAt("zoom", "out", 0, false);
assert.equal(f.widgets, false);
assert.equal(f.background, true);
same(Array.from(f.outlines), [1]);
const back = Array.from({length: 9}, (_, k) => g.frameAt("zoom", "out", k * F, false).outlines.slice(-1)[0]);
for (let k = 1; k < back.length; k++) assert.ok(back[k] < back[k - 1], "shrinks toward the origin");
f = g.frameAt("zoom", "out", 9 * F, false);
assert.equal(f.background, false);
assert.equal(f.done, true);
// The mirror of each summon frame is the same outline set reversed in time.
for (let k = 0; k < 9; k++) {
    const a = g.frameAt("zoom", "in", k * F, false).outlines.slice(-1)[0];
    const b = g.frameAt("zoom", "out", (9 - k) * F, false);
    if (b.outlines) assert.ok(Math.abs(a - b.outlines.slice(-1)[0]) < 0.25, "roughly mirrored at " + k);
}
// Reduced motion and the cut: the end state at frame 0.
for (const [style, reduced] of [["cut", false], ["zoom", true]]) {
    same(g.frameAt(style, "in", 0, reduced), {background: true, widgets: true, outlines: null, done: true, k: 0});
    same(g.frameAt(style, "out", 0, reduced), {background: false, widgets: false, outlines: null, done: true, k: 0});
}
same(g.between({x: 0, y: 0, w: 10, h: 10}, {x: 100, y: 50, w: 200, h: 110}, 0.5), {x: 50, y: 25, w: 105, h: 60});
same(g.between({x: 5, y: 6, w: 7, h: 8}, {x: 100, y: 50, w: 200, h: 110}, 0), {x: 5, y: 6, w: 7, h: 8});

// ---------------------------------------------------------------- registry
same(Array.from(reg.ids()), ["fleet", "disks"]);
assert.equal(reg.label("disks"), "Disks");
assert.equal(reg.label("notes"), "", "no Note Pad or Calendar placeholders ship");
assert.equal(reg.known("cal"), false);
let state = reg.parse("");
same(state.enabled, {fleet: true, disks: true});
same(Array.from(reg.enabledIds(state.enabled)), ["fleet", "disks"]);
state = reg.withEnabled(state, "fleet", false);
same(Array.from(reg.enabledIds(state.enabled)), ["disks"]);
same(Array.from(reg.enabledIds(reg.withEnabled(state, "notes", true).enabled)), ["disks"], "unknown ids are ignored");
state = reg.withPlace(state, "disks", 400.4, 299.6);
same(state.places.disks, {r: 400, t: 300});
assert.equal(reg.hasPlaces(state), true);
assert.equal(reg.hasPlaces(reg.cleanedUp(state)), false);
assert.equal(reg.cleanedUp(state).enabled.fleet, false, "Clean Up keeps the checks");
const round = reg.parse(reg.serialize(state));
same(round, state);
for (const bad of ["{", "[]", "null", '{"enabled":{"fleet":"no"},"places":{"disks":{"r":"x"}},"fleet":{"w":-5,"shaded":1}}']) {
    const s = reg.parse(bad);
    same(s.enabled, {fleet: true, disks: true}, bad);
    same(s.places, {}, bad);
    assert.equal(s.fleet.shaded, false);
    assert.equal(s.fleet.w, undefined);
}
same(reg.parse('{"fleet":{"r":12,"t":40,"w":500,"h":300,"shaded":true}}').fleet, {r: 12, t: 40, w: 500, h: 300, shaded: true});
const frozen = reg.parse("");
const before = JSON.stringify(frozen);
reg.withEnabled(frozen, "disks", false);
reg.withPlace(frozen, "fleet", 1, 2);
reg.cleanedUp(frozen);
assert.equal(JSON.stringify(frozen), before, "state changes never mutate their input");
console.log("glance-plan: layout, gaps, overflow, places, zoom motion, reduced motion and the widget registry pass");
