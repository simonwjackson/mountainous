// desktop-art.js: the pattern per theme and appearance, and its tile size.
// Run: node desktop-art.test.js desktop-art.js themes.json
// With "--state <dir>" it prints the pattern the shell would draw for the
// state files in <dir> (checks.native-themes, after each desktop-theme call).
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const A = {};
const source = process.argv[2] || __dirname + "/desktop-art.js";
vm.runInNewContext(fs.readFileSync(source, "utf8").replace(/^\.pragma library\s*$/m, ""), A);
const registryPath = process.argv[3] || __dirname + "/themes.json";
const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
const find = (id) => registry.find((t) => t.id === id) || registry.find((t) => t.id === "platinum");

if (process.argv[4] === "--state") {
    // Theme.qml's reading of the three files: a missing or unknown name is
    // Platinum, a missing mode dark, a missing extra file off.
    const read = (name) => { try { return fs.readFileSync(path.join(process.argv[5], name), "utf8").trim(); } catch (e) { return ""; } };
    const mode = read("theme") === "light" ? "light" : "dark";
    process.stdout.write(A.pattern(find(read("theme-name")), mode, read("theme-extra") === "on") + "\n");
    process.exit(0);
}

const platinum = find("platinum"), win98 = find("win98");
assert.equal(A.appearance(platinum, "light", false), "light");
assert.equal(A.appearance(platinum, "light", true), "light");
assert.equal(A.appearance(platinum, "dark", false), "dark");
assert.equal(A.appearance(platinum, "dark", true), "extra");
// Win98 keeps the Extra dark choice but ignores it.
assert.equal(A.appearance(win98, "dark", true), "dark");
assert.equal(A.appearance(null, "dark", true), "dark");

// Every theme has a tile for every appearance it offers, under its folder.
const root = path.dirname(registryPath);
for (const theme of registry) {
    const appearances = theme.appearances.map((a) => a.mode).concat(theme.options.extraDark ? ["extra"] : []);
    for (const a of appearances) {
        const file = theme.art.patterns[a];
        assert.ok(file && file.startsWith("themes/" + theme.id + "/"), theme.id + " " + a);
        assert.ok(fs.existsSync(path.join(root, file)), file);
        const svg = fs.readFileSync(path.join(root, file), "utf8");
        assert.match(svg, /viewBox="0 0 8 8"/, file);
        assert.match(svg, /shape-rendering="crispEdges"/, file);
    }
    assert.deepEqual(Object.keys(theme.art.patterns).sort(), appearances.sort(), theme.id);
}
// The five appearances draw five different tiles.
const five = [["platinum", "light", false], ["platinum", "dark", false], ["platinum", "dark", true],
              ["win98", "light", false], ["win98", "dark", true]].map(([t, m, e]) => A.pattern(find(t), m, e));
assert.equal(new Set(five).size, 5);
assert.equal(A.pattern(win98, "dark", true), A.pattern(win98, "dark", false));
assert.equal(A.pattern({ id: "x" }, "dark", false), "");

// Whole device pixels: at Myoko's 1.5 a Platinum cell is 3 device px and
// the tile 16 logical px; at 1 and 2 the cell follows the scale.
assert.deepEqual(JSON.parse(JSON.stringify(A.tile(3, 1.5))), { cell: 3, logical: 16 });
assert.deepEqual(JSON.parse(JSON.stringify(A.tile(3, 1))), { cell: 2, logical: 16 });
assert.deepEqual(JSON.parse(JSON.stringify(A.tile(3, 2))), { cell: 4, logical: 16 });
assert.deepEqual(JSON.parse(JSON.stringify(A.tile(2, 1.5))), { cell: 3, logical: 16 });
for (const dpr of [1, 1.25, 1.5, 1.75, 2, 2.25, 3]) {
    for (const base of [2, 3]) {
        const t = A.tile(base, dpr);
        assert.equal(t.logical * dpr, 8 * t.cell, base + "@" + dpr);
        assert.ok(Number.isInteger(t.logical) && t.cell >= 1, base + "@" + dpr);
    }
}
console.log("DESKTOP_ART_TESTS_PASSED");
