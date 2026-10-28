// Window motion per theme (window-motion.js): which move each event gets,
// the events a hide/show batch and a maximize make, and the frames.
// Run: node window-motion.test.js window-motion.js glance-plan.js
"use strict";
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const lib = (p) => fs.readFileSync(p, "utf8").replace(/^\.pragma library\s*$/m, "").replace(/^\.import .*$/gm, "");
const G = {};
vm.runInNewContext(lib(process.argv[3] || __dirname + "/glance-plan.js"), G);
const M = { GlancePlan: G };
vm.runInNewContext(lib(process.argv[2] || __dirname + "/window-motion.js"), M);
const eq = (a, b, m) => assert.deepEqual(JSON.parse(JSON.stringify(a)), JSON.parse(JSON.stringify(b)), m);

// ---- the table: Win98 animates minimize, restore and maximize with its
// caption; Platinum opens, closes, hides and shows with zoom rects; every
// other cell is a cut, and an unknown theme draws nothing.
eq(["minimize", "restore", "maximize", "unmaximize", "open", "close"].map((k) => M.style("win98", k)),
    ["caption", "caption", "caption", "caption", "", ""], "Win98: caption, and no open or close motion");
eq(["minimize", "restore", "maximize", "unmaximize", "open", "close"].map((k) => M.style("platinum", k)),
    ["zoom", "zoom", "", "", "zoom", "zoom"], "Platinum: zoom rects, and no zoom-box motion");
assert.equal(M.style("kamoi", "minimize"), "", "another theme cuts");

// ---- 150 ms: nine frames at 60 Hz, as the glance space.
assert.ok(Math.abs(M.DURATION - 150) < 1e-6);
const frames = (style, kind) => {
    const out = [];
    for (let k = 0; k < 12; k++) out.push(M.frame(style, kind, k * 1000 / 60, false));
    return out;
};
const cap = frames("caption", "minimize");
assert.equal(cap.filter((f) => !f.done).length, 9, "nine caption frames");
assert.ok(cap.slice(0, 9).every((f) => f.progress.length === 1), "one caption bar in flight");
assert.equal(cap[0].progress[0], 1, "minimize starts at the window");
assert.equal(cap[8].progress[0], 0, "and frame 8 lands on the button");
for (let k = 1; k < 9; k++) assert.ok(cap[k].progress[0] < cap[k - 1].progress[0], "toward the button every frame");
const res = frames("caption", "restore");
assert.equal(res[0].progress[0], 0, "restore starts at the button");
assert.equal(res[8].progress[0], 1, "and frame 8 lands on the window");
for (let k = 1; k < 9; k++) assert.ok(res[k].progress[0] > res[k - 1].progress[0], "toward the window every frame");
// Ease out toward the window, ease in toward the control (the glance's curves).
assert.ok(res[1].progress[0] - res[0].progress[0] > res[8].progress[0] - res[7].progress[0], "a restore slows as it lands");
assert.ok(cap[0].progress[0] - cap[1].progress[0] < cap[7].progress[0] - cap[8].progress[0], "a minimize speeds up into the button");
const zoom = frames("zoom", "open");
eq(zoom.slice(0, 5).map((f) => f.progress.length), [1, 2, 3, 4, 4], "zoom rects trail four");
assert.equal(zoom[8].progress[zoom[8].progress.length - 1], 1, "the newest zoom rect lands on the window");
const shut = frames("zoom", "close");
assert.equal(shut[8].progress[shut[8].progress.length - 1], 0, "a close lands on the tile");
assert.ok(zoom[9].done && zoom[9].progress.length === 0, "nothing after frame 8");
// Reduced motion is the cut: no frame draws anything.
for (const kind of ["minimize", "restore", "maximize", "open", "close"])
    for (const style of ["caption", "zoom"]) {
        const f = M.frame(style, kind, 0, true);
        assert.ok(f.done && f.progress.length === 0, `reduced ${style} ${kind} draws nothing`);
    }

// ---- rows: the snapshot and maximize.
const row = (address, extra) => Object.assign({ address, appId: "zed", title: "notes", page: 1, screen: "eDP-1",
    x: 100, y: 200, w: 800, h: 600, fullscreen: 0, active: false }, extra || {});
const shownAll = () => true;
const s0 = M.snapshot([row("aa"), row("bb", { x: undefined }), row("cc", { page: -98, workspace: "special:hidden-zed" })],
    (r) => r.page > 0);
eq(s0.aa.rect, { x: 100, y: 200, w: 800, h: 600 });
assert.equal(s0.bb.rect, null, "no rect before Hyprland says where");
assert.equal(s0.cc.shown, false);
const before = M.snapshot([row("aa"), row("dd", { fullscreen: 1, x: 0, y: 0, w: 1920, h: 1100 })], shownAll);
const after = M.snapshot([row("aa", { fullscreen: 1, x: 0, y: 30, w: 1920, h: 1100 }), row("dd", { fullscreen: 0 })], shownAll);
eq(M.zooms(before, after).map((z) => [z.kind, z.address, z.rect.w, z.to.w]),
    [["maximize", "aa", 800, 1920], ["unmaximize", "dd", 1920, 800]], "maximize and restore, old rect to new");
const full = M.snapshot([row("aa", { fullscreen: 2, x: 0, y: 0, w: 1920, h: 1200 })], shownAll);
eq(M.zooms(before, full), [], "fullscreen has no caption motion");
eq(M.zooms({}, after), [], "no event for a window seen for the first time (restart, theme switch)");

// ---- a hide/show batch.
const known = M.snapshot([row("aa", { active: true }), row("bb", { page: 2 }), row("cc", { page: -98 })], (r) => r.page === 1);
const hide = M.fromMoves([{ address: "aa", workspace: "special:hidden-zed" }, { address: "bb", workspace: "special:hidden-zed" }],
    known, { windows: {} }, {}, { "eDP-1": 1 }, "");
eq(hide.map((e) => [e.kind, e.address, e.active]), [["minimize", "aa", true]], "only a shown window's hide is drawn");
const kept = { cc: { rect: { x: 5, y: 6, w: 7, h: 8 }, screen: "HDMI-A-1" } };
const state = { windows: { cc: { app: "zed", page: 3, screen: "HDMI-A-1" } } };
eq(M.fromMoves([{ address: "cc", workspace: 3 }], known, state, kept, { "HDMI-A-1": 3 }, "").map((e) => [e.kind, e.screen, e.rect.w]),
    [["restore", "HDMI-A-1", 7]], "a show onto its screen's shown page, on its home screen, to its kept rect");
eq(M.fromMoves([{ address: "cc", workspace: 4 }], known, state, kept, { "HDMI-A-1": 3 }, ""), [],
    "a show onto a page no screen shows is not drawn");
eq(M.fromMoves([{ address: "cc", workspace: 4 }], known, state, {}, { "HDMI-A-1": 3 }, "0xcc").map((e) => [e.kind, e.rect, e.active]),
    [["restore", null, true]], "a focused restore is drawn, to the work area when its rect was never seen");

// ---- events and geometry.
assert.equal(M.eventAddress("55d0e1a2b3c0,1,zed,notes"), "55d0e1a2b3c0");
assert.equal(M.eventAddress("0x55d0"), "55d0");
eq(M.captionOf({ x: 10, y: 50, w: 300, h: 200 }, 25), { x: 10, y: 25, w: 300, h: 25 });
eq(M.frameOf({ x: 10, y: 50, w: 300, h: 200 }, 20), { x: 10, y: 30, w: 300, h: 220 });
eq(M.local({ x: 1930, y: 10, w: 5, h: 5 }, { x: 1920, y: 0 }), { x: 10, y: 10, w: 5, h: 5 });
eq(M.between({ x: 0, y: 0, w: 10, h: 10 }, { x: 100, y: 100, w: 110, h: 110 }, 0.5), { x: 50, y: 50, w: 60, h: 60 });
console.log("WINDOW_MOTION_TESTS_PASSED");
