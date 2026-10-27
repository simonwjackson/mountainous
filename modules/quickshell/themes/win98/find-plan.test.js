// find-plan.js: the Win98 Find window and Open dialog at every size, one
// unit either side of each threshold. Run: node find-plan.test.js find-plan.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const P = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/find-plan.js", "utf8")
    .replace(/^\.pragma library\s*$/m, ""), P);

// Myoko at 1.5 is 1920x1200 logical, 1440x900 u; the taskbar takes 28 u.
const room = (wPx, hPx, scale) => {
    const u = 2 / (scale || 1.5);
    return [Math.floor(wPx / u), Math.floor(hPx / u) - 28];
};

// ---- the Find window
let f = P.findPlan(...room(1920, 1200));
assert.equal(f.width, 400);
assert.equal(f.list, 18 * 16);
assert.equal(f.buttonColumn, true);
assert.equal(f.detail, 0.36);
assert.equal(f.status, true);
assert.equal(f.inline, false);
assert.equal(f.scroll, false);
assert.deepEqual([...f.steps], []);
assert.equal(f.x, 2);
assert.equal(f.y + f.height, 872 - 2, "above the taskbar, 2 u clear");
// 37 + 50 (two button-tall rows) + 6 + 21 + 288 + 26.
assert.equal(f.criteria, 50);
assert.equal(f.natural, 428);

// 360x640 logical at 1.5 (270x452 u): narrow and a little short.
f = P.findPlan(...room(360, 640));
assert.equal(f.width, 266);
assert.equal(f.buttonColumn, false, "Open and Close go under the list");
assert.equal(f.detail, 0.3);
assert.equal(f.status, true);
assert.ok(f.list >= 6 * 16 && f.list % 16 === 0);
assert.equal(f.scroll, false);
// 360x640 at scale 1: 180 u wide, the Details column goes.
f = P.findPlan(...room(360, 640, 1));
assert.equal(f.detail, 0);
assert.equal(f.scroll, false);

// Width thresholds, one unit either side (width = W - 4).
assert.equal(P.findPlan(404, 800).width, 400);
assert.equal(P.findPlan(403, 800).width, 399);
assert.equal(P.findPlan(304, 800).buttonColumn, true);
assert.equal(P.findPlan(303, 800).buttonColumn, false);
assert.equal(P.findPlan(304, 800).detail, 0.36);
assert.equal(P.findPlan(303, 800).detail, 0.3);
assert.equal(P.findPlan(204, 800).detail, 0.3);
assert.equal(P.findPlan(203, 800).detail, 0);

// Height: the yield order. Rows first, then the status bar, then one
// criteria row (wide enough), then rows down to three, then the body scrolls.
const wide = 600;
const at = (H) => P.findPlan(wide, H);
assert.deepEqual([...at(432).steps], []);
assert.deepEqual([...at(431).steps], ["list rows"]);
let prev = at(432);
for (let H = 431; H >= 40; H--) {
    const p = at(H);
    assert.ok(p.height <= H - 4, "inside the room at " + H);
    assert.ok(p.list % 16 === 0 && p.list >= 48, "whole rows, at least three, at " + H);
    // Nothing comes back as the room shrinks: each step only grows.
    assert.ok(p.steps.length >= prev.steps.length || p.steps.join() === prev.steps.join(), "steps grow at " + H);
    if (prev.status === false) assert.equal(p.status, false);
    if (prev.inline) assert.equal(p.inline, true);
    assert.equal(p.scroll, p.natural > H - 4);
    prev = p;
}
// The status bar goes only once the list is down to six rows.
for (let H = 431; H >= 40; H--) {
    const p = at(H);
    if (!p.status) { assert.ok(p.list <= 6 * 16 || p.inline || p.steps.length > 2, "status after rows at " + H); }
}
// Where each step starts, both sides.
const first = (pred) => { for (let H = 432; H >= 40; H--) if (pred(at(H))) return H; return -1; };
const statusGoes = first((p) => !p.status);
assert.equal(at(statusGoes + 1).status, true);
assert.equal(at(statusGoes + 1).list, 6 * 16);
const inlineAt = first((p) => p.inline);
assert.ok(inlineAt < statusGoes);
assert.equal(at(inlineAt + 1).inline, false);
const scrollAt = first((p) => p.scroll);
assert.equal(at(scrollAt + 1).scroll, false);
assert.equal(at(scrollAt).list, 48);
// The one row needs a wider window: 520 u, so a screen under 524 u skips it.
assert.equal(at(inlineAt).width, 520);
assert.equal(at(inlineAt).criteria, 23);
assert.equal(at(inlineAt + 1).width, 400);
assert.equal(P.findPlan(524, inlineAt).inline, true);
assert.equal(P.findPlan(523, inlineAt).inline, false);
// Narrow and short: no inline step (the row would not fit), straight to three rows.
const narrowShort = P.findPlan(300, 200);
assert.equal(narrowShort.inline, false);
assert.equal(narrowShort.criteria, 2 * 21 + 4, "rows as tall as the fields when the buttons are under the list");
assert.equal(narrowShort.list, 48);

// ---- the Open dialog
let o = P.openPlan(...room(1920, 1200), { x: 540, y: 0, w: 900, h: 860 });
assert.equal(o.width, 340);
assert.equal(o.labelAbove, false);
assert.equal(o.intro, true);
assert.equal(o.scroll, false);
assert.equal(o.natural, 41 + 42 + 27 + 36 + 23);
assert.equal(o.x, Math.round(540 + 450 - 170), "centred on the caller");
assert.equal(o.y, Math.round(430 - o.height / 2));
// No caller: centred in the room.
o = P.openPlan(1440, 872, null);
assert.equal(o.x, 550);
// A caller near an edge: kept 2 u inside.
o = P.openPlan(1440, 872, { x: 1400, y: 840, w: 40, h: 30 });
assert.equal(o.x, 1440 - 2 - 340);
assert.equal(o.y, 872 - 2 - o.height);
o = P.openPlan(1440, 872, { x: -50, y: -50, w: 20, h: 20 });
assert.equal(o.x, 2);
assert.equal(o.y, 2);
// Width: 340, then the screen; the label goes above under 230.
assert.equal(P.openPlan(344, 800, null).width, 340);
assert.equal(P.openPlan(343, 800, null).width, 339);
assert.equal(P.openPlan(234, 800, null).labelAbove, false);
assert.equal(P.openPlan(233, 800, null).labelAbove, true);
// Height: the intro goes first, then the body scrolls.
const need = 41 + 42 + 27 + 36 + 23;
assert.equal(P.openPlan(600, need + 4, null).intro, true);
assert.equal(P.openPlan(600, need + 3, null).intro, false);
assert.equal(P.openPlan(600, need + 3, null).scroll, false);
assert.equal(P.openPlan(600, need - 42 + 4, null).scroll, false);
assert.equal(P.openPlan(600, need - 42 + 3, null).scroll, true);
// 360x640 at 1.5: whole, with its intro.
o = P.openPlan(...room(360, 640), null);
assert.equal(o.width, 266);
assert.equal(o.intro, true);
assert.equal(o.scroll, false);

// ---- drop-down lists
let d = P.dropPlan(1440, 872, { x: 100, y: 100, w: 200, h: 21 }, 5, 170);
assert.equal(d.up, false);
assert.equal(d.y, 121);
assert.equal(d.height, 5 * 16 + 4);
assert.equal(d.width, 200);
// No room below: it opens up, as Win98 combo boxes did.
d = P.dropPlan(1440, 872, { x: 100, y: 830, w: 200, h: 21 }, 5, 170);
assert.equal(d.up, true);
assert.equal(d.y + d.height, 830);
// Too little room either way: it scrolls, and it never leaves the screen.
d = P.dropPlan(300, 100, { x: 280, y: 40, w: 100, h: 21 }, 20, 170);
assert.equal(d.scrolls, true);
assert.ok(d.x >= 2 && d.x + d.width <= 298);
assert.ok(d.y >= 2 - 1e-9 && d.y + d.height <= 98 + 1e-9);

// ---- rows
const rows = [{ t: "head" }, { t: "item" }, { t: "item" }, { t: "sep" }, { t: "item", dis: true }, { t: "item" }];
assert.equal(P.contentHeight(rows), 16 + 16 + 16 + 8 + 16 + 16);
assert.equal(P.rowAt(rows, 0), 0);
assert.equal(P.rowAt(rows, 47), 2);
assert.equal(P.rowAt(rows, 48), 3);
assert.equal(P.rowAt(rows, 56), 4);
assert.equal(P.rowAt(rows, 200), -1);
assert.equal(P.scrollFor(rows, 5, 0, 48, 1), 88 - 48);
assert.equal(P.scrollFor(rows, 1, 40, 48, 1), 0, "the first selectable row starts the list");
assert.equal(P.scrollFor(rows, 2, 40, 48, 1), 32);
const st = P.status(rows, 1);
assert.equal(st.count, "3 items");
assert.equal(P.status([{ t: "item", k: "win", hint: "page 1" }], 0).count, "1 item");
assert.equal(P.status([{ t: "item", k: "win", hint: "page 1" }], 0).detail, "Window: page 1");
assert.equal(P.status([{ t: "item", k: "none", dis: true }], 0).detail, "");

console.log("WIN98_FIND_PLAN_PASSED");
