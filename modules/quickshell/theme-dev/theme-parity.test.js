// theme-parity.js: the failure modes, on small stand-ins, then the real
// tree. Run: node theme-parity.test.js <quickshell dir> <desktop-themes.md>
"use strict";
const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const P = require("./theme-parity.js");

const shell = `
    function reveal() { for (const desktop of x) desktop.reveal(); }
    if (desktop && typeof desktop.cycle === "function") desktop.cycle(a, b);
    shown: root.anyDesktop("fleetShown")
    function toggle(): void { root.fleetCall("toggleFleet"); }
`;
const c = P.contract(shell);
assert.deepEqual(c.methods, ["cycle", "reveal", "toggleFleet"]);
assert.deepEqual(c.flags, ["fleetShown"]);

const full = {
    id: "a", webCss: true, picker: true,
    desktop: `function reveal() {}\nfunction cycle(a, p) {}\nfunction toggleFleet() {}\nreadonly property bool fleetShown: x\nproperty bool omniClaimed: false\nLoader { source: theme.picker }`,
    files: ["o.claimView(desktop)"]
};
const bare = { id: "b", webCss: false, picker: true, desktop: `function reveal() {}\nLoader { source: theme.picker }`, files: [] };
const ledger = (lines) => "# x\n```parity-gaps\n# feature theme reason\n" + lines.join("\n") + "\n```\n";
const gapLines = ["cycle b Cool Switch is being built", "toggleFleet b the Fleet window is being built",
    "fleetShown b the Fleet window is being built", "omni-view b the Find window is being built", "web.css b the web sheet is being built"];

assert.deepEqual([...P.features(full, c)].sort(), ["cycle", "fleetShown", "omni-view", "picker", "reveal", "toggleFleet", "web.css"]);
assert.deepEqual([...P.features(bare, c)].sort(), ["picker", "reveal"]);
// claimView without omniClaimed, or the reverse, is not a claim.
assert.ok(!P.features(Object.assign({}, full, { files: [] }), c).has("omni-view"));
assert.ok(!P.features(Object.assign({}, full, { desktop: "function reveal() {}" }), c).has("omni-view"));

// Every gap listed: passes.
let r = P.parity([full, bare], shell, ledger(gapLines));
assert.deepEqual(r.errors, []);
assert.equal(r.missing.length, 5);
// One gap not listed: fails and names it.
r = P.parity([full, bare], shell, ledger(gapLines.filter((l) => !l.startsWith("cycle"))));
assert.equal(r.errors.length, 1);
assert.match(r.errors[0], /b lacks cycle, which a has/);
// The other way round too: a feature only the second theme has.
r = P.parity([bare, Object.assign({}, full, { id: "b" })].map((t, i) => Object.assign({}, t, { id: ["p", "q"][i] })), shell, ledger([]));
assert.ok(r.errors.some((e) => /p lacks web\.css, which q has/.test(e)));
// A gap that closed: fails until the line goes.
r = P.parity([full, Object.assign({}, full, { id: "b" })], shell, ledger(gapLines));
assert.ok(r.errors.some((e) => /b now has cycle: remove the gap/.test(e)));
// No reason, an unknown theme, no block at all.
r = P.parity([full, bare], shell, ledger(gapLines.concat(["picker b x"]).map((l) => l.startsWith("cycle") ? "cycle b short" : l)));
assert.ok(r.errors.some((e) => /cycle in b needs a reason/.test(e)));
r = P.parity([full, bare], shell, ledger(gapLines.concat(["cycle zz no such theme here"])));
assert.ok(r.errors.some((e) => /unknown theme "zz"/.test(e)));
r = P.parity([full, bare], shell, "# no block");
assert.ok(r.errors.some((e) => /no ```parity-gaps block/.test(e)));

// The real tree passes.
const out = execFileSync(process.execPath, [__dirname + "/theme-parity.js", process.argv[2] || __dirname + "/..", process.argv[3]], { encoding: "utf8" });
assert.match(out, /THEME_PARITY_PASSED/);
process.stdout.write(out);
console.log("THEME_PARITY_TESTS_PASSED");
