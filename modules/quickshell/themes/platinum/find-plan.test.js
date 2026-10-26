// find-plan.js: the Find menu and the Go to Address dialog at every size.
// Run: node find-plan.test.js find-plan.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const P = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/find-plan.js", "utf8")
    .replace(/^\.pragma library\s*$/m, ""), P);

// ---- the Find menu
let m = P.menuPlan(1920, 1200);
assert.equal(m.x, 6);
assert.equal(m.width, 400);
assert.equal(m.maxHeight, 1200 - 28 - 6);
assert.equal(m.hintShare, 0.45);
assert.equal(m.popup, true);
// 360 wide: the menu is the screen less its edges, and keeps the pop-up.
m = P.menuPlan(360, 780);
assert.equal(m.width, 348);
assert.equal(m.popup, true);
assert.equal(m.hintShare, 0.45);
// One pixel either side of each threshold.
assert.equal(P.menuPlan(412, 800).width, 400);
assert.equal(P.menuPlan(411, 800).width, 399);
assert.equal(P.menuPlan(272, 800).popup, true);    // 260 wide
assert.equal(P.menuPlan(271, 800).popup, false);   // 259 wide
assert.equal(P.menuPlan(312, 800).hintShare, 0.45); // 300
assert.equal(P.menuPlan(311, 800).hintShare, 0.38); // 299
assert.equal(P.menuPlan(262, 800).hintShare, 0.38); // 250
assert.equal(P.menuPlan(261, 800).hintShare, 0);    // 249
assert.equal(P.menuPlan(232, 800).width, 220);
assert.equal(P.menuPlan(231, 800).width, 219, "under 220 the menu still stays on screen");
// Every width from 1 to 2000: never past the right edge, never negative.
for (let W = 1; W <= 2000; W++) {
    const p = P.menuPlan(W, 600);
    assert.ok(p.width >= 0 && p.x + p.width <= Math.max(W - 6, 6), "menu inside at " + W);
}
// Every height: the menu never leaves the screen.
for (let H = 0; H <= 1400; H += 7) assert.ok(P.menuPlan(1920, H).maxHeight <= Math.max(0, H - 28 - 6));

// ---- Go to Address
let a = P.addrPlan(1920, 1200, 42);
assert.deepEqual(JSON.parse(JSON.stringify(a)), { x: 42, y: 32, width: 480, listRows: 5, hostColumn: true, maxHeight: 1200 - 38, stackButtons: false });
// The left edge follows the title, so it says which window Go acts on.
assert.equal(P.addrPlan(1920, 1200, 300).x, 300);
// Too little room under the title: the dialog takes the screen's width.
// At 360 the room under the title is 312 (< 320): the dialog moves to the left edge.
assert.equal(P.addrPlan(360, 780, 42).x, 6);
assert.equal(P.addrPlan(360, 780, 42).width, 348);
assert.equal(P.addrPlan(360, 780, 42).hostColumn, false);
assert.equal(P.addrPlan(368, 780, 42).width, 320);  // 368 - 42 - 6 = 320: stays under the title
assert.equal(P.addrPlan(368, 780, 42).x, 42);
assert.equal(P.addrPlan(367, 780, 42).x, 6);       // 319: moves
// The page list gives rows back before the field or the buttons go.
assert.equal(P.addrPlan(1920, 520, 42).listRows, 5);
assert.equal(P.addrPlan(1920, 519, 42).listRows, 3);
assert.equal(P.addrPlan(1920, 400, 42).listRows, 3);
assert.equal(P.addrPlan(1920, 399, 42).listRows, 0);
assert.equal(P.addrPlan(1920, 1200, 42).hostColumn, true);
assert.equal(P.addrPlan(426, 1200, 0).hostColumn, false);   // 414 wide
assert.equal(P.addrPlan(432, 1200, 6).hostColumn, true);    // 420 wide
// Every width: inside the screen.
for (let W = 1; W <= 2000; W++) {
    const p = P.addrPlan(W, 800, 42);
    assert.ok(p.width >= 0 && (p.width === 0 || p.x + p.width <= W - 6 + 0.01), "dialog inside at " + W);
}
console.log("find-plan: menu and dialog sizes, thresholds and edges passed");
