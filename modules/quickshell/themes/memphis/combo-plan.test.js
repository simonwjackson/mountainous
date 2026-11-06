// combo-plan.js: the Memphis drop-down list's field and list placement, one
// unit either side of each threshold. Run: node combo-plan.test.js combo-plan.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const P = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/combo-plan.js", "utf8")
    .replace(/^\.pragma library\s*$/m, ""), P);

const ROW = P.ROW, EDGE = P.EDGE, MAX = P.MAX_ROWS;
const single = n => Array(n).fill(ROW);

// ---- the closed field
// Inline down to a VALUE_MIN-wide value box; stacked one unit narrower.
const inlineMin = P.VALUE_MIN + P.INSET + P.GAP + P.BUTTON + 2;
let f = P.field(inlineMin, 1);
assert.equal(f.stacked, false);
assert.equal(f.valueWidth, P.VALUE_MIN);
assert.equal(f.height, 21, "one line: Memphis's 21-u field");
assert.equal(f.buttonX, inlineMin - 2 - P.BUTTON);
assert.equal(f.buttonY, 2);
f = P.field(inlineMin - 1, 1);
assert.equal(f.stacked, true);
assert.equal(f.valueWidth, inlineMin - 1 - 2 * P.INSET, "stacked: the value takes the whole width");
assert.ok(f.buttonY >= P.INSET + f.valueHeight, "the button sits under the value");
assert.equal(f.height, f.buttonY + 17 + 2);
f = P.field(inlineMin + 1, 1);
assert.equal(f.stacked, false);
// A wrapped value grows the field a line at a time, inline or stacked.
assert.equal(P.field(200, 2).height, 21 + P.LINE);
assert.equal(P.field(200, 3).height, 21 + 2 * P.LINE);
assert.equal(P.field(20, 3).height - P.field(20, 1).height, 2 * P.LINE);
// The smallest widths never go negative.
for (const w of [0, 1, 6, 7, 30]) {
    const g = P.field(w, 1);
    assert.ok(g.valueWidth >= 0, "value width at " + w);
    assert.ok(g.height > 0);
}

// ---- the list's width
assert.equal(P.listWidth(200, 60, 1000, false), 200, "never narrower than the field");
assert.equal(P.listWidth(40, 90, 1000, true), 90 + P.PAD + 2 * EDGE + P.SCROLLBAR, "as wide as the longest label needs");
assert.equal(P.listWidth(40, 90, 60, true), 60, "never wider than the window");
assert.equal(P.rowTextWidth(60, true), 60 - 2 * EDGE - P.PAD - P.SCROLLBAR);
assert.ok(P.rowTextWidth(5, true) >= 1);

// ---- placement. 22 single-line rows want MAX rows' worth.
const rows = single(22);
const want = MAX * ROW;
const down = (area, fieldTop, fieldBottom) => P.place({ rows, area, fieldTop, fieldBottom });
// Down: exactly enough room below, and one unit more.
for (const extra of [0, 1]) {
    const p = down(400, 100, 121 - 0);
    const q = P.place({ rows, fieldTop: 100, fieldBottom: 121, area: 121 + want + 2 * EDGE + extra });
    assert.equal(q.mode, "down");
    assert.equal(q.view, want);
    assert.equal(q.y, 121);
    assert.equal(q.scrolls, true);
    assert.equal(p.mode, "down");
}
// One unit short below, more room above: up, at full height.
let p = P.place({ rows, fieldTop: 300, fieldBottom: 321, area: 321 + want + 2 * EDGE - 1 });
assert.equal(p.mode, "up");
assert.equal(p.view, want);
assert.equal(p.y, 300 - p.height);
// One unit short below, less room above than below: down, shortened.
p = P.place({ rows, fieldTop: 50, fieldBottom: 71, area: 71 + 120 });
assert.equal(p.mode, "down");
assert.equal(p.view, 120 - 2 * EDGE);
assert.ok(p.y + p.height <= 71 + 120, "inside the usable height");
// Equal room either side: down (Memphis dropped down).
p = P.place({ rows, fieldTop: 60 + 2 * EDGE, fieldBottom: 81, area: 81 + 60 + 2 * EDGE });
assert.equal(p.mode, "down");
// Cramped: neither side fits the shortest row, one unit either side of it.
const cramp = room => P.place({ rows, fieldTop: room + 2 * EDGE, fieldBottom: room + 2 * EDGE + 21, area: 2 * room + 4 * EDGE + 21 });
assert.equal(cramp(ROW - 1).mode, "over");
assert.notEqual(cramp(ROW).mode, "over", "one row fits: not over");
p = cramp(ROW - 1);
assert.ok(p.y >= 0 && p.y + p.height <= 2 * (ROW - 1) + 4 * EDGE + 21, "over: inside the usable height");
assert.ok(p.view >= ROW, "over: at least one row shows");
// A window shorter than a row: over, never negative.
p = P.place({ rows, fieldTop: 0, fieldBottom: 21, area: 10 });
assert.equal(p.mode, "over");
assert.ok(p.view >= 0 && p.y >= 0);
// Few rows: no scrolling, the list as tall as its rows.
p = P.place({ rows: single(3), fieldTop: 0, fieldBottom: 21, area: 800 });
assert.equal(p.view, 3 * ROW);
assert.equal(p.scrolls, false);
// Wrapped rows: the wanted height still caps at MAX single rows' worth,
// and a tall row counts as the shortest when every row is tall.
const tall = Array(22).fill(3 * 13 + 4);
p = P.place({ rows: tall, fieldTop: 0, fieldBottom: 21, area: 2000 });
assert.equal(p.view, want);
assert.equal(p.scrolls, true);
p = P.place({ rows: tall, fieldTop: 3 * 13 + 4 + 2 * EDGE - 1, fieldBottom: 3 * 13 + 4 + 2 * EDGE - 1 + 21, area: 2 * (3 * 13 + 4 + 2 * EDGE - 1) + 21 });
assert.equal(p.mode, "over", "a tall row one unit short on both sides: over");
// No rows at all.
p = P.place({ rows: [], fieldTop: 0, fieldBottom: 21, area: 400 });
assert.equal(p.view, 0);
assert.equal(p.scrolls, false);

// ---- scrolling
const mixed = [17, 30, 17, 43, 17, 17];
assert.equal(P.rowTop(mixed, 3), 64);
assert.equal(P.reveal(mixed, 0, 30, 50), 0, "up to a row above the view");
assert.equal(P.reveal(mixed, 3, 0, 50), 64 + 43 - 50, "down so the row's bottom shows");
assert.equal(P.reveal(mixed, 1, 10, 50), 10, "a visible row keeps the offset");
assert.equal(P.reveal(mixed, 3, 0, 40), 64, "a row taller than the view shows its top");
assert.equal(P.reveal(mixed, 5, 0, 500), 0, "never past the end");
assert.equal(P.reveal(mixed, -1, 7, 50), 7);
// Page keys move a view at a time, at least one row, inside the list.
assert.equal(P.page(single(22), 0, MAX * ROW, 1), MAX - 1);
assert.equal(P.page(single(22), 21, MAX * ROW, -1), 21 - (MAX - 1));
assert.equal(P.page(single(22), 20, MAX * ROW, 1), 21);
assert.equal(P.page(single(22), 0, MAX * ROW, -1), 0);
assert.equal(P.page([43, 43, 43], 0, 20, 1), 1, "a view shorter than a row still moves one row");
assert.equal(P.page([], 0, 100, 1), -1);

console.log("MEMPHIS_COMBO_PLAN_PASSED");
