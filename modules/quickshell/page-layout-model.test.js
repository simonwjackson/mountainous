// page-layout-model.js under node: the Layout control's view of the state
// file that modules/hyprland/page-layout.lua writes.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const m = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/page-layout-model.js", "utf8").replace(/^\.pragma library\s*$/m, ""), m);

assert.equal(m.parse("{"), null, "half-written file keeps the last state");
assert.equal(m.parse('{"version":2}'), null, "unknown version is ignored");

const state = m.parse(JSON.stringify({
    version: 1,
    fallback: { cap: 1, floating: false, gap: 8 },
    defaults: { "eDP-1": { cap: 1, floating: false, gap: 8 }, "DP-3": { cap: 2, floating: false, gap: 16 } },
    pages: {
        "1": { monitor: "eDP-1", cap: 1, floating: false, gap: 8, zen: false, own: false },
        "2": { monitor: "eDP-1", cap: 2, floating: false, gap: 8, zen: false, own: true },
        "4": { monitor: "eDP-1", cap: 3, floating: true, gap: 50, zen: true, own: true },
        "3": { monitor: "DP-3", cap: 2, floating: false, gap: 16, own: false },
    },
}));

let v = m.view(state, "eDP-1", 2, [4, 1, 2]);
assert.equal(v.available, true);
assert.equal(v.pageIndex, 2, "page 2 is the second page on this screen");
assert.equal(v.pageCount, 3);
assert.equal(v.page.cap, 2);
assert.equal(v.def.cap, 1);
assert.equal(v.ownCount, 2, "pages 2 and 4 differ from the default");
assert.equal(v.glyph, "tile-2");
assert.equal(v.title, "Built-in Display");
assert.equal(m.capNote(v.page), "A third window opens on the next page.");

v = m.view(state, "eDP-1", 4, [1, 2, 4]);
assert.equal(v.page.gap, 48, "gaps clamp to 48");
assert.equal(v.page.zen, true);
assert.equal(v.glyph, "float");
assert.match(m.capNote(v.page), /do not count/);

v = m.view(state, "DP-3", 3, [3]);
assert.equal(v.def.gap, 16, "each screen has its own default");
assert.equal(v.ownCount, 0);

v = m.view(state, "DP-3", 9, [3, 9]);
assert.equal(v.page.cap, 2, "a page the file does not know yet shows the screen default");

v = m.view(null, "eDP-1", -1, []);
assert.equal(v.available, false, "no state file, or no page yet: unavailable");
assert.equal(v.page.cap, 1);

assert.equal(m.clampGap(9), 8);
assert.equal(m.clampGap(-4), 0);
assert.equal(m.clampGap(100), 48);
assert.equal(m.word(3), "Three");
assert.equal(m.screenTitle("SUNSHINE"), "Tablet");
console.log("page-layout-model: parse, per-screen view, clamps and words pass");
