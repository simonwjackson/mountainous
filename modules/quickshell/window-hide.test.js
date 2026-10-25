// window-hide.js: hide moves to a per-app special workspace and remembers
// the home page; show returns windows home, also after a restart (parse).
// Run: node window-hide.test.js window-hide.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const H = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/window-hide.js", "utf8")
    .replace(/^\.pragma library\s*$/m, ""), H);
const plain = (v) => JSON.parse(JSON.stringify(v));

const row = (address, appId, page, screen, extra) => Object.assign({
    address, appId, title: appId + " " + address, page,
    workspace: page > 0 ? String(page) : page === -1 ? "" : "special:x", screen,
}, extra || {});

const rows = [
    row("0xa1", "firefox", 1, "eDP-1"),
    row("a2", "com.mitchellh.ghostty", 1, "eDP-1"),
    row("a3", "com.mitchellh.ghostty", 2, "eDP-1"),
    row("a4", "chrome-github.com__-Default", 3, "eDP-1"),
    row("b1", "firefox", 4, "DP-2"),
    row("b2", "signal", 4, "DP-2"),
    row("c1", "mpv", -1, "eDP-1"),                       // between pages
];

// ---- names
assert.equal(H.workspaceFor("firefox"), "special:hidden-firefox");
assert.equal(H.workspaceFor("chrome-github.com__-Default"), "special:hidden-chrome-github.com__-Default");
assert.equal(H.workspaceFor('a "quoted" app/id'), "special:hidden-a__quoted__app_id");
assert.equal(H.workspaceFor(""), "special:hidden-app");
assert.equal(H.isHiddenWorkspace("special:hidden-firefox"), true);
assert.equal(H.isHiddenWorkspace("special:term"), false);
assert.equal(H.isHiddenWorkspace("3"), false);
assert.equal(H.isHiddenWorkspace(undefined), false);
assert.equal(H.key("0x55ab"), "55ab");

// ---- hide one app, every screen
let r = H.hideApp(H.empty(), rows, "firefox");
assert.deepEqual(plain(r.moves), [
    { address: "a1", workspace: "special:hidden-firefox" },
    { address: "b1", workspace: "special:hidden-firefox" },
]);
assert.deepEqual(plain(r.state.windows.a1), { app: "firefox", page: 1, screen: "eDP-1", title: "firefox 0xa1" });
assert.equal(r.state.windows.b1.page, 4);
assert.equal(H.command(r.moves),
    'dispatch hl.dsp.window.move({ window = "address:0xa1", workspace = "special:hidden-firefox", follow = false }) ; '
    + 'dispatch hl.dsp.window.move({ window = "address:0xb1", workspace = "special:hidden-firefox", follow = false })');

// The windows land on the special workspace; model that.
const after = rows.map((x) => r.moves.some((m) => m.address === H.key(x.address))
    ? Object.assign({}, x, { page: -98, workspace: "special:hidden-firefox" }) : x);
assert.deepEqual(plain(H.hiddenApps(after)), ["firefox"]);
assert.equal(H.hiddenRows(after).length, 2);

// Hiding again changes nothing: already hidden windows are skipped.
const again = H.hideApp(r.state, after, "firefox");
assert.equal(again.moves.length, 0);

// ---- a restart: the file round-trips, and reconcile keeps live entries
const text = H.serialize(r.state);
const loaded = H.parse(text);
assert.deepEqual(plain(loaded), plain(r.state));
const reconciled = H.reconcile(loaded, after);
assert.deepEqual(Object.keys(reconciled.windows).sort(), ["a1", "b1"]);

// ---- show returns each window to its own page, not the current one
const shown = H.showApp(reconciled, after, "firefox", 7);
assert.deepEqual(plain(shown.moves), [{ address: "a1", workspace: 1 }, { address: "b1", workspace: 4 }]);
assert.deepEqual(plain(shown.state.windows), {});
assert.equal(H.command(shown.moves).split(" ; ")[0],
    'dispatch hl.dsp.window.move({ window = "address:0xa1", workspace = 1, follow = false })');

// ---- Hide Others is per screen
const others = H.hideOthers(H.empty(), rows, "com.mitchellh.ghostty", "eDP-1");
assert.deepEqual(plain(others.moves.map((m) => m.address)), ["a1", "a4"],
    "other apps on this screen hide; DP-2 and the between-pages window stay");

// ---- a window found hidden with no entry is adopted; it shows on the fallback page
const orphan = [row("d1", "obsidian", -97, "eDP-1", { workspace: "special:hidden-obsidian" })];
const adopted = H.reconcile(H.empty(), orphan);
assert.deepEqual(plain(adopted.windows.d1), { app: "obsidian", page: null, screen: "eDP-1", title: "obsidian d1" });
assert.deepEqual(plain(H.showAll(adopted, orphan, 3).moves), [{ address: "d1", workspace: 3 }]);
assert.deepEqual(plain(H.showAll(adopted, orphan, 0).moves), [{ address: "d1", workspace: 1 }]);

// ---- a closed window is forgotten
assert.deepEqual(Object.keys(H.reconcile(loaded, rows.filter((x) => x.address !== "0xa1")).windows), ["b1"],
    "a1 closed: forgotten; b1 is live (its move may be in flight): kept");

// ---- bad files never throw
for (const bad of ["", "{", "null", "[]", '{"windows": 3}', '{"windows": {"x": 5}}']) {
    assert.deepEqual(plain(H.parse(bad).windows), {}, bad);
}
assert.equal(H.parse('{"windows": {"0xff": {"app": "a", "page": -3}}}').windows.ff.page, null);

// ---- counts: 0, 1 and many
assert.equal(H.hideApp(H.empty(), [], "x").moves.length, 0);
const many = Array.from({ length: 60 }, (_, i) => row("m" + i, "app" + (i % 3), 1 + (i % 9), "eDP-1"));
const big = H.hideOthers(H.empty(), many, "app0", "eDP-1");
assert.equal(big.moves.length, 40);
assert.equal(Object.keys(big.state.windows).length, 40);
console.log("window-hide: hide, show, restart, hide others per screen, adoption, bad files pass");
