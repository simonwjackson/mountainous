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
    process.stdout.write(A.pattern(find(read("theme-name")), mode, read("theme-extra") === "on", read("theme-appearance")) + "\n");
    process.exit(0);
}

const platinum = find("platinum"), memphis = find("memphis");
assert.equal(A.appearance(platinum, "light", false), "light");
assert.equal(A.appearance(platinum, "light", true), "light");
assert.equal(A.appearance(platinum, "dark", false), "dark");
assert.equal(A.appearance(platinum, "dark", true), "extra");
// Memphis keeps the Extra dark choice but ignores it.
assert.equal(A.appearance(memphis, "dark", true), "dark");
assert.equal(A.appearance(null, "dark", true), "dark");

// Only real tiles belong in the registry. Schemes without a tile are solid.
const root = path.dirname(registryPath);
for (const theme of registry) {
    for (const file of Object.values(theme.art.patterns)) {
        assert.ok(file.startsWith("themes/" + theme.id + "/"), file);
        assert.ok(fs.existsSync(path.join(root, file)), "missing registered pattern: " + file);
        const svg = fs.readFileSync(path.join(root, file), "utf8");
        assert.match(svg, /viewBox="0 0 8 8"/, file);
        assert.match(svg, /shape-rendering="crispEdges"/, file);
    }
}
assert.deepEqual(Object.keys(memphis.art.patterns).sort(), ["dark", "light"]);
assert.deepEqual(Object.keys(platinum.art.patterns).sort(), ["dark", "drawing-board", "extra", "light"]);
// Existing Memphis tiles remain byte-for-byte unchanged.
const crypto = require("node:crypto");
for (const [mode, digest] of Object.entries({
    light: "fefa39a17477f326f0e9ca94f3ca4947852c068dc8b174181452373bc3ba449d",
    dark: "e916792350c8a1d2318323195aa6c5b53d3b10beffb01ef6f7203bb781094cd0"
})) {
    assert.equal(crypto.createHash("sha256").update(fs.readFileSync(path.join(root, memphis.art.patterns[mode]))).digest("hex"), digest);
}
assert.equal(A.pattern(memphis, "light", false, "standard"), memphis.art.patterns.light);
assert.equal(A.pattern(memphis, "dark", true, "dark-grey"), memphis.art.patterns.dark);
assert.equal(A.pattern(platinum, "light", true, "drawing-board"), platinum.art.patterns["drawing-board"]);
assert.equal(A.pattern(memphis, "dark", true, "unknown"), memphis.art.patterns.dark);
if (process.env.KIT_PALETTES && process.env.SCHEMES_JSON) {
    const kit = JSON.parse(fs.readFileSync(process.env.KIT_PALETTES, "utf8"));
    const schemes = JSON.parse(fs.readFileSync(process.env.SCHEMES_JSON, "utf8")).filter((s) => !s.name.startsWith("Classic"));
    assert.equal(schemes.length, 20);
    for (const scheme of schemes) {
        const id = scheme.name.toLowerCase().replace(" #", "-").replaceAll(" ", "-");
        const choice = memphis.appearances.find((a) => a.id === id);
        const palette = kit.memphis[id].off;
        assert.equal(A.pattern(memphis, choice.mode, false, id), "", id + ": no tile");
        assert.equal(A.background(memphis, choice.mode, false, id, palette), scheme.colors.Desktop, id + ": JSON Desktop colour");
        assert.equal(A.background(memphis, choice.mode, true, id, palette), scheme.colors.Desktop, id + ": Extra dark ignored");
    }
}
// The five appearances draw five different tiles.
const five = [["platinum", "light", false], ["platinum", "dark", false], ["platinum", "dark", true],
              ["memphis", "light", false], ["memphis", "dark", true]].map(([t, m, e]) => A.pattern(find(t), m, e));
assert.equal(new Set(five).size, 5);
assert.equal(A.pattern(memphis, "dark", true), A.pattern(memphis, "dark", false));
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
