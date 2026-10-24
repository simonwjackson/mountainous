const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const plan = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/fleet-plan.js", "utf8").replace(/^\.pragma library\s*$/m, ""), plan);

// A stand-in for ChicagoFLF: a fixed advance per character and size.
const w12 = s => Math.ceil(s.length * 7.2);
const w14 = s => Math.ceil(s.length * 8.6);
const w11 = s => Math.ceil(s.length * 6.6);
const m = {
    border: 2 * (2 / 1.5), rows: 8,
    nameW: Math.min(Math.max(...["fuji", "hiyori", "ibuki", "myoko", "rakku", "tate", "unzen", "yari"].map(w14)), 120),
    head: Object.fromEntries(Object.entries(plan.HEAD).map(([id, labels]) => [id, labels.map(w12)])),
    fsLabelW: Math.min(w11("towada"), 70) + 4,
    pctW: w12("100%"), tempW: w12("100°"), failedW: w12("14"), notesW: w12("14 failed"),
    upLongW: Math.max(w12("10d 17h"), w12("seen 49m ago")), upShortW: w12("49m")
};

const natural = plan.plan(9999, null, m).natural;
assert.ok(natural > 500 && natural < 760, "natural width in the mock's range: " + natural);
assert.equal(plan.plan(natural, null, m).level, 0);

// Walk the width down 1 px at a time: levels only grow, every boundary is
// exact (level n at its natural width, n+1 one pixel below), the name and
// light never go, and the row always ends on the right edge.
let previous = 0;
const boundaries = [];
for (let w = natural + 50; w >= 60; w--) {
    const p = plan.plan(w, null, m);
    assert.ok(p.level >= previous, "levels are monotonic at " + w);
    if (p.level !== previous) boundaries.push([w, p.level]);
    previous = p.level;
    const used = plan.C.TRI + plan.C.LAMP + p.nameW + p.cols.reduce((s, id) => s + p.widths[id], 0) + p.sb;
    if (p.fits) assert.ok(Math.abs(used - (w - m.border)) < 1e-6, "the row ends on the right edge at " + w);
    assert.ok(p.nameW >= m.nameW, "the name keeps its width at " + w);
    for (let j = 0; j < p.cols.length; j++) assert.ok(p.widths[p.cols[j]] > 0);
}
assert.deepEqual(boundaries.map(b => b[1]), [1, 2, 3, 4, 5, 6, 7, 8], "every level is reached in order");
for (const [w, level] of boundaries) {
    assert.equal(plan.plan(w + 1, null, m).level, level - 1, "one px wider stays at level " + (level - 1));
    assert.equal(plan.plan(w, null, m).level, level);
}
assert.equal(plan.plan(60, null, m).level, 8);
assert.deepEqual(Array.from(plan.plan(60, null, m).cols), []);
assert.equal(plan.plan(60, null, m).gave.length, 8);

// Level contents follow the mock: bars go whole, CPU and memory first.
const byLevel = level => plan.plan(boundaries.find(b => b[1] === level)[0], null, m);
assert.equal(byLevel(2).up, "short");
assert.deepEqual(Array.from(byLevel(3).barCols), ["disk"]);
assert.equal(byLevel(4).bar, 0);
assert.equal(byLevel(5).cols.includes("up"), false);
assert.deepEqual(Array.from(byLevel(6).cols), ["cpu", "mem", "disk", "notes"]);
assert.deepEqual(Array.from(byLevel(7).cols), ["why"]);
assert.ok(byLevel(7).widths.why >= 2 * byLevel(7).pad + 64, "the reason takes the spare width");

// Header labels shorten only when the full one does not fit.
assert.equal(plan.headLabel("mem", plan.LEVELS[0], m, plan.plan(natural, null, m).widths.mem), "Memory");
assert.equal(plan.headLabel("failed", plan.LEVELS[4], m, w12("Fail") + 8), "Fail");

// Height: rows shrink from 24 to 19, then the summary moves into the title,
// then the list scrolls and the scroll bar takes width.
const fixed = plan.C.TITLE + plan.C.INFO + plan.C.COLH + plan.C.FOOT + m.border + 3;
const at = h => plan.plan(natural, h, m);
assert.equal(at(fixed + 8 * 24).rowH, 24);
assert.equal(at(fixed + 8 * 24 - 1).rowH, 19);
assert.equal(at(fixed + 8 * 19).infoInTitle, false);
assert.equal(at(fixed + 8 * 19 - 1).infoInTitle, true);
assert.equal(at(fixed + 8 * 19 - 1).scrolls, false, "the summary's room pays for the rows first");
assert.equal(at(fixed + 8 * 19 - plan.C.INFO - 1).scrolls, true);
assert.equal(at(fixed + 8 * 19 - plan.C.INFO - 1).sb, plan.C.SB);
assert.equal(at(null).scrolls, false);
assert.equal(at(null).listH, null);
assert.equal(plan.plan(natural, fixed + 8 * 24, m, {detailH: 1}).scrolls, true, "an open host's drill-down scrolls the list");
assert.ok(plan.plan(natural, 150, m).level >= at(null).level, "a scroll bar can push the columns down a level");
assert.ok(plan.plan(natural, 150, m).listH >= 0);
assert.ok(plan.plan(natural, 0, m).listH === 0);

// Loading keeps the window's eight-row size; zero hosts plan one row.
assert.equal(plan.plan(natural, null, {...m, rows: 0}).rowH, 24);

// Summary fitting: shortens before it is cut.
const variants = ["8 hosts · 1 problem: unzen", "1 problem: unzen", "1 problem", "1"];
assert.equal(plan.fit(variants, 1000, w12), variants[0]);
assert.equal(plan.fit(variants, w12("1 problem"), w12), "1 problem");
assert.equal(plan.fit(variants, 0, w12), "1");
assert.equal(JSON.stringify(plan.minimum(m)), JSON.stringify({w: 150, h: 16 + 19 + 15 + 38 + 5}));
console.log("fleet-plan: " + boundaries.length + " width levels at +/-1 px, row height, summary, scroll and fitting pass");
