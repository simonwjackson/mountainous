// No workspace numbers are shown in either theme (docs/plans/desktop-themes.md,
// "No workspace numbers"). Simon: "I don't ever want to see the number of a
// workspace." Two cheap halves:
//
//   1. The models: every label, hint and detail that find-model.js,
//      menu-models.js, strip-plan.js and page-names.js render, for a fixture
//      of many windows across pages and two screens, in every scope.
//   2. The sources: no shipped QML or JS builds a label from "page " and a
//      number. PENDING lists the files another worker still owns; a listed
//      file that is clean fails too, so the list stays true.
//
//   node no-page-numbers.test.js <quickshell dir>
"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const dir = process.argv[2] || path.join(__dirname, "..");
const NUMBER = /\bpage\s*\d/i;
const lib = (rel) => fs.readFileSync(path.join(dir, rel), "utf8").replace(/^\.pragma library\s*$/m, "");
const load = (rel, ctx) => { const c = ctx || {}; vm.runInNewContext(lib(rel).replace(/^\.import .*$/gm, ""), c); return c; };

// ---------------------------------------------------------------- 1. the models
const F = load("find-model.js");
const PageNames = load("page-names.js");
const S = load("themes/platinum/strip-plan.js", { PageNames });
const M = load("themes/platinum/menu-models.js");

const apps = ["com.mitchellh.ghostty", "signal", "dev.zed.Zed", "chrome-github.com__-Default", "firefox", "obsidian"];
const names = { "com.mitchellh.ghostty": "Ghostty", signal: "Signal", "dev.zed.Zed": "Zed",
    "chrome-github.com__-Default": "GitHub", firefox: "Firefox", obsidian: "Obsidian" };
const windows = [];
for (let i = 0; i < 48; i++) {
    const page = 1 + (i % 12), screen = page > 9 ? "SUNSHINE" : "eDP-1";
    windows.push({ address: "w" + i, appId: apps[i % apps.length], title: i === 7 ? "page 3 notes" : "Window " + i,
        page, screen, shown: page === 1 || page === 10, workspace: String(page), x: i * 10, y: 0 });
}
const seen = [];
const look = (where, text) => { if (typeof text === "string" && text !== "") seen.push([where, text]); };
const screenLabel = (s) => (s === "SUNSHINE" ? "tablet" : "laptop");

// Find rows, every scope and query.
const ctx = { here: "eDP-1", screenLabel,
    windows: windows.map((w, i) => ({ label: w.title, page: w.page, shown: w.shown, screen: w.screen, order: i, appId: w.appId, icon: w.appId, ref: w })),
    apps: [], recent: [], commands: [] };
for (const scope of ["all", "app", "win", "cmd"])
    for (const q of ["", "w", "1", "3", "tablet", "page"])
        for (const r of F.findRows(scope, q, ctx)) {
            // A window's own title may say anything; only what the model adds counts.
            if (!(r.k === "win" && r.label === (r.ref && r.ref.title))) look("find " + scope + " " + q, r.label);
            look("find " + scope + " " + q, r.hint);
        }

// The Application menu, every app's window submenu.
const byApp = {};
for (const w of windows) (byApp[w.appId] = byApp[w.appId] || []).push(w);
const appRows = Object.keys(byApp).map((id) => ({ appId: id, name: names[id], icon: id, count: byApp[id].length, front: false,
    hidden: false, windows: byApp[id] }));
const walk = (where, rows) => { for (const r of rows || []) { look(where, r.label === undefined ? "" : r.label); look(where, r.hint); look(where, r.detail); walk(where, r.submenu); } };
const stripWindowTitles = (rows) => (rows || []).map((r) => Object.assign({}, r, { label: windows.some((w) => w.title === r.label) ? "" : r.label,
    submenu: r.submenu ? stripWindowTitles(r.submenu) : r.submenu }));
walk("application", stripWindowTitles(M.application({ apps: appRows, here: "eDP-1", screenLabel })));

// Each tile's menu with Move to page, and every drag label on one screen.
const lane = S.order(windows.filter((w) => w.screen === "eDP-1"));
const pageIds = [...new Set(windows.map((w) => w.page))];
for (const w of lane) {
    const move = S.movePages(lane, w.address, w.page, 1, pageIds, names);
    const t = M.tile({ window: w, appName: names[w.appId], appIcon: w.appId, front: false, shown: w.shown, move });
    walk("tile", t.slice(1));
    look("tile header", t[0].detail);
}
for (let a = 0; a < lane.length; a += 5) for (let b = 0; b < lane.length; b += 3) look("drag", S.drop(lane, a, b, names).label);
for (let n = 0; n < 6; n++) { const l = apps.slice(0, n).map((id) => names[id]); look("names", PageNames.listNames(l)); look("names", PageNames.beside(l)); }

assert.ok(seen.length > 400, "the sweep rendered " + seen.length + " strings");
const bad = seen.filter(([, text]) => NUMBER.test(text));
assert.deepEqual(bad, [], "a rendered label shows a page number");

// ---------------------------------------------------------------- 2. the sources
// Owned by win98-taskbar-session (the taskbar, Move to Page, Start ▸ Windows,
// Alt+Tab). Remove a line when that work lands; a clean listed file fails.
const PENDING = new Set([]);
// A string that ends in "page " or "Page " and is followed by + or ${}:
// a page number about to be shown.
const BUILD = /(["'`])[^"'`\n]*\b[Pp]age \1\s*\+|`[^`\n]*\b[Pp]age \$\{/;
function files(d, rel) {
    let out = [];
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
        const r = rel ? rel + "/" + e.name : e.name;
        if (e.isDirectory()) { if (e.name !== "theme-dev" && e.name !== "dev" && e.name !== "node_modules") out = out.concat(files(path.join(d, e.name), r)); }
        else if (/\.(qml|js)$/.test(e.name) && !/\.test\.js$/.test(e.name)) out.push(r);
    }
    return out;
}
const offenders = [];
for (const rel of files(dir, "")) {
    const lines = fs.readFileSync(path.join(dir, rel), "utf8").split("\n");
    const hits = lines.map((l, i) => [i + 1, l]).filter(([, l]) => BUILD.test(l) && !/^\s*\/\//.test(l));
    if (PENDING.has(rel)) {
        assert.ok(hits.length > 0, rel + " no longer builds a page number: remove it from PENDING");
        continue;
    }
    for (const [n, l] of hits) offenders.push(rel + ":" + n + ": " + l.trim());
}
assert.deepEqual(offenders, [], "a shipped file builds a page-number label");
// ---------------------------------------------------------------- 3. the dividers
// A page is never a control, so it has nothing to number: the Win98
// taskbar's divider is a groove with no head (no place, no tooltip, no
// keyboard stop, no click), and the Control Strip's page slot is a groove.
const src = (rel) => fs.readFileSync(path.join(dir, rel), "utf8");
const P = load("themes/win98/taskbar-plan.js");
assert.equal(P.TAG, undefined, "the taskbar plan has no page head");
const tp = P.plan(1440, { windows: [{ page: 1, focused: true }, { page: 2 }, { page: 5 }], showingPage: 1,
    tray: [], clock: { time: "4:51", ampm: "PM" }, dict: { visible: false }, measure: (t) => String(t).length * 6 });
assert.equal(JSON.stringify(tp.groups.map((g) => [g.divider, g.head])), "[[false,3],[true,5],[true,5]]", "dividers are a groove and a gap");
for (const rel of ["Win98Taskbar.qml", "Win98MenuHost.qml", "Win98Desktop.qml"]) {
    const text = src(rel);
    assert.ok(!/["']page["']\s*\+/.test(text), rel + " builds no page control id");
    assert.ok(!/showPage/.test(text), rel + " has no page click");
}
const slots = S.slots(S.order(windows.filter((w) => w.screen === "eDP-1")));
assert.ok(slots.slots.filter((x) => x.kind !== "tile").every((x) => x.kind === "groove"), "the Control Strip's page slots are grooves");

console.log("NO_PAGE_NUMBERS_PASSED strings=" + seen.length + " pending=" + PENDING.size);
