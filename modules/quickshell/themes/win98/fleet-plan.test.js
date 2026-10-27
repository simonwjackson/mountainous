// The Win98 Fleet window, Properties sheet and glance space policies: the
// width levels at +/-1 u, the height order, Large Icons, the sheet's place,
// the one-row tab strip (tab-strip.js), the mirrored glance layout (shared glance-plan.js
// with Win98 margins) and the caption animation's timing.
//
//   node fleet-plan.test.js fleet-plan.js ../../glance-plan.js tab-strip.js host-icon.js
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const load = file => {
    const out = {};
    vm.runInNewContext(fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, ""), out);
    return out;
};
const P = load(process.argv[2] || __dirname + "/fleet-plan.js");
const G = load(process.argv[3] || __dirname + "/../../glance-plan.js");
const T = load(process.argv[4] || __dirname + "/tab-strip.js");
const I = load(process.argv[5] || __dirname + "/host-icon.js");
const same = (a, b, m) => assert.equal(JSON.stringify(a), JSON.stringify(b), m);

// W95FA Grid at 12.5 u: about 6 u a letter.
const w = s => String(s).length * 6;
const head = {};
for (const id of Object.keys(P.HEAD)) head[id] = P.HEAD[id].map(w);
const m = {
    border: 14, chrome: 54, rows: 8, nameW: w("hiyori"), head, fsLabelW: w("towada") + 3,
    pctW: w("100%"), tempW: w("100°"), failedW: w("14"), notesW: w("14 failed"),
    upLongW: w("seen 49m ago"), upShortW: w("49m")
};

// ---------------------------------------------------------------- width
const natural = P.plan(9999, null, m).natural;
assert.equal(P.plan(natural, null, m).level, 0, "the natural width is level 0");
assert.equal(P.plan(natural - 1, null, m).level, 1, "1 u less gives up spacing");
// Each level's own natural width keeps that level; 1 u less goes on.
let prev = 0;
for (let width = natural; width >= 40; width--) {
    const p = P.plan(width, null, m);
    assert.ok(p.level >= prev, "levels only rise as the width falls (" + width + ")");
    prev = p.level;
    // The name and the status icon never yield; the row ends on the edge.
    assert.ok(p.nameW >= P.C.ICON, "the name column keeps its icon at " + width);
    if (p.fits) {
        const sum = p.nameW + p.cols.reduce((s, id) => s + p.widths[id], 0) + p.sb;
        assert.ok(Math.abs(sum - (width - m.border)) < 1e-9, "the row fills the list at " + width);
    }
}
for (let i = 1; i < P.LEVELS.length - 1; i++) {
    let edge = null;
    for (let width = natural; width >= 40; width--) if (P.plan(width, null, m).level === i) { edge = width; break; }
    assert.ok(edge !== null, "level " + i + " is reached");
    assert.equal(P.plan(edge + 1, null, m).level < i, true, "level " + i + " starts at " + edge + " u");
}
// The order is the shared one: bars shorten, CPU and memory bars go, every
// bar goes, uptime goes, temp and failed merge, the values merge.
same(P.plan(natural, null, m).gave, []);
const last = P.plan(40, null, m);
assert.equal(last.level, P.LEVELS.length - 1);
same(last.cols, []);
assert.equal(last.gave.length, P.LEVELS.length - 1);
assert.equal(P.LEVELS[3].barCols[0], "disk", "the disk bar, the only toned one, goes last");
// Headers take the short label when the long one does not fit.
assert.equal(P.headLabel("mem", P.LEVELS[0], m, w("Memory") + 12), "Memory");
assert.equal(P.headLabel("mem", P.LEVELS[0], m, w("Memory") + 11), "Mem");

// ---------------------------------------------------------------- height
const rows = 8 * P.C.ROW, fixed = m.chrome + P.C.MENU + P.C.COLH;
let h = P.heightPlan(null, m);
assert.equal(h.natural, fixed + rows);
assert.equal(h.rowH, P.C.ROW);
h = P.heightPlan(fixed + rows, m);
assert.equal(h.rowH, P.C.ROW, "the natural height keeps 18-u rows");
assert.equal(h.scrolls, false);
h = P.heightPlan(fixed + rows - 1, m);
assert.equal(h.rowH, P.C.ROW_MIN, "1 u less: 16-u rows");
assert.equal(h.menuInCap, false);
assert.equal(h.scrolls, false);
h = P.heightPlan(fixed + 8 * P.C.ROW_MIN, m);
assert.equal(h.menuInCap, false);
h = P.heightPlan(fixed + 8 * P.C.ROW_MIN - 1, m);
assert.equal(h.menuInCap, true, "then the menu bar folds into the control menu");
assert.equal(h.scrolls, false, "its 19 u still hold the rows");
h = P.heightPlan(fixed + 8 * P.C.ROW_MIN - P.C.MENU - 1, m);
assert.equal(h.scrolls, true, "then the list scrolls");
assert.equal(P.plan(400, fixed + 8 * P.C.ROW_MIN - P.C.MENU - 1, m).sb, P.C.SB, "and pays its scroll bar");
// Large Icons: the grid replaces rows and headers.
const grid = P.iconGrid(400, 8);
assert.equal(grid.cols, 4);
assert.equal(grid.rows, 2);
assert.equal(P.iconGrid(50, 8).cols, 1, "one column at least");
assert.equal(P.iconGrid(400, 0).rows, 0);
h = P.heightPlan(null, m, {icons: true, iconsH: grid.height});
assert.equal(h.natural, m.chrome + P.C.MENU + grid.height);

// ---------------------------------------------------------------- sheet
const area = {x: 6, y: 4, w: 1428, h: 864};
const fr = {x: 1434 - 411, y: 868 - 200, w: 411, h: 200};
let s = P.sheetRect(fr, area);
assert.equal(s.beside, true);
assert.equal(s.x + s.w, fr.x - P.GP.GAP, "beside Fleet, a gap to its left");
assert.equal(s.y + s.h, fr.y + fr.h, "bottom-aligned");
assert.equal(s.w, P.PROPS.W);
assert.equal(s.h, P.PROPS.H, "at least 360 u tall");
// The boundary: 220 u of room to the left opens beside; 219 opens over.
const at = room => P.sheetRect({x: area.x + P.GP.GAP + room, y: 100, w: 300, h: 300}, area);
assert.equal(at(P.PROPS.MINW).beside, true);
assert.equal(at(P.PROPS.MINW).w, P.PROPS.MINW);
assert.equal(at(P.PROPS.MINW - 1).beside, false);
// Always inside the area, at every size the ladder visits.
for (const [W, H] of [[270, 442], [600, 322], [960, 562], [1440, 862], [1280, 762], [120, 80]]) {
    const ar = {x: 6, y: 4, w: W - 12, h: H - 8};
    const f = P.standaloneRect(W, H, 411, 200);
    const r = P.sheetRect(f, ar);
    assert.ok(r.x >= ar.x - 1e-9 && r.x + r.w <= ar.x + ar.w + 1e-9, "sheet inside across at " + W);
    assert.ok(r.y >= ar.y - 1e-9 && r.y + r.h <= ar.y + ar.h + 1e-9, "sheet inside down at " + H);
}
// The standalone place: 6 u from the right, 4 u above the taskbar.
same(P.standaloneRect(1440, 862, 411, 200), {x: 1440 - 6 - 411, y: 862 - 4 - 200, w: 411, h: 200});
same(P.standaloneRect(270, 442, 411, 600), {x: 6, y: 4, w: 258, h: 434}, "capped to the work area");

// ---------------------------------------------------------------- tabs
const tabs = ["General", "Performance", "Services", "Disks"].map(t => w(t) + 14);
const full = 4 + tabs.reduce((a, b) => a + b, 0) - 3;
same(T.tabStrip(tabs, full, 0, 0).mode, "row", "one row while they fit");
let t = T.tabStrip(tabs, full - 1, 0, 0);
assert.equal(t.mode, "scroll", "1 u less: the row scrolls");
assert.equal(t.first, 0);
assert.equal(t.left, false);
assert.equal(t.right, true);
// Every tab is reachable by the up-down arrows, and the current tab shows.
for (let room = 40; room < full; room += 7) {
    for (let cur = 0; cur < 4; cur++) {
        const q = T.tabStrip(tabs, room, cur, 0);
        assert.ok(q.first <= cur && cur <= q.last, "current tab " + cur + " shows at " + room);
    }
    let q = T.tabStrip(tabs, room, 0, 0), steps = 0;
    while (q.right && steps++ < 10) q = T.tabStrip(tabs, room, 0, q.first + 1);
    // Stepping right from the start keeps the current tab shown, so it can
    // stop early; from the last tab the strip reaches the end.
    q = T.tabStrip(tabs, room, 3, 0);
    assert.equal(q.last, 3, "the last tab is reachable at " + room);
    assert.equal(q.right, false);
}
same(T.tabStrip([], 100, 0, 0).last, -1, "no tabs");

// ---------------------------------------------------------------- glance
// The shared plan with Win98's margins, from the bottom right.
const opt = {gp: P.GP, from: "bottom"};
const fleet = {id: "fleet", w: 411, h: 200};
const disks = {id: "disks", w: 230, h: 180};
let g = G.plan(1440, 862, [fleet, disks], opt);
assert.equal(g.cols, 1);
assert.equal(g.gap, 9);
same(g.rects.fleet, P.standaloneRect(1440, 862, 411, 200), "Fleet stands where the standalone window does");
assert.equal(g.rects.disks.y + g.rects.disks.h + g.gap, g.rects.fleet.y, "Disks goes up the column");
assert.equal(g.rects.disks.x + g.rects.disks.w, 1440 - 6, "right-aligned");
// The same rect in both hosts whenever the space does not scroll.
for (const [W, H] of [[960, 562], [1440, 862], [1280, 762]]) {
    const q = G.plan(W, H, [fleet, disks], opt);
    assert.equal(q.scroll, false);
    same(q.rects.fleet, P.standaloneRect(W, H, 411, 200), "one Fleet rect at " + W + "x" + H);
}
// Gaps yield at 450 x 300 u of room, both sides.
assert.equal(G.plan(450 + 12, 2000, [fleet], opt).gap, 9);
assert.equal(G.plan(450 + 11, 2000, [fleet], opt).gap, 4);
// Narrow: one column that scrolls, measured from the bottom of the content.
g = G.plan(270, 442, [{id: "fleet", w: 258, h: 300}, {id: "disks", w: 230, h: 300}], opt);
assert.equal(g.scroll, true);
assert.equal(g.sb, P.GP.SB);
assert.equal(g.rects.fleet.y + g.rects.fleet.h, g.contentH - P.GP.BOTTOM, "Fleet at the bottom of the content");
assert.ok(g.rects.disks.y < g.rects.fleet.y);
for (const r of Object.values(g.rects)) assert.ok(r.x >= 0 && r.x + r.w <= 270 - g.sb && r.y >= 0);
// Platinum's order is untouched without the option.
assert.equal(G.plan(1440, 862, [fleet, disks]).rects.fleet.y, G.GP.TOP);

// ---------------------------------------------------------------- motion
const F = G.FRAME;
let f = G.frameAt("zoom", "in", 0, false);
assert.equal(P.captionProgress(f), 0, "frame 0: the captions start at the button");
assert.equal(f.background, true, "the dither at frame 0");
assert.equal(f.widgets, false);
f = G.frameAt("zoom", "in", 8 * F, false);
assert.ok(Math.abs(P.captionProgress(f) - (1 - (1 / 9) ** 2)) < 1e-9);
f = G.frameAt("zoom", "in", 9 * F, false);
assert.equal(P.captionProgress(f), null, "frame 9: no caption, the windows");
assert.equal(f.widgets, true);
f = G.frameAt("zoom", "out", 0, false);
assert.equal(P.captionProgress(f), 1, "the dismiss starts at the windows");
assert.equal(f.background, true);
f = G.frameAt("zoom", "out", 9 * F, false);
assert.equal(f.background, false, "the dither goes at frame 9");
f = G.frameAt("zoom", "in", 0, true);
assert.equal(P.captionProgress(f), null, "reduced motion: the cut");
assert.equal(f.widgets, true);
const origin = {x: 1200, y: 870, w: 100, h: 22}, target = {x: 1026, y: 671, w: 405, h: 18};
same(P.captionRect(origin, target, 0), origin);
same(P.captionRect(origin, target, 1), target);
const mid = P.captionRect(origin, target, 0.5);
assert.ok(mid.x < origin.x && mid.x > target.x && mid.w > origin.w && mid.w < target.w);

// ---------------------------------------------------------------- icons
// Shape says the status, the overlay the tone; muted is the checker.
const count = (g, f) => g.reduce((n, row, y) => n + row.filter((c, x) => f(c, x, y)).length, 0);
for (const size of [16, 32]) {
    const lit = I.grid("up", size), dark = I.grid("down", size);
    assert.ok(count(lit, c => c === "#008080") > 0, "up: a lit screen at " + size);
    assert.equal(count(dark, c => c === "#008080"), 0, "down: a dark screen at " + size);
    assert.ok(count(I.grid("paused", size), c => c === "#fff") > count(lit, c => c === "#fff"), "paused: two bars");
    const muted = I.shade(I.grid("up", size), true, false, "");
    assert.equal(count(muted, (c, x, y) => c !== "" && (x + y) % 2 === 1), 0, "muted: odd pixels clear at " + size);
    assert.equal(count(muted, c => c !== ""), count(lit, (c, x, y) => c !== "" && (x + y) % 2 === 0), "muted keeps the even half");
    const sel = I.shade(I.grid("up", size), false, true, "#000080");
    assert.equal(count(sel, c => c === "#000080"), count(lit, (c, x, y) => c !== "" && (x + y) % 2 === 0), "selected tints half");
}
assert.ok(I.svg("down", "danger", 16).includes('fill="#ff0000"'), "a down server: the red cross");
assert.ok(I.svg("down", "muted", 16).includes('fill="#000000" stroke="#808080"'), "a down desktop: the black cross");
assert.ok(I.svg("up", "danger", 16).includes("<circle"), "danger: the stop circle");
assert.ok(I.svg("up", "warning", 16).includes('fill="#ffff00"'), "warning: the triangle");
assert.ok(!I.svg("up", "normal", 16).includes("<g transform"), "normal: no overlay");
assert.ok(I.svg("pending", "muted", 32).includes('fill="#ffff80"'), "pending: the hourglass");
same(I.fleetLook({state: "ready", tone: "danger", hosts: [1]}, false), {status: "up", tone: "danger"});
same(I.fleetLook({state: "ready", tone: "danger", hosts: [1]}, true), {status: "up", tone: "muted"}, "stale values are muted");
same(I.fleetLook({state: "loading", tone: "muted", hosts: []}, false), {status: "pending", tone: "muted"});
same(I.fleetLook({state: "unavailable", tone: "muted", hosts: []}, false), {status: "down", tone: "muted"});
same(I.fleetLook({state: "ready", tone: "normal", hosts: []}, false), {status: "up", tone: "muted"}, "no hosts");

console.log("WIN98_FLEET_PLAN_TESTS_PASSED");
