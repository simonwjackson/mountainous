// find-model.js: the Find menu's rows, ranking, scopes, the empty and
// no-results states, the recent list, the launch kind, and the caller rule.
// Run: node find-model.test.js find-model.js [OmniBar.qml] [launcher-model.js] [Launcher.qml]
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const load = (file) => {
    const ctx = {};
    vm.runInNewContext(fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, ""), ctx);
    return ctx;
};
const F = load(process.argv[2] || path.join(__dirname, "find-model.js"));
const plain = (v) => JSON.parse(JSON.stringify(v));
const shape = (rows) => rows.map((r) => r.t === "sep" ? "—" : r.t === "head" ? "# " + r.label : r.label);
const items = (rows) => rows.filter((r) => r.t === "item");

// ---------------------------------------------------------------- fixtures
// OmniBar.windowRows order: the focused screen first, most recent first.
// shown: the window's page is the one its screen shows (laptop: page 1,
// tablet: page 3).
const SHOWN = { "eDP-1": 1, SUNSHINE: 3 };
const W = (label, page, screen, order, appId) => ({ label, page, shown: SHOWN[screen] === page, screen, order, appId, icon: appId, ref: { label } });
const windows = [
    W("~/code/mountainous — nvim modules/quickshell/OmniBar.qml", 1, "eDP-1", 1, "com.mitchellh.ghostty"),
    W("find-mock · Forgerie", 2, "eDP-1", 2, "chrome-forgerie.hummingbird-lake.ts.net__-Default"),
    W("Pull requests · simonwjackson/mountainous", 2, "eDP-1", 3, "chrome-github.com__-Default"),
    W("btop", 1, "eDP-1", 9, "com.mitchellh.ghostty"),
    W("Desktop themes - Vault - Obsidian", 3, "SUNSHINE", 4, "obsidian"),
    W("YouTube Music", 3, "SUNSHINE", 6, "chrome-music.youtube.com__-Default"),
    W("", 3, "SUNSHINE", 8, "mpv"),
];
const A = (label, id, generic) => ({ label, id, generic, icon: id, ref: { label, entry: { id } } });
const apps = [
    A("Advanced Network Configuration", "nm-connection-editor", "Manage and change your network connection settings"),
    A("Chromium", "chromium-browser", "Web Browser"),
    A("Firefox", "firefox", "Web Browser"),
    A("Forgerie", "webapp-forgerie", ""),
    A("Ghostty", "com.mitchellh.ghostty", "Terminal emulator"),
    A("Moonlight", "com.moonlight_stream.Moonlight", "Stream games from your PC"),
    A("YouTube Music", "webapp-youtube-music", ""),
];
const recent = [
    { id: "webapp-youtube-music", name: "YouTube Music", icon: "webapp-youtube-music", kind: "webapp", argv: ["web-app", "https://music.youtube.com"] },
    { id: "com.mitchellh.ghostty", name: "Ghostty", icon: "com.mitchellh.ghostty", kind: "app", argv: ["ghostty"] },
    { id: "webapp-forgerie", name: "Forgerie", icon: "webapp-forgerie", kind: "webapp", argv: ["web-app", "https://forgerie"] },
    { id: "gimp", name: "GNU Image Manipulation Program", icon: "gimp", kind: "app", argv: ["gimp"] },
    { id: "mpv", name: "mpv Media Player", icon: "mpv", kind: "app", argv: ["mpv"] },
    { id: "signal", name: "Signal", icon: "signal", kind: "app", argv: ["signal"] },
];
// OmniBar.commandRows, as written.
const commands = [
    ["New terminal", "Super+N", "term"], ["Go to address", "Ctrl+L", "mode:nav"], ["Go to window", "mode", "mode:window"],
    ["Close window", "Super+C", "close"], ["Monocle", "Super+M", "monocle"], ["Zen", "Super+Shift+M", "zen"],
    ["Mirror workspace", "Super+Shift+G", "mirror"], ["Even / golden split", "Super+G", "split"],
    ["Interface scale up", "Super+=", "scaleup"], ["Interface scale down", "Super+-", "scaledown"],
    ["Interface scale 100%", "Super+0", "scalereset"], ["Toggle bars", "Super+I", "chrome"],
    ["Dark appearance", "Super+D", "theme:dark"], ["Light appearance", "Super+D", "theme:light"],
    ["Desktop theme…", "Appearance", "theme:picker"], ["Extra dark appearance", "dark only", "theme:extra"],
    ["Screenshot", "Super+S", "shot"],
].map(([label, detail, act]) => ({ kind: "cmd", label, detail, act }));
const screenLabel = (s) => s === "SUNSHINE" ? "tablet" : s.indexOf("eDP") === 0 ? "laptop" : s;
const ctx = { windows, here: "eDP-1", screenLabel, apps, recent, commands };

// ---------------------------------------------------------------- scopes
assert.deepEqual(plain(F.SCOPES.map((s) => [s.id, s.mode, s.label, s.key])), [
    ["all", "root", "All", ""], ["app", "app", "Applications", "Ctrl+1"],
    ["win", "window", "Windows", "Ctrl+2"], ["cmd", "cmd", "Commands", "Ctrl+3"]]);
for (const s of F.SCOPES) { assert.equal(F.scopeOf(s.mode), s.id); assert.equal(F.modeOf(s.id), s.mode); }
assert.equal(F.scopeOf("nav"), "all");
assert.equal(F.modeOf("nope"), "root");

// ---------------------------------------------------------------- empty field
// Each screen's windows page by page, the page it shows first, a rule
// between pages; most recent first inside a page.
let rows = F.findRows("all", "", ctx);
assert.deepEqual(plain(shape(rows)), [
    "# Windows on laptop", "~/code/mountainous — nvim modules/quickshell/OmniBar.qml", "btop", "—",
    "find-mock · Forgerie", "Pull requests · simonwjackson/mountainous",
    "# Windows on tablet", "Desktop themes - Vault - Obsidian", "YouTube Music", "(untitled)",
    "# Recent Applications", "YouTube Music", "Ghostty", "Forgerie", "GNU Image Manipulation Program", "mpv Media Player",
    "# Commands", ...commands.map((c) => c.label),
    "—", "All Applications…"]);
// Super+P, Return: the first row Return runs is the last window.
assert.equal(rows[F.firstSelectable(rows)].k, "win");
assert.equal(rows[F.firstSelectable(rows)].ref.label, windows[0].label);
// No page number, ever. Another screen's window names the screen.
assert.equal(rows[1].hint, "");
assert.equal(rows.find((r) => r.label === "YouTube Music" && r.k === "win").hint, "tablet");
// The shown page goes first even when its window is not the most recent.
const later = windows.map((w) => Object.assign({}, w, { shown: w.screen === "eDP-1" ? w.page === 2 : w.shown }));
assert.deepEqual(plain(shape(F.findRows("win", "", Object.assign({}, ctx, { windows: later }))).slice(0, 6)), [
    "# Windows on laptop", "find-mock · Forgerie", "Pull requests · simonwjackson/mountainous", "—",
    "~/code/mountainous — nvim modules/quickshell/OmniBar.qml", "btop"]);
// Nothing shown (the screen shows an empty page): the most recent page first.
const none = windows.map((w) => Object.assign({}, w, { shown: false }));
assert.equal(F.findRows("win", "", Object.assign({}, ctx, { windows: none }))[1].label, windows[0].label);
// One page: no rule.
const onePage = windows.filter((w) => w.page === 1);
assert.ok(!F.findRows("win", "", Object.assign({}, ctx, { windows: onePage })).some((r) => r.t === "sep"));
// Recent: five at most, web apps marked, launched from their record.
const rec = items(rows).filter((r) => r.k === "recent");
assert.equal(rec.length, 5);
assert.deepEqual(plain(rec.map((r) => r.hint)), ["web app", "", "web app", "", ""]);
assert.deepEqual(plain(rec[0].entry), recent[0]);
assert.equal(rows[rows.length - 1].k, "scope");
assert.equal(rows[rows.length - 1].to, "app");
assert.equal(rows[rows.length - 1].hint, "7 items  Ctrl+1");
// Commands keep their shortcut as the hint.
assert.equal(rows.find((r) => r.label === "Zen").hint, "Super+Shift+M");

// One screen: one "Windows" heading, no screen in the hints.
const oneScreen = Object.assign({}, ctx, { windows: windows.filter((w) => w.screen === "eDP-1") });
rows = F.findRows("all", "", oneScreen);
assert.equal(rows[0].label, "Windows");
assert.equal(rows.filter((r) => r.t === "head" && /^Windows/.test(r.label)).length, 1);
assert.ok(items(rows).filter((r) => r.k === "win").every((r) => !/,/.test(r.hint)));
// No other windows: the empty field leads with the recent apps.
rows = F.findRows("all", "", Object.assign({}, ctx, { windows: [] }));
assert.equal(rows[0].label, "Recent Applications");
assert.equal(rows[F.firstSelectable(rows)].k, "recent");
// No recent launches: no empty heading.
rows = F.findRows("all", "", Object.assign({}, ctx, { recent: [] }));
assert.ok(!rows.some((r) => r.label === "Recent Applications"));

// ---------------------------------------------------------------- ranking and grouping
rows = F.findRows("all", "you", ctx);
assert.deepEqual(plain(shape(rows)), ["# Applications", "YouTube Music", "Advanced Network Configuration", "Moonlight",
    "# Windows", "YouTube Music"]);
assert.equal(rows[1].hint, "web app");
// Prefix, then word start, then inside the name, then the detail or id.
assert.equal(F.rank({ label: "YouTube Music" }, "you"), 0);
assert.equal(F.rank({ label: "Mac OS 8 - Wikipedia" }, "wiki"), 1);
assert.equal(F.rank({ label: "Moonlight" }, "light"), 2);
assert.equal(F.rank({ label: "Moonlight", generic: "Stream games from your PC" }, "your"), 3);
assert.equal(F.rank({ label: "Zen", hint: "Super+Shift+M" }, "shift"), 3);
assert.equal(F.rank({ label: "Zen" }, "qx7"), -1);
assert.equal(F.rank({ label: "Anything" }, ""), 0);
// Case does not matter; equal ranks keep the service's order.
assert.deepEqual(plain(F.filter([{ label: "b Alpha" }, { label: "alpha" }, { label: "Alphabet" }], "ALPHA").map((r) => r.label)),
    ["alpha", "Alphabet", "b Alpha"]);
// "tablet" finds every window on the tablet, by its hint; a filtered list
// keeps rank order, with no page rules.
rows = F.findRows("win", "tablet", ctx);
assert.deepEqual(plain(shape(rows)), ["Desktop themes - Vault - Obsidian", "YouTube Music", "(untitled)"]);
// A page number finds nothing: it is not shown, so it is not searched.
assert.equal(items(F.findRows("win", "page 3", ctx)).filter((r) => r.k === "win").length, 0);
// "super" finds every command whose shortcut uses Super; "web" finds the browsers by generic name...
assert.equal(items(F.findRows("cmd", "super", ctx)).length, 13);
// ...and the web apps, by their id and their "web app" hint (today: by id).
assert.deepEqual(plain(items(F.findRows("app", "web", ctx)).map((r) => r.label)), ["Chromium", "Firefox", "Forgerie", "YouTube Music"]);
// The app id still matches.
assert.deepEqual(plain(items(F.findRows("app", "mitchellh", ctx)).map((r) => r.label)), ["Ghostty"]);
// Typing searches every app, not only the recent ones.
assert.ok(items(F.findRows("all", "chrom", ctx)).some((r) => r.k === "app" && r.label === "Chromium"));
// Applications, then commands, then windows, as today.
rows = F.findRows("all", "mo", ctx);
const order = rows.filter((r) => r.t === "head").map((r) => r.label);
assert.deepEqual(plain(order), ["Applications", "Commands", "Windows"]);

// ---------------------------------------------------------------- each scope
rows = F.findRows("app", "", ctx);
assert.deepEqual(plain(rows.filter((r) => r.t === "head").map((r) => r.label)), ["Recent Applications", "All Applications"]);
assert.equal(items(rows).length, 5 + apps.length);
rows = F.findRows("win", "", ctx);
assert.deepEqual(plain(rows.filter((r) => r.t === "head").map((r) => r.label)), ["Windows on laptop", "Windows on tablet"]);
assert.equal(items(rows).length, windows.length);
rows = F.findRows("win", "", oneScreen);
assert.ok(rows.every((r) => r.t !== "head"), "a one-screen Windows scope needs no heading");
assert.deepEqual(plain(shape(rows)), ["~/code/mountainous — nvim modules/quickshell/OmniBar.qml", "btop", "—",
    "find-mock · Forgerie", "Pull requests · simonwjackson/mountainous"]);
rows = F.findRows("cmd", "", ctx);
assert.deepEqual(plain(rows.map((r) => r.label)), commands.map((c) => c.label));
assert.ok(rows.every((r) => r.k === "cmd" && r.ref && r.act));
rows = F.findRows("cmd", "scale", ctx);
assert.deepEqual(plain(rows.map((r) => r.label)), ["Interface scale up", "Interface scale down", "Interface scale 100%"]);

// ---------------------------------------------------------------- no results
rows = F.findRows("all", "qx7", ctx);
assert.deepEqual(plain(rows.map((r) => [r.k, r.label, !!r.dis])), [
    ["none", "Nothing named “qx7”", true], ["addr", "Go to Address “qx7”…", false]]);
assert.equal(rows[F.firstSelectable(rows)].k, "addr", "Return on no results opens Go to Address");
assert.equal(rows[1].text, "qx7");
rows = F.findRows("win", "qx7", ctx);
assert.deepEqual(plain(rows.map((r) => r.label)), ["Nothing named “qx7” in Windows", "Search All for “qx7”", "Go to Address “qx7”…"]);
assert.equal(rows[1].to, "all");
assert.equal(rows[1].keep, true, "Search All keeps the text");
rows = F.findRows("win", "", Object.assign({}, ctx, { windows: [] }));
assert.deepEqual(plain(rows.map((r) => [r.label, !!r.dis])), [["No other windows", true]]);
assert.equal(F.firstSelectable(rows), -1);
rows = F.findRows("all", "", { windows: [], apps: [], recent: [], commands: [] });
assert.deepEqual(plain(rows.map((r) => r.label)), ["Nothing to show"]);
// A host offers itself as an address, under the other matches.
rows = F.findRows("all", "nixos.org", ctx);
assert.deepEqual(plain(shape(rows)), ["Go to “nixos.org”"], "a host alone needs no rule above it");
rows = F.findRows("all", "github.com", ctx);
assert.equal(rows[rows.length - 1].label, "Go to “github.com”");
assert.equal(rows[rows.length - 2].t, "sep");
assert.ok(F.looksLikeAddress("https://x"));
assert.ok(F.looksLikeAddress("nixos.org"));
assert.ok(!F.looksLikeAddress("page 3"));
assert.ok(F.isBareWords("mac os 8"));
assert.ok(!F.isBareWords("nixos.org"));
assert.ok(!F.isBareWords("https://en.wikipedia.org/wiki/Mac_OS_8"));
assert.ok(!F.isBareWords(""));

// ---------------------------------------------------------------- the launch kind
assert.equal(F.launchKind("webapp-youtube-music"), "webapp");
assert.equal(F.launchKind("com.mitchellh.ghostty"), "app");
assert.equal(F.launchKind(""), "app");
assert.equal(F.launchKind(undefined), "app");
rows = items(F.findRows("app", "", ctx)).filter((r) => r.k === "app");
assert.deepEqual(plain(rows.map((r) => [r.label, r.kind, r.hint])), [
    ["Advanced Network Configuration", "app", ""], ["Chromium", "app", ""], ["Firefox", "app", ""],
    ["Forgerie", "webapp", "web app"], ["Ghostty", "app", ""], ["Moonlight", "app", ""], ["YouTube Music", "webapp", "web app"]]);
assert.deepEqual(plain(items(F.findRows("all", "", ctx)).filter((r) => r.k === "recent").map((r) => r.kind)),
    ["webapp", "app", "webapp", "app", "app"]);

// ---------------------------------------------------------------- selection and scrolling
rows = F.findRows("all", "", ctx);
const first = F.firstSelectable(rows);
assert.equal(first, 1);
assert.equal(F.step(rows, first, -1), rows.length - 1, "Up from the first row wraps to the last");
assert.equal(F.step(rows, rows.length - 1, 1), first, "Down from the last row wraps to the first");
assert.equal(F.step(rows, 5, 1), 7, "Down skips a heading");
assert.equal(F.step(rows, 2, 1), 4, "Down skips a page rule");
assert.equal(F.page(rows, first, 1, 10) > first, true);
assert.equal(F.page(rows, first, -1, 10), first, "PageUp stops at the top");
assert.equal(F.step([], 0, 1), -1);
assert.equal(F.contentHeight([{ t: "head" }, { t: "item" }, { t: "sep" }]), 20 + 24 + 9);
// A long list: the highlight is kept whole between the arrow bands.
const long = [];
for (let i = 0; i < 60; i++) long.push({ t: "item", k: "win", label: "w" + i });
const view = 240, band = 16;
let s = 0;
for (let i = 0; i < 60; i++) {
    s = F.scrollFor(long, i, s, view, band);
    const top = F.rowTop(long, i), bottom = top + 24, max = 60 * 24 - view;
    assert.ok(top >= s + (s > 0 ? band : 0) - 0.01, "row " + i + " below the top band");
    assert.ok(bottom <= s + view - (s < max ? band : 0) + 0.01, "row " + i + " above the bottom band");
}
assert.equal(F.scrollFor(long, 0, 500, view, band), 0, "back to the first row unscrolls");
assert.equal(F.scrollFor(long.slice(0, 5), 4, 0, view, band), 0, "a list that fits never scrolls");

// ---------------------------------------------------------------- the caller (bug: it was set only on Ctrl+L)
const A1 = { title: "Mac OS 8 - Wikipedia" }, B1 = { title: "btop" };
let st = F.close({});
// Each entry point from closed captures the window that had focus.
for (const mode of ["root", "window", "app", "cmd", "nav"]) {
    const next = F.enter(st, mode, A1);
    assert.equal(next.caller, A1, mode + " captures the caller");
    assert.equal(next.shown, true);
    assert.equal(next.mode, mode);
    assert.equal(next.query, "");
}
// Super+P on window B after a Ctrl+L on window A: Go to Address targets B.
st = F.enter(F.close({}), "nav", A1);          // Ctrl+L on A
st = F.close(st);                               // Esc
st = F.enter(st, "root", B1);                   // Super+P on B
st = F.enter(st, "nav", null, "");              // the "Go to address" row; the menu has the keyboard now
assert.equal(st.caller, B1, "Go to Address targets the window Super+P was pressed on");
// Moving between scopes keeps it; Esc keeps it while the menu stays; closing drops it.
st = F.enter(st, "window", null);
assert.equal(st.caller, B1);
st = F.back(st);
assert.deepEqual(plain(st), { shown: true, mode: "root", query: "", caller: B1 });
st = F.back(st);
assert.deepEqual(plain(st), { shown: false, mode: "root", query: "", caller: null });
// No focused window: no caller (Go opens a new window).
assert.equal(F.enter(F.close({}), "nav", null).caller, null);
// A query passes through (Go to Address “qx7”…).
assert.equal(F.enter(F.enter({}, "root", A1), "nav", null, "qx7").query, "qx7");

// ---------------------------------------------------------------- Go to Address
const pages = [
    { url: "https://en.wikipedia.org/wiki/Mac_OS_8", title: "Mac OS 8 - Wikipedia", host: "en.wikipedia.org" },
    { url: "https://github.com/simonwjackson/mountainous/pulls", title: "Pull requests", host: "github.com" },
];
assert.equal(F.addressPages(pages, "", "").length, 2);
assert.equal(F.addressPages(pages, pages[0].url, pages[0].url).length, 2, "the prefilled URL lists every page");
assert.deepEqual(plain(F.addressPages(pages, "pull", pages[0].url).map((p) => p.host)), ["github.com"]);
assert.deepEqual(plain(F.addressPages(pages, "WIKI", "")).length, 1);
assert.deepEqual(plain(F.destination({ title: "Mac OS 8 - Wikipedia", appName: "Wikipedia" }, pages[0])),
    { here: true, text: "Opens in this window:", title: "Mac OS 8 - Wikipedia" });
assert.deepEqual(plain(F.destination({ title: "btop", appName: "Ghostty" }, null)),
    { here: false, text: "Opens in a new window (Ghostty has no address)", title: "" });
assert.equal(F.destination(null, null).text, "Opens in a new window");

// ---------------------------------------------------------------- the service uses these rules
const omniFile = process.argv[3];
if (omniFile) {
    const src = fs.readFileSync(omniFile, "utf8");
    const body = (name) => {
        const at = src.indexOf("function " + name + "(");
        assert.ok(at >= 0, "OmniBar." + name + " exists");
        let depth = 0, i = src.indexOf("{", at);
        const start = i;
        for (; i < src.length; i++) { if (src[i] === "{") depth++; else if (src[i] === "}" && --depth === 0) break; }
        return src.slice(start, i + 1);
    };
    // Every way in captures the caller through FindModel.enter with the active window.
    for (const fn of ["enterRoot", "enterMode", "enterNavigate"]) {
        const b = body(fn);
        assert.match(b, /FindModel\.enter\(root\.state, [^,]+, root\.activeWindow\(\)/, fn + " captures the caller");
        assert.doesNotMatch(b, /root\.caller\s*=/, fn + " must not set caller by hand");
    }
    assert.doesNotMatch(src, /if \(!root\.shown\) root\.caller/, "the Ctrl+L-only capture is gone");
    // The IPC names other code calls are unchanged.
    for (const verb of ["toggle", "reveal", "gotowindow", "apps", "navigate", "dismiss"])
        assert.match(src, new RegExp("function " + verb + "\\(\\): void"), "omni " + verb);
    assert.match(src, /target: "omni"/);
    // A window row's detail is never its page number; it carries shown.
    const wr = src.slice(src.indexOf("readonly property var windowRows"), src.indexOf("readonly property var appRows"));
    assert.doesNotMatch(wr, /detail:\s*"page /, "OmniBar window rows show no page number");
    assert.match(wr, /shown: Lanes\.isShown\(t\)/, "OmniBar window rows say which page is showing");
    // Web apps launched from the menu are recorded as web apps.
    assert.match(src, /Launcher\.launchEntry\(row\.entry\)/);
}
const launcherModel = process.argv[4], launcherQml = process.argv[5];
if (launcherModel) {
    const L = load(launcherModel);
    for (const id of ["webapp-forgerie", "firefox", "", "webapp-"])
        assert.equal(L.entryKind({ id }), F.launchKind(id), "Launcher and the menu agree on " + JSON.stringify(id));
    assert.equal(L.entryKind(null), "app");
}
if (launcherQml) {
    const src = fs.readFileSync(launcherQml, "utf8");
    assert.match(src, /kind: Model\.entryKind\(entry\)/, "launchEntry records web apps as webapp");
    assert.doesNotMatch(src, /icon: entry\.icon, kind: "app"/);
}
// ---------------------------------------------------------------- no workspace numbers
// Every rendered label and hint, in every scope, with and without a query.
const NUMBER = /\bpage\s*\d/i;
const many = [];
for (let i = 0; i < 40; i++) many.push(W("Window " + i, 1 + (i % 9), i % 3 ? "eDP-1" : "SUNSHINE", i, "app" + i));
for (const c of [ctx, Object.assign({}, ctx, { windows: many })])
    for (const scope of ["all", "app", "win", "cmd"])
        for (const q of ["", "w", "tablet", "1", "page"])
            for (const r of F.findRows(scope, q, c))
                for (const text of [r.label, r.hint]) if (text) assert.doesNotMatch(text, NUMBER, scope + " " + q + ": " + text);

console.log("find-model: ranking, grouping, scopes, empty, no results, recent, kinds, scrolling and caller capture passed");
assert.deepEqual(plain(F.destination({title:"Repeated title", appName:"Chromium", isBrowser:true},null)),
    {here:false, blocked:true, text:"Cannot identify this browser window",title:""},
    "a disconnected or ambiguous browser must not promise a new window");
