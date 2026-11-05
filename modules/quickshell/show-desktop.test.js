// show-desktop.js: park the shown page's windows, bring them back, and
// stay right when windows open or close in between.
// Run: node show-desktop.test.js show-desktop.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const S = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/show-desktop.js", "utf8")
    .replace(/^\.pragma library\s*$/m, ""), S);
const plain = (v) => JSON.parse(JSON.stringify(v));

const row = (address, page, screen, extra) => Object.assign({
    address, appId: "app-" + address, title: "w " + address, page,
    workspace: page > 0 ? String(page) : "", screen, active: false,
}, extra || {});
// Apply moves the way Hyprland would: a name is a special workspace.
const apply = (rows, moves) => rows.map((r) => {
    const m = moves.find((x) => x.address === r.address);
    if (!m) return r;
    return typeof m.workspace === "number"
        ? Object.assign({}, r, { page: m.workspace, workspace: String(m.workspace) })
        : Object.assign({}, r, { page: -99, workspace: m.workspace, active: false });
});

// ---- names
assert.equal(S.workspaceFor("eDP-1"), "special:desktop-eDP-1");
assert.equal(S.workspaceFor("a b\"c"), "special:desktop-a_b_c");
assert.equal(S.workspaceFor(""), "special:desktop-screen");
assert.equal(S.isParkedWorkspace("special:desktop-eDP-1"), true);
assert.equal(S.isParkedWorkspace("special:hidden-firefox"), false);
assert.equal(S.isParkedWorkspace(undefined), false);

let rows = [
    row("a1", 1, "eDP-1", { active: true }),
    row("a2", 1, "eDP-1"),
    row("a3", 2, "eDP-1"),                                   // another page: stays
    row("b1", 1, "DP-2"),                                    // another screen: stays
    { address: "h1", appId: "x", page: -98, workspace: "special:hidden-x", screen: "eDP-1" }, // minimized: stays
];

// ---- show: only the shown page of this screen
let r = S.toggle(S.empty(), rows, "eDP-1", 1, { screens: ["eDP-1", "DP-2"] });
assert.equal(r.action, "show");
assert.deepEqual(plain(r.moves), [
    { address: "a1", workspace: "special:desktop-eDP-1" },
    { address: "a2", workspace: "special:desktop-eDP-1" }]);
assert.deepEqual(plain(r.state.screens["eDP-1"]), { focus: "a1", windows: { a1: 1, a2: 1 } });
rows = apply(rows, r.moves);
assert.equal(S.active(rows, "eDP-1"), true);
assert.equal(S.active(rows, "DP-2"), false);
let state = r.state;

// ---- restore: back to their page, focus returns
r = S.toggle(state, rows, "eDP-1", 1, { screens: ["eDP-1", "DP-2"] });
assert.equal(r.action, "restore");
assert.deepEqual(plain(r.moves), [{ address: "a1", workspace: 1 }, { address: "a2", workspace: 1 }]);
assert.equal(r.focus, "a1");
assert.deepEqual(plain(r.state.screens), {});
rows = apply(rows, r.moves);
assert.equal(S.active(rows, "eDP-1"), false);

// ---- nothing to do on an empty page
r = S.toggle(S.empty(), [row("z", 3, "eDP-1")], "eDP-1", 1, {});
assert.equal(r.action, "none");
assert.deepEqual(plain(r.moves), []);

// ---- a window closes while the desktop shows: forgotten, the rest return
rows = [row("a1", 1, "eDP-1", { active: true }), row("a2", 1, "eDP-1"), row("a3", 1, "eDP-1")];
r = S.toggle(S.empty(), rows, "eDP-1", 1, {});
rows = apply(rows, r.moves); state = r.state;
rows = rows.filter((x) => x.address !== "a1");               // the focused one closed
r = S.toggle(state, rows, "eDP-1", 1, {});
assert.equal(r.action, "restore");
assert.deepEqual(plain(r.moves), [{ address: "a2", workspace: 1 }, { address: "a3", workspace: 1 }]);
assert.equal(r.focus, "", "a closed window is never focused");
rows = apply(rows, r.moves);

// ---- a window opens while the desktop shows: the next press parks it
// too (the desktop is covered again), and the press after brings every
// window back, the new one included, each to its own page.
rows = [row("a1", 1, "eDP-1"), row("a2", 1, "eDP-1")];
r = S.toggle(S.empty(), rows, "eDP-1", 1, {});
rows = apply(rows, r.moves); state = r.state;
rows = rows.concat([row("n1", 1, "eDP-1", { active: true })]);
r = S.toggle(state, rows, "eDP-1", 1, {});
assert.equal(r.action, "show");
assert.deepEqual(plain(r.moves), [{ address: "n1", workspace: "special:desktop-eDP-1" }]);
assert.deepEqual(plain(r.state.screens["eDP-1"].windows), { a1: 1, a2: 1, n1: 1 });
rows = apply(rows, r.moves); state = r.state;
r = S.toggle(state, rows, "eDP-1", 1, {});
assert.equal(r.action, "restore");
assert.deepEqual(plain(r.moves.map((m) => m.address).sort()), ["a1", "a2", "n1"]);
assert.equal(r.focus, "n1");

// ---- a window that opens and is left uncovered: Show Desktop parks it
// alone; the parked ones stay parked until the screen is clear again.
rows = [row("a1", 1, "eDP-1")];
r = S.toggle(S.empty(), rows, "eDP-1", 1, {});
rows = apply(rows, r.moves); state = r.state;
// The user switched to page 2 meanwhile and opened a window there.
rows = rows.concat([row("p2", 2, "eDP-1")]);
r = S.toggle(state, rows, "eDP-1", 2, {});
assert.equal(r.action, "show");
rows = apply(rows, r.moves); state = r.state;
r = S.toggle(state, rows, "eDP-1", 2, {});
assert.equal(r.action, "restore");
assert.deepEqual(plain(r.moves), [{ address: "a1", workspace: 1 }, { address: "p2", workspace: 2 }],
    "each window returns to the page it left, not the page shown now");

// ---- after a restart with the state lost: parked windows are adopted and
// return to the page shown.
rows = [row("q1", -99, "eDP-1", { workspace: "special:desktop-eDP-1" })];
r = S.toggle(S.parse("garbage"), rows, "eDP-1", 4, {});
assert.equal(r.action, "restore");
assert.deepEqual(plain(r.moves), [{ address: "q1", workspace: 4 }]);

// ---- a screen that left: its parked windows come back with the next restore.
rows = [row("t1", -99, "HDMI-A-1", { workspace: "special:desktop-HDMI-A-1" })];
r = S.toggle(S.empty(), rows, "eDP-1", 1, { screens: ["eDP-1"] });
assert.equal(r.action, "restore");
assert.deepEqual(plain(r.moves), [{ address: "t1", workspace: 1 }]);
r = S.toggle(S.empty(), rows, "eDP-1", 1, { screens: ["eDP-1", "HDMI-A-1"] });
assert.equal(r.action, "none", "a present screen keeps its own parked windows");

// ---- one window back (a Memphis taskbar button)
rows = [row("a1", 1, "eDP-1"), row("a2", 3, "eDP-1")];
state = S.empty();
r = S.toggle(state, rows, "eDP-1", 1, {});
rows = apply(rows, r.moves); state = r.state;
assert.equal(S.homeOf(state, "0xa1"), 1);
assert.equal(S.screenOf(state, rows[0]), "eDP-1");
r = S.restoreWindow(state, rows, "0xa1", 1);
assert.deepEqual(plain(r.moves), [{ address: "a1", workspace: 1 }]);
assert.equal(r.focus, "a1");
assert.deepEqual(plain(r.state.screens), {});
assert.equal(S.restoreWindow(state, rows, "a2", 1).action, "none", "a window that is not parked");

// ---- state file
const text = S.serialize({ version: 1, screens: { "eDP-1": { focus: "0xa1", windows: { "0xa1": 2, a2: -3, a3: "x" } } } });
assert.deepEqual(plain(S.parse(text)), { version: 1, screens: { "eDP-1": { focus: "a1", windows: { a1: 2, a2: null, a3: null } } } });
assert.deepEqual(plain(S.parse("{}")), plain(S.empty()));
assert.deepEqual(plain(S.parse('{"screens": 4}')), plain(S.empty()));

console.log("show-desktop: show, restore, opened and closed windows, restarts, screens, one window");
