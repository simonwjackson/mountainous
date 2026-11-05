// menu-models.js: the Apple menu, the Application menu and a tile's menu.
// Run: node menu-models.test.js menu-models.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
// menu-models.js .imports ../../sni-tray.js as Sni, as QML does. The
// third argument names it when the model file is not in its tree.
const load = (file, ctx = {}) => {
    vm.runInNewContext(fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "")
        .replace(/^\.import "[^"]+" as \w+\s*$/mg, ""), ctx);
    return ctx;
};
const modelFile = process.argv[2] || __dirname + "/menu-models.js";
const Sni = load(process.argv[3] || path.join(path.dirname(modelFile), "../../sni-tray.js"));
const M = load(modelFile, { Sni });
const plain = (v) => JSON.parse(JSON.stringify(v));
const labels = (rows) => rows.map((r) => r.kind === "separator" ? "—" : r.label);

// ---- Apple menu
const webApps = [{ id: "youtube-music", name: "YouTube Music", icon: "webapp-youtube-music" },
    { id: "forgerie", name: "Forgerie", icon: "webapp-forgerie" }, { id: "reddit", name: "Reddit", icon: "webapp-reddit" }];
let a = M.apple({ host: "myoko", builder: true, recent: [], webApps });
assert.deepEqual(plain(labels(a)), ["About Myoko…", "—", "Control Panels", "Recent Applications",
    "Forgerie", "Reddit", "YouTube Music", "—", "Find…", "—", "Lock", "Sleep", "Log Out…", "Restart…", "Shut Down…"]);
assert.equal(a.find((r) => r.id === "find").hint, "Super+P");
assert.equal(a.find((r) => r.id === "logout").hint, "Super+Shift+E");
assert.deepEqual(plain(labels(a.find((r) => r.id === "cp").submenu)),
    ["Appearance…", "Bluetooth", "Brightness", "Remote builds", "Sound", "Wi-Fi"]);
assert.deepEqual(plain(a.find((r) => r.id === "cp").submenu.map((r) => r.action.control)), ["theme", "bt", "bri", "builder", "vol", "wifi"]);
assert.equal(a.find((r) => r.id === "forgerie" || r.id === "webapp-forgerie").app, "webapp-forgerie");
assert.deepEqual(plain(a.find((r) => r.id === "restart").action), { kind: "confirm", what: "restart" });
assert.deepEqual(plain(a.find((r) => r.id === "lock").action), { kind: "session", what: "lock" });
assert.deepEqual(plain(a.find((r) => r.id === "sleep").action), { kind: "session", what: "sleep" });
// No gate: no Remote builds. No recent: one disabled row that says so.
a = M.apple({ host: "zao", builder: false, recent: [], webApps: [] });
assert.equal(labels(a)[0], "About Zao…");
assert.deepEqual(plain(labels(a.find((r) => r.id === "cp").submenu)), ["Appearance…", "Bluetooth", "Brightness", "Sound", "Wi-Fi"]);
assert.deepEqual(plain(a.find((r) => r.id === "recent").submenu.map((r) => [r.label, r.disabled])), [["No recent applications", true]]);
assert.equal(a.filter((r) => r.id && r.id.indexOf("webapp-") === 0).length, 0);
assert.equal(M.apple({}).length > 0, true);
assert.equal(labels(M.apple({}))[0], "About This Computer…");
// Recent: most recent first, at most 15, web apps marked.
const recent = Array.from({ length: 20 }, (_, i) => ({ id: "app" + i, name: "App " + i, icon: i === 0 ? "" : "icon" + i, kind: i === 1 ? "webapp" : "app" }));
const rr = M.apple({ recent }).find((r) => r.id === "recent").submenu;
assert.equal(rr.length, 15);
assert.deepEqual(plain([rr[0].label, rr[0].spacer, rr[1].hint, rr[1].app]), ["App 0", true, "web app", "icon1"]);
assert.equal(rr[2].action.kind, "launchRecent");

// ---- alerts
assert.equal(M.alert("restart", "myoko").button, "Restart");
assert.match(M.alert("shutdown", "myoko").text, /Myoko/);
assert.equal(M.alert("logout").button, "Log Out");
assert.equal(M.alert("nope"), null);

// ---- Application menu
const app = (appId, name, n, extra) => Object.assign({ appId, name, icon: appId, count: n, front: false, hidden: false,
    windows: Array.from({ length: n }, (_, i) => ({ address: appId + i, title: name + " " + i, page: 1 + i, screen: "eDP-1", workspace: String(1 + i) })) }, extra || {});
const apps = [app("firefox", "Firefox", 1, { front: true }), app("gh", "GitHub", 5), app("signal", "Signal", 1, { hidden: true })];
let m = M.application({ apps, front: "firefox0", frontApp: "firefox", frontName: "Firefox", othersShown: true, anyHidden: true, target: "gh", here: "eDP-1" });
assert.deepEqual(plain(labels(m)), ["Hide Firefox", "Hide Others", "Show All", "—", "Show Desktop", "—", "Firefox", "GitHub", "Signal"]);
const ghRow = m.find((r) => r.id === "app-gh");
assert.deepEqual(plain([ghRow.count, ghRow.highlight, ghRow.submenu.length, ghRow.submenu[2].hint]), [5, true, 5, ""], "this screen: no hint");
assert.equal(m.find((r) => r.id === "app-firefox").check, true);
assert.equal(m.find((r) => r.id === "app-firefox").submenu, null, "one window: no submenu");
assert.equal(m.find((r) => r.id === "app-signal").dim, true);
// No front app, nothing hidden, nothing else shown: the three actions disable.
m = M.application({ apps: [], front: "", frontApp: "", othersShown: false, anyHidden: false });
assert.deepEqual(plain(m.slice(0, 3).map((r) => [r.label, r.disabled])), [["Hide", true], ["Hide Others", true], ["Show All", true]]);
assert.deepEqual(plain(labels(m)), ["Hide", "Hide Others", "Show All", "—", "Show Desktop", "—", "No applications"]);
assert.equal(m.find((r) => r.id === "showDesktop").disabled, true, "nothing covers the desktop and nothing is parked");
// Another screen names the screen; hidden windows say so. Never a page.
const other = app("mpv", "mpv", 2);
other.windows[1].screen = "SUNSHINE";
other.windows[0].workspace = "special:desktop-eDP-1";
const sub = M.application({ apps: [other], here: "eDP-1", screenLabel: (s) => s === "SUNSHINE" ? "tablet" : s })[6].submenu;
assert.deepEqual(plain(sub.map((r) => r.hint)), ["hidden", "tablet"]);

// Window rows go in strip order, whatever the MRU order of the app's windows.
const mixed = app("gh", "GitHub", 3);
mixed.windows = [mixed.windows[2], mixed.windows[0], mixed.windows[1]];
assert.deepEqual(plain(M.application({ apps: [mixed], here: "eDP-1" })[6].submenu.map((r) => r.label)), ["GitHub 0", "GitHub 1", "GitHub 2"]);

// ---- Show Desktop: its own row, and Hide Others while the desktop is in front
m = M.application({ apps, front: "firefox0", frontApp: "firefox", frontName: "Firefox", othersShown: true, coveredShown: true });
let sd = m.find((r) => r.id === "showDesktop");
assert.deepEqual(plain([sd.hint, sd.check, sd.disabled, sd.action]), ["Super+Shift+D", false, false, { kind: "showDesktop" }]);
assert.deepEqual(plain(m.find((r) => r.id === "hideOthers").action), { kind: "hideOthers", appId: "firefox" }, "an app in front: Hide Others hides the other apps");
m = M.application({ apps, front: "", frontApp: "", coveredShown: true });
assert.deepEqual(plain([m[1].label, m[1].disabled, m[1].action]), ["Hide Others", false, { kind: "showDesktop" }], "the desktop in front: Hide Others shows the desktop");
m = M.application({ apps, front: "", frontApp: "", coveredShown: false, desktopShown: true });
sd = m.find((r) => r.id === "showDesktop");
assert.deepEqual(plain([sd.check, sd.disabled]), [true, false], "shown: checked, and choosing it brings the windows back");
assert.equal(m[1].disabled, true, "nothing left to hide");

// ---- Apple menu: Files while Hensou Files is installed
let af = M.apple({ host: "myoko", recent: [], webApps: [], files: { icon: "hensou-files" } });
assert.deepEqual(plain(labels(af).slice(0, 5)), ["About Myoko…", "—", "Control Panels", "Files", "Recent Applications"]);
const filesRow = af.find((r) => r.id === "files");
assert.deepEqual(plain([filesRow.hint, filesRow.app, filesRow.spacer, filesRow.action]), ["Super+E", "hensou-files", false, { kind: "files" }]);
af = M.apple({ host: "myoko", files: {} });
assert.deepEqual(plain([af.find((r) => r.id === "files").app, af.find((r) => r.id === "files").spacer]), ["", true], "no icon: the column stays");
assert.equal(M.apple({ host: "myoko" }).some((r) => r.id === "files"), false, "not installed: no row");

// ---- an app's tray menu (dbusmenu) as cascade rows
const e = (text, extra) => Object.assign({ text, enabled: true, separator: false, check: "none", checked: false, ref: { name: text } }, extra || {});
const sepE = { separator: true };
let sr = M.sniRows([sepE, e("_Show Transfers"), sepE, sepE, e("Cancel _All", { enabled: false }),
    e("Mode", { children: [e("_Fast", { check: "radio", checked: true }), e("Slow", { check: "radio" })] }),
    e("Empty", { children: [] }), e("a__b"), sepE]);
assert.deepEqual(plain(labels(sr)), ["Show Transfers", "—", "Cancel All", "Mode", "Empty", "a_b"]);
assert.equal(sr[0].action.kind, "sniEntry");
assert.equal(sr[0].action.ref.name, "_Show Transfers");
assert.equal(sr[2].disabled, true);
assert.deepEqual(plain(sr[3].submenu.map((r) => [r.label, r.check])), [["Fast", true], ["Slow", false]]);
assert.equal(sr[3].action, null, "a cascade opens, it does not trigger");
assert.equal(sr[4].disabled, true, "an empty submenu stays visible, disabled");
assert.equal("check" in sr[0], false, "a plain entry has no check column");
sr = M.sniRows([e("Quit")], { defaultLabel: "Files" });
assert.deepEqual(plain(labels(sr)), ["Open Files", "—", "Quit"]);
assert.deepEqual(plain(sr[0].action), { kind: "sniActivate" });
assert.deepEqual(plain(labels(M.sniRows([]))), ["No commands"]);
assert.equal(M.sniRows([]).every((r) => r.disabled), true);

// ---- tile menu
const move = { pages: [{ page: 1, label: "Beside Signal and Zed", current: false }, { page: 2, label: "On its own", current: true }], newPage: 5 };
let t = M.tile({ window: { address: "w4", appId: "gh", title: "feat(quickshell): Platinum control strip #418", page: 2 },
    appName: "GitHub", appIcon: "github", front: false, shown: false, move });
assert.deepEqual(plain(labels(t)), ["feat(quickshell): Platinum control strip #418", "—", "Switch to window", "Close window", "—", "Move to page", "Hide GitHub"]);
assert.equal(t[0].kind, "header");
assert.equal(t[0].detail, "GitHub, not showing");
assert.deepEqual(plain(labels(t[5].submenu)), ["Beside Signal and Zed", "On its own", "—", "New page"]);
assert.deepEqual(plain([t[5].submenu[1].check, t[5].submenu[1].disabled]), [true, true]);
assert.deepEqual(plain(t[5].submenu[3].action), { kind: "moveTo", address: "w4", page: 5 });
t = M.tile({ window: { address: "w1", appId: "x", title: "", page: 1 }, front: true, shown: true, move });
assert.deepEqual(plain([t[0].label, t[0].detail, t[2].label, t[2].disabled]), ["x", "x, front window", "Front window", true]);

// ---- no workspace numbers: no label, hint or detail in any menu names a page
const NUMBER = /\bpage\s*\d/i;
const text = (rows) => (rows || []).flatMap((r) => [r.label, r.hint, r.detail].concat(text(r.submenu))).filter(Boolean);
const many = Array.from({ length: 12 }, (_, i) => app("app" + i, "App " + i, 4));
many[3].windows[2].screen = "SUNSHINE";
const shown = [].concat(
    text(M.application({ apps: many, here: "eDP-1", screenLabel: (s) => s })),
    text(M.tile({ window: { address: "w", appId: "gh", title: "t", page: 7 }, appName: "GitHub", move })),
    text(M.apple({ host: "myoko", builder: true, recent, webApps, files: { icon: "x" } })));
assert.ok(shown.length > 50);
for (const s of shown) assert.doesNotMatch(s, NUMBER, s);

// ---- keyboard: the next enabled row, skipping separators, headers and disabled rows
assert.equal(M.nextEnabled(t, -1, 1), 3);
assert.equal(M.nextEnabled(t, 3, 1), 5);
assert.equal(M.nextEnabled(t, 3, -1), 6, "wraps upward past the header");
assert.equal(M.nextEnabled([], 0, 1), -1);
assert.equal(M.nextEnabled([{ kind: "separator" }, { kind: "item", disabled: true }], -1, 1), -1);
console.log("menu-models: Apple menu (Files), alerts, Application menu (Show Desktop), tray menus, tile menu and keyboard order pass");
