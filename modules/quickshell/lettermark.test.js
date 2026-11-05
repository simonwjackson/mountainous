// lettermark.js: when an icon needs a lettermark, which letter and tint,
// and the tile's art in both themes.
// Run: node lettermark.test.js [lettermark.js]
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const L = {};
const source = process.argv[2] || __dirname + "/lettermark.js";
vm.runInNewContext(fs.readFileSync(source, "utf8").replace(/^\.pragma library\s*$/m, ""), L);

// ---- needs()
const own = "/run/current-system/sw/share/icons/Mountainous-platinum/32x32/apps/zed.png";
assert.equal(L.needs("zed", own), false);
assert.equal(L.needs("zed", "file://" + own), false);
assert.equal(L.needs("zed", own, "platinum"), false);
// Chicago95 is Memphis's own set, not Platinum's.
const c95 = "/nix/store/x-desktop-art/share/icons/Chicago95/apps/32/chromium.png";
assert.equal(L.needs("chromium", c95, "win98"), false);
assert.equal(L.needs("chromium", c95, "platinum"), true);
assert.equal(L.needs("chromium", c95), false);
// hicolor, Adwaita and an app's own file are not period art.
assert.equal(L.needs("krita", "/run/current-system/sw/share/icons/hicolor/32x32/apps/krita.png"), true);
assert.equal(L.needs("folder", "/run/current-system/sw/share/icons/Adwaita/32x32/places/folder.png"), true);
assert.equal(L.needs("app", "/opt/app/share/pixmaps/app.png"), true);
assert.equal(L.needs("app", "/home/simon/.local/share/icons/hicolor/48x48/apps/app.png"), true);
// No name, no file, or a pixmap (an SNI icon without a name).
assert.equal(L.needs("", own), true);
assert.equal(L.needs("zed", ""), true);
assert.equal(L.needs(null, undefined), true);
assert.equal(L.needs("nm-applet", "image://qsimage/1234/0"), true);
// Escaped paths decode.
assert.equal(L.needs("x", "file:///usr/share/icons/Mountainous-win98/apps/32/x%20y.png", "win98"), false);

// ---- mark(): the letter
assert.equal(L.mark("platinum", "Krita", "org.kde.krita").letter, "K");
assert.equal(L.mark("platinum", "  zed editor", "dev.zed.Zed").letter, "Z");
assert.equal(L.mark("win98", "3D Pinball", "pinball").letter, "3");
assert.equal(L.mark("win98", "(beta) Tool", "tool").letter, "B");
assert.equal(L.mark("win98", "", "org.signal.Signal").letter, "O");
assert.equal(L.mark("win98", "—", "").letter, "?");
assert.equal(L.mark("platinum", "", "").letter, "?");
assert.equal(L.mark("platinum", "élan", "x").letter, "É");
assert.equal(L.mark("platinum", "Ωmega", "x").letter, "Ω");

// ---- mark(): the tint is the id's, in the theme's palette
const a = L.mark("platinum", "Krita", "org.kde.krita");
const b = L.mark("platinum", "Krita (renamed)", "org.kde.krita");
assert.equal(a.fill, b.fill, "the tint follows the id, not the label");
assert.ok(L.TINTS.platinum.indexOf(a.fill) >= 0);
assert.ok(L.TINTS.win98.indexOf(L.mark("win98", "Krita", "org.kde.krita").fill) >= 0);
const fills = new Set(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"].map((id) => L.mark("platinum", id, id).fill));
assert.ok(fills.size >= 4, "ids spread over the palette: " + fills.size);
for (const theme of ["platinum", "win98"]) {
    const m = L.mark(theme, "A", "a");
    assert.equal(m.ink, "#ffffff");
    assert.equal(m.edge, "#000000");
}
// White ink stays legible on every tint (contrast >= 4:1).
function lum(h) {
    const c = [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255).map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}
for (const t of L.TINTS.platinum.concat(L.TINTS.win98))
    assert.ok(1.05 / (lum(t) + 0.05) >= 4, t + " is too light for white ink");
// Unknown themes draw Platinum.
assert.deepEqual(L.mark("nope", "A", "a"), L.mark("platinum", "A", "a"));
// A provider-given tint (IconArt::Lettermark) gets the same colours.
assert.equal(L.colours("platinum", "#3a6ea5").fill, "#3a6ea5");
assert.equal(L.colours("platinum", "#3a6ea5").light, "#92afcd");
assert.equal(L.colours("win98", "bogus").fill, "#808080");

// ---- art()
assert.equal(L.gridFor("platinum", 16), 32);
assert.equal(L.gridFor("win98", 16), 16);
assert.equal(L.gridFor("win98", 24), 16);
assert.equal(L.gridFor("win98", 32), 32);
function grid(art) {
    const g = Array.from({ length: art.grid }, () => Array(art.grid).fill(null));
    for (const r of art.rects) {
        assert.ok(r.x >= 0 && r.y >= 0 && r.x + r.w <= art.grid && r.y + r.h <= art.grid, JSON.stringify(r));
        for (let y = r.y; y < r.y + r.h; y++) for (let x = r.x; x < r.x + r.w; x++) {
            assert.equal(g[y][x], null, "rects overlap at " + x + "," + y);
            g[y][x] = r.color;
        }
    }
    return g;
}
const pc = L.colours("platinum", "#3a6ea5");
const p = grid(L.art("platinum", pc, 32));
// The cube: black outline round the front face, the face, the highlight,
// the top and side faces, the shadow, and nothing in the far corners.
assert.equal(p[12][3], "#000000");
assert.equal(p[27][18], "#000000");
assert.equal(p[20][10], pc.fill);
assert.equal(p[13][8], pc.shade);
assert.equal(p[8][14], pc.light);
assert.equal(p[16][21], pc.dark);
assert.equal(p[29][21], "#50000000");
assert.equal(p[0][0], null);
assert.equal(p[31][0], null);
const wc = L.colours("win98", "#000080");
for (const n of [16, 32]) {
    const art = L.art("win98", wc, n);
    const w = grid(art);
    const lo = n === 16 ? 1 : 2, hi = n - 1 - lo;
    assert.equal(art.grid, n);
    assert.equal(w[lo][lo], "#ffffff", "raised: light top left");
    assert.equal(w[hi][hi], "#000000", "dark bottom right");
    assert.equal(w[hi - 1][lo + 3], "#808080", "inner shadow");
    assert.equal(w[(n / 2) | 0][(n / 2) | 0], "#000080");
    assert.equal(w[0][0], null);
    assert.equal(art.text, 12 * n / 16);
}
// Few rectangles: vertical runs merge.
assert.ok(L.art("win98", wc, 32).rects.length < 20);
assert.ok(L.art("platinum", pc, 32).rects.length < 120);

console.log("LETTERMARK_TESTS_PASSED");
