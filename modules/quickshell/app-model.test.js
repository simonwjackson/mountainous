// app-model.js: grouping by app, MRU, and Super+Tab cycling.
// Run: node app-model.test.js app-model.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const A = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/app-model.js", "utf8")
    .replace(/^\.pragma library\s*$/m, ""), A);
const plain = (v) => JSON.parse(JSON.stringify(v));
const row = (address, appId, page, extra) => Object.assign({ address, appId, page, title: address, workspace: String(page), screen: "eDP-1" }, extra || {});
const names = { firefox: "Firefox", ghostty: "Ghostty", gh: "GitHub", signal: "Signal", obsidian: "Obsidian", mpv: "mpv" };

// ---- MRU
let mru = [];
for (const a of ["w1", "w2", "0xw3", "w1"]) mru = A.touch(mru, a);
assert.deepEqual(plain(mru), ["w1", "w3", "w2"]);
assert.deepEqual(plain(A.touch(mru, "")), ["w1", "w3", "w2"]);
let long = [];
for (let i = 0; i < 400; i++) long = A.touch(long, "x" + i);
assert.equal(long.length, 256, "bounded");
assert.equal(long[0], "x399");

const rows = [
    row("w1", "ghostty", 1, { focusHistory: 3 }),
    row("w2", "firefox", 1, { focusHistory: 0 }),
    row("w3", "gh", 2, { focusHistory: 1 }),
    row("w4", "gh", 2, { focusHistory: 4 }),
    row("w5", "gh", 3, { focusHistory: 2 }),
    row("w6", "signal", -99, { workspace: "special:hidden-signal", focusHistory: 5 }),
    row("w7", "", 1),
];
// A restart: Hyprland's focus history seeds the order.
assert.deepEqual(plain(A.reconcile([], rows)), ["w2", "w3", "w5", "w1", "w4", "w6", "w7"]);
assert.deepEqual(plain(A.reconcile(["gone", "w4", "w1"], rows)).slice(0, 3), ["w4", "w1", "w2"]);
mru = A.reconcile([], rows);

// ---- the Application menu's apps: by name, windows most recent first
const list = A.apps(rows, mru, "w2", names, { gh: "webapp-github" });
assert.deepEqual(plain(list.map((a) => a.name)), ["Firefox", "Ghostty", "GitHub", "Signal"]);
const gh = list.find((a) => a.appId === "gh");
assert.deepEqual(plain(gh.windows.map((w) => w.address)), ["w3", "w5", "w4"]);
assert.equal(gh.count, 3);
assert.equal(gh.icon, "webapp-github");
assert.equal(list.find((a) => a.appId === "firefox").front, true);
assert.equal(list.find((a) => a.appId === "ghostty").front, false);
assert.equal(list.find((a) => a.appId === "signal").hidden, true);
assert.equal(list.find((a) => a.appId === "signal").icon, "signal", "no icon map entry: the app id");
assert.equal(A.apps([], [], "", {}, {}).length, 0);
assert.equal(A.apps(rows, mru, "", names, {}).some((a) => a.front), false);

// ---- recent window: the app's most recent
assert.equal(A.recentWindow(gh, mru).address, "w3");
assert.equal(A.recentWindow(null, mru), null);

// ---- app order: by each app's most recent window
assert.deepEqual(plain(A.appOrder(rows, mru, names)), ["firefox", "gh", "ghostty", "signal"]);

// ---- cycling. Start: Firefox (w2) in front, then GitHub (w3), Ghostty, Signal.
// The quick press focused the last window, w3 (GitHub): MRU is now w3, w2, ...
const afterQuick = A.touch(mru, "w3");
let c = A.cycleStart(rows, afterQuick, names);
assert.deepEqual(plain(c.order), ["firefox", "gh", "ghostty", "signal"], "the order before the quick press");
assert.equal(c.base, 1, "GitHub is in front after the quick press");
assert.equal(A.cycleTarget(c, 1), "gh");
assert.equal(A.cycleTarget(c, 2), "ghostty", "second Tab: the next app after GitHub");
assert.equal(A.cycleTarget(c, 3), "signal", "hidden apps take part");
assert.equal(A.cycleTarget(c, 4), "firefox", "wraps");
assert.equal(A.cycleTarget(c, 0), "firefox", "Shift+Tab back past the start");
assert.equal(A.cycleTarget(c, -2), "ghostty");

// The quick press reached another window of the same app (two Firefox windows).
const same = rows.concat([row("w8", "firefox", 1)]);
let m2 = A.touch(A.touch(A.reconcile([], same), "w8"), "w2");  // w2, w8, ...
m2 = A.touch(m2, "w8");                                        // quick press: w8, w2, ...
c = A.cycleStart(same, m2, names);
assert.equal(c.base, 0);
assert.equal(A.cycleTarget(c, 2), "gh", "the next app, not the one after it");

// One app, one window: the cycle stays on it.
c = A.cycleStart([row("w1", "ghostty", 1)], ["w1"], names);
assert.equal(A.cycleTarget(c, 2), "ghostty");
assert.equal(A.cycleTarget({ order: [], base: 0 }, 2), "");
assert.equal(A.cycleTarget(null, 2), "");

// ---- stale cycle messages
assert.equal(A.accept(4, 5), true);
assert.equal(A.accept(5, 5), false);
assert.equal(A.accept(5, 3), false);
assert.equal(A.accept(5, "6"), false);

// ---- many: 52 windows over 9 apps stay grouped and ordered
const many = Array.from({ length: 52 }, (_, i) => row("m" + i, "app" + (i % 9), 1 + (i % 9)));
const mm = A.reconcile([], many);
assert.equal(A.apps(many, mm, "m0", {}, {}).length, 9);
assert.equal(A.appOrder(many, mm, {}).length, 9);
// ---- window cycling (Win98's Cool Switch): windows, not apps
// Before the quick press: w2 (Firefox) in front, then w3, w5, w1, w4, w6, w7.
// The quick press focused w3; position 1 is w3, 2 the next window after it.
let wc = A.windowCycleStart(rows, afterQuick);
assert.deepEqual(plain(wc.order), ["w2", "w3", "w5", "w1", "w4", "w6", "w7"], "the window order before the quick press");
assert.equal(wc.base, 1);
assert.equal(A.cycleTarget(wc, 1), "w3");
assert.equal(A.cycleTarget(wc, 2), "w5", "another window of the same app is its own stop");
assert.equal(A.cycleTarget(wc, 5), "w6", "a hidden window takes part");
assert.equal(A.cycleTarget(wc, 7), "w2", "wraps to the window the quick press left");
assert.equal(A.cycleTarget(wc, 0), "w2", "Shift+Tab back past the start");
assert.equal(A.cycleTarget(wc, -1), "w7");
// Closed windows leave the order; unknown ones join at the end; 0x is dropped.
wc = A.windowCycleStart(rows.filter((r) => r.address !== "w5"), ["0xw3", "gone", "w2"]);
assert.deepEqual(plain(wc.order), ["w2", "w3", "w1", "w4", "w6", "w7"]);
assert.equal(A.cycleTarget(wc, 2), "w1");
// One window, and none.
wc = A.windowCycleStart([row("w1", "ghostty", 1)], ["w1"]);
assert.deepEqual(plain(wc), { order: ["w1"], base: 0 });
assert.equal(A.cycleTarget(wc, 3), "w1");
assert.equal(A.cycleTarget(A.windowCycleStart([], []), 2), "");
assert.equal(A.windowCycleStart(rows, []).base, 0, "no MRU: the first live window");

// ---- out-of-order messages: the shell's guard (shell.qml cycleChrome) in
// front of a window cycle. Two qs processes can deliver hyprland.lua's
// numbered messages in any order; a step older than the commit must not
// reopen or move the finished cycle.
function runCycle(messages) {
    let last = 0, cycle = null, target = "", committed = "";
    const seen = [];
    for (const m of messages) {
        if (!A.accept(last, m.seq)) { seen.push("stale " + m.seq); continue; }
        last = m.seq;
        if (m.action === "cancel") { cycle = null; target = ""; seen.push("cancel"); continue; }
        if (!cycle) cycle = A.windowCycleStart(rows, afterQuick);
        target = A.cycleTarget(cycle, m.position);
        if (m.action === "commit") { committed = target; cycle = null; }
        seen.push(m.action + " " + target);
    }
    return { committed, open: cycle !== null, seen };
}
let run = runCycle([{ action: "step", position: 2, seq: 11 }, { action: "step", position: 3, seq: 12 }, { action: "commit", position: 3, seq: 13 }]);
assert.equal(run.committed, "w1");
assert.equal(run.open, false);
run = runCycle([{ action: "step", position: 2, seq: 11 }, { action: "commit", position: 3, seq: 13 }, { action: "step", position: 3, seq: 12 }]);
assert.equal(run.committed, "w1", "the commit carries the final position");
assert.equal(run.open, false, "the late step does not open a new cycle");
assert.deepEqual(run.seen, ["step w5", "commit w1", "stale 12"]);
run = runCycle([{ action: "commit", position: 2, seq: 21 }, { action: "step", position: 2, seq: 20 }]);
assert.deepEqual(run.seen, ["commit w5", "stale 20"], "a step that arrives after its commit is dropped");
run = runCycle([{ action: "step", position: 2, seq: 31 }, { action: "cancel", position: 0, seq: 33 }, { action: "commit", position: 2, seq: 32 }]);
assert.equal(run.committed, "", "a commit older than the cancel is dropped");
assert.equal(run.open, false);
console.log("app-model: MRU, grouping, recent window, cycle order, window cycle and stale messages pass");

// A no-tab browser can have dozens of windows with the same Wayland class.
// The Application menu groups the app, not its windows: no page may vanish.
for (const count of [20, 40]) {
    // Repeated real-site titles must not merge distinct native windows.
    const chromiumPages = Array.from({length:count}, (_,i) => row("browser-"+i,"chromium-browser",i+1,{title:"Site "+(i%5),focusHistory:i}));
    const browserMru = A.reconcile([],chromiumPages);
    const browsers = A.apps(chromiumPages,browserMru,"browser-0",{"chromium-browser":"Chromium"},{});
    assert.equal(browsers.length,1);
    assert.equal(browsers[0].count,count);
    assert.equal(new Set(browsers[0].windows.map(w=>w.address)).size,count);
    const cycle = A.windowCycleStart(chromiumPages,browserMru);
    assert.equal(cycle.order.length,count,"Win98 cycles all browser windows, not one app group");
    assert.equal(new Set(Array.from({length:count}, (_,i) => A.cycleTarget(cycle,i))).size,count,
        "all windows remain reachable even when their titles are the same");
    assert.equal(A.cycleStart(chromiumPages,browserMru,{}).order.length,1,
        "Platinum's held switcher cycles apps, not forty copies of Chromium");
}
