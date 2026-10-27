// page-names.js: pages named by their apps, never by number.
// Run: node page-names.test.js page-names.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const P = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/page-names.js", "utf8")
    .replace(/^\.pragma library\s*$/m, ""), P);
const plain = (v) => JSON.parse(JSON.stringify(v));
const NUMBER = /\bpage\s*\d/i;

// ---- listNames: the text a divider's tooltip or label uses.
assert.equal(P.listNames([]), "");
assert.equal(P.listNames(undefined), "");
assert.equal(P.listNames(["Signal"]), "Signal");
assert.equal(P.listNames(["Signal", "Zed"]), "Signal and Zed");
assert.equal(P.listNames(["Signal", "Zed", "Ghostty"]), "Signal, Zed and Ghostty");
assert.equal(P.listNames(["Signal", "Zed", "Ghostty", "Chromium"]), "Signal, Zed, Ghostty…");
assert.equal(P.listNames(["Signal", "Zed", "Ghostty", "Chromium", "Pyxamp"]), "Signal, Zed, Ghostty…");
// Twice the same app is one name; blanks drop out; order is first seen.
assert.equal(P.listNames(["Ghostty", "Zed", "Ghostty", "", null, " "]), "Ghostty and Zed");
assert.equal(P.listNames(["Ghostty", "Ghostty", "Ghostty", "Ghostty"]), "Ghostty");
// A long name with no break points is kept whole; the view truncates it.
const long = "Supercalifragilisticexpialidocious-Workbench";
assert.equal(P.listNames([long, "Zed"]), long + " and Zed");

// ---- beside and moveBeside: the same text, one word in front.
assert.equal(P.beside(["Signal"]), "Beside Signal");
assert.equal(P.beside(["Signal", "Zed"]), "Beside Signal and Zed");
assert.equal(P.beside(["Signal", "Zed", "Ghostty"]), "Beside Signal, Zed and Ghostty");
assert.equal(P.beside(["Signal", "Zed", "Ghostty", "Chromium"]), "Beside Signal, Zed, Ghostty…");
assert.equal(P.beside([]), "");
assert.equal(P.moveBeside(["Signal", "Zed"]), "Move beside Signal and Zed");
assert.equal(P.moveBeside([]), "Move to an empty page");
for (const n of [[], ["A"], ["A", "B"], ["A", "B", "C"], ["A", "B", "C", "D"]])
    assert.equal(P.beside(n), n.length ? "Beside " + P.listNames(n) : "", "beside is listNames with a word in front");

// ---- namesOn
const lane = [
    { page: 1, name: "Ghostty", address: "a" }, { page: 1, name: "Chromium", address: "b" },
    { page: 3, name: "Signal", address: "c" }, { page: 3, name: "Zed", address: "d" },
    { page: 4, name: "GitHub", address: "e" },
    { page: 6, name: "Pyxamp", address: "f" }, { page: 6, name: "Zed", address: "g" },
    { page: 6, name: "Ghostty", address: "h" }, { page: 6, name: "Signal", address: "i" },
];
assert.deepEqual(plain(P.namesOn(lane, 1)), ["Ghostty", "Chromium"]);
assert.deepEqual(plain(P.namesOn(lane, 1, "a")), ["Chromium"]);
assert.deepEqual(plain(P.namesOn(lane, 9)), []);

// ---- movePages: GitHub, alone on page 4, while the screen shows page 1.
let mv = P.movePages(lane, "e", 4, 1, [1, 3, 4, 6, 7]);
assert.deepEqual(plain(mv.pages), [
    { page: 1, current: false, label: "Beside Ghostty and Chromium" },
    { page: 3, current: false, label: "Beside Signal and Zed" },
    { page: 4, current: true, label: "On its own" },
    { page: 6, current: false, label: "Beside Pyxamp, Zed, Ghostty…" }]);
assert.equal(mv.newPage, 8, "after every page on every screen");
assert.equal(P.NEW_PAGE, "New page");
// Signal on page 3: its own page names the others, checked.
mv = P.movePages(lane, "c", 3, 3, []);
assert.deepEqual(plain(mv.pages.find((p) => p.current)), { page: 3, current: true, label: "Beside Zed" });
assert.equal(mv.newPage, 7);
// The screen shows an empty page: it is listed, and reads "Empty page".
mv = P.movePages(lane, "a", 1, 5, [1, 3, 4, 5, 6]);
assert.deepEqual(plain(mv.pages.find((p) => p.page === 5)), { page: 5, current: false, label: "Empty page" });
// No windows at all: the own page alone, then a new one.
mv = P.movePages([], "x", 2, 2, [2]);
assert.deepEqual(plain(mv.pages), [{ page: 2, current: true, label: "On its own" }]);
assert.equal(mv.newPage, 3);
// Between pages (-1): nothing is checked.
mv = P.movePages(lane, "e", -1, 1, []);
assert.equal(mv.pages.some((p) => p.current), false);

// No label this file makes ever names a page by number.
for (const ids of [[1, 3, 4, 6], [12, 40]]) {
    const m = P.movePages(lane.map((w, i) => Object.assign({}, w, { page: ids[i % ids.length] })), "a", ids[0], ids[1], ids);
    for (const p of m.pages) assert.doesNotMatch(p.label, NUMBER, p.label);
}
assert.doesNotMatch(P.NEW_PAGE + " " + P.moveBeside([]), NUMBER);

console.log("page-names: ok");
