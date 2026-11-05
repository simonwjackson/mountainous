// sni-tray.js: which StatusNotifierItems show and in what order, their
// keys, what a press does, and dbusmenu labels; and the lettermark
// shared lettermark contract (lettermark.js).
// Run: node sni-tray.test.js sni-tray.js lettermark.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const load = (file) => {
    const ctx = {};
    vm.runInNewContext(fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, ""), ctx);
    return ctx;
};
const T = load(process.argv[2] || path.join(__dirname, "sni-tray.js"));
const L = load(process.argv[3] || path.join(__dirname, "lettermark.js"));
const plain = (v) => JSON.parse(JSON.stringify(v));

const item = (id, extra) => Object.assign({ id, title: id, status: "Active", iconSource: "image://icon/" + id + "?fallback=x&theme=T",
    tooltipTitle: "", tooltipDescription: "", hasMenu: true, onlyMenu: false }, extra || {});

// ---- order: registration order, Passive hidden, status never reorders
let r = T.rows([item("nm-applet"), item("steam", { status: "Passive" }), item("hensou-files", { status: "NeedsAttention", tooltipTitle: "Files", tooltipDescription: "Copying 3 items" }),
    item("telegram")]);
assert.deepEqual(plain(r.map((x) => x.key)), ["sni:nm-applet", "sni:hensou-files", "sni:telegram"]);
assert.deepEqual(plain(r.map((x) => x.index)), [0, 2, 3], "index points back at the owner's item");
assert.equal(r[1].attention, true);
assert.equal(r[1].label, "Files");
assert.equal(r[1].tooltip, "Files\nCopying 3 items");
assert.equal(r[0].iconName, "nm-applet");

// ---- keys: stable, unique, safe
r = T.rows([item("a b/c"), item("a b/c"), item(""), item("x", { iconSource: "image://qsimage/123" })]);
assert.deepEqual(plain(r.map((x) => x.key)), ["sni:a_b_c", "sni:a_b_c#2", "sni:item", "sni:x"]);
assert.equal(r[3].iconName, "", "a pixmap has no theme name");
assert.equal(T.isKey("sni:x"), true);
assert.equal(T.isKey("vol"), false);
assert.equal(T.iconName("image://icon/org.kde%20x?fallback=y"), "org.kde x");
assert.equal(T.iconName("file:///a/b.png"), "");
assert.deepEqual(plain(T.rows(null)), []);

// ---- labels: tooltip title, title, id; markup stripped
assert.equal(T.label({ id: "i", title: "", tooltipTitle: "<b>Up &amp; down</b>" }), "Up & down");
assert.equal(T.label({ id: "i", title: "T" }), "T");
assert.equal(T.label({ id: "i" }), "i");
assert.equal(T.tooltip({ id: "i", tooltipTitle: "Same", tooltipDescription: "Same" }), "Same");

// ---- presses
const row = (hasMenu, onlyMenu) => T.rows([item("z", { hasMenu, onlyMenu })])[0];
assert.equal(T.press(row(true, false), "left"), "activate");
assert.equal(T.press(row(true, true), "left"), "menu", "an item that is only a menu opens it");
assert.equal(T.press(row(false, true), "left"), "activate", "onlyMenu without a menu still activates");
assert.equal(T.press(row(true, false), "middle"), "secondary");
assert.equal(T.press(row(true, false), "right"), "menu");
assert.equal(T.press(row(false, false), "right"), "activate");
assert.equal(T.press(null, "left"), "none");
assert.equal(T.overflowChoice(row(true, false)), "menu");
assert.equal(T.overflowChoice(row(false, false)), "activate");

// ---- dbusmenu labels
assert.equal(T.accessText("_File"), "&File");
assert.equal(T.accessText("Save _As__x"), "Save &As_x");
assert.equal(T.accessText("R&D"), "R&&D");
assert.equal(T.accessText("trailing_"), "trailing");
assert.equal(T.plainText("Save _As__x"), "Save As_x");
assert.deepEqual(plain(T.tidy([{ separator: true }, { text: "a" }, { separator: true }, { separator: true }, { text: "b" }, { separator: true }, null])),
    [{ text: "a" }, { separator: true }, { text: "b" }]);

// ---- the shared lettermark keeps the agreed API
assert.equal(L.needs("", "/x/icons/Chicago95/16/apps/a.png", "win98"), true, "no name");
assert.equal(L.needs("a", "", "win98"), true, "not found");
assert.equal(L.needs("a", "image://qsimage/1", "win98"), true, "a pixmap");
assert.equal(L.needs("a", "/run/current-system/sw/share/icons/hicolor/16x16/apps/a.png", "win98"), true, "hicolor only");
assert.equal(L.needs("a", "/run/current-system/sw/share/icons/Chicago95/16/apps/a.png", "win98"), false);
assert.equal(L.needs("a", "file:///s/icons/Mountainous-platinum/32/apps/a.png", "platinum"), false);
assert.equal(L.needs("a", "/s/icons/Chicago95/16/apps/a.png", "platinum"), true, "Memphis art is not Platinum art");
assert.equal(L.needs("a", "/s/icons/Chicago95/16/apps/a.png"), false, "no theme: both sets count");
const m = plain(L.mark("win98", "Hensou Files", "hensou-files"));
assert.deepEqual(Object.keys(m).sort(), ["dark", "edge", "fill", "ink", "letter", "light", "shade"]);
assert.equal(m.letter, "H");
assert.deepEqual(plain(L.mark("win98", "Hensou Files", "hensou-files")), m, "the same app, the same tile");
assert.equal(L.mark("platinum", "", "9lives").letter, "9");
assert.equal(L.mark("platinum", "", "").letter, "?");

console.log("sni-tray: order, keys, labels, presses, dbusmenu labels and the lettermark contract pass");
