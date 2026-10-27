.pragma library
// The Win98 Start menu's lists, as pure functions over plain values. The
// Desktop passes DesktopEntries, the screen's windows and the omni bar's
// command rows; the menu (Win98Menu) draws what these return.
//
// An item is { text, icon, shortcut, submenu, enabled, action, ... }:
// "&" marks the access key, and action names what a click does.

// Freedesktop main categories, by the folder Win98 would have filed them in.
var FOLDERS = [
    ["Accessories", ["Utility", "TextEditor", "Accessibility"]],
    ["Development", ["Development"]],
    ["Education", ["Education", "Science"]],
    ["Games", ["Game"]],
    ["Graphics", ["Graphics"]],
    ["Internet", ["Network", "WebBrowser", "Email", "Chat"]],
    ["Multimedia", ["AudioVideo", "Audio", "Video"]],
    ["Office", ["Office"]],
    ["System", ["System", "Settings", "TerminalEmulator"]]
];
var OTHER = "Other";

// The Win98 icon for an app, when the set has one; "" otherwise.
// Data never carries access keys: a literal "&" is written "&&".
function literal(s) { return String(s).replace(/&/g, "&&"); }

function appIcon(id, name) {
    var s = ((id || "") + " " + (name || "")).toLowerCase();
    if (/ghostty|foot|kitty|alacritty|terminal|htop|btop/.test(s)) return "term";
    if (/chrom/.test(s)) return "chromium";
    if (/firefox/.test(s)) return "firefox";
    if (/signal/.test(s)) return "signal";
    if (/(^|[ .])zed/.test(s)) return "zed";
    if (/obsproject|obs studio|(^| )obs( |$)/.test(s)) return "obs";
    if (/sunshine/.test(s)) return "sun";
    if (/syncthing/.test(s)) return "sync";
    if (/transmission/.test(s)) return "tx";
    return "";
}

function folderOf(categories) {
    var list = categories || [];
    for (var f = 0; f < FOLDERS.length; f++) {
        for (var c = 0; c < FOLDERS[f][1].length; c++) {
            if (list.indexOf(FOLDERS[f][1][c]) >= 0) return FOLDERS[f][0];
        }
    }
    return OTHER;
}

// apps: [{ id, name, categories }] -> menu items. One folder per category in
// use, sorted by name, each with its apps sorted by name. When every app
// lands in one folder, the folder is pointless: Programs lists the apps.
function programs(apps) {
    var byFolder = {};
    var rows = [];
    for (var i = 0; i < apps.length; i++) {
        var a = apps[i];
        if (!a || !a.name) continue;
        var row = { text: literal(a.name), name: a.name, icon: appIcon(a.id, a.name) || "doc", action: "app", app: i };
        var folder = folderOf(a.categories);
        (byFolder[folder] = byFolder[folder] || []).push(row);
        rows.push(row);
    }
    var byName = function (x, y) { return x.name.localeCompare(y.name); };
    var names = Object.keys(byFolder).sort(function (x, y) {
        if (x === OTHER) return 1;
        if (y === OTHER) return -1;
        return x.localeCompare(y);
    });
    if (names.length <= 1) return rows.sort(byName);
    return names.map(function (n) {
        return { text: n, icon: "folder", submenu: byFolder[n].sort(byName) };
    });
}

function shortTitle(title) {
    var t = title && title !== "" ? title : "(untitled)";
    return t.length > 44 ? t.slice(0, 41) + "..." : t;
}

// windows: [{ title, page, icon, hint }] in lane order (by page). Pages are
// never numbered on screen: a separator stands between two pages' windows.
// hint goes in the shortcut column ("Minimized").
function windows(list) {
    if (!list.length) return [{ text: "(No windows)", enabled: false }];
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var w = list[i];
        if (i > 0 && w.page !== list[i - 1].page) out.push({ separator: true });
        var item = { text: literal(shortTitle(w.title)), icon: w.icon || "doc", action: "window", window: i };
        if (w.hint) item.shortcut = w.hint;
        out.push(item);
    }
    return out;
}

// The omni bar's commands, without the rows the picker owns (appearance and
// theme) or the omni bar's own modes. The three scale rows become one
// cascade, as the mock draws them.
var SCALE = { scaleup: "Scale up", scaledown: "Scale down", scalereset: "Scale 100%" };
function commands(rows) {
    var out = [];
    var scale = [];
    var tail = [];
    for (var i = 0; i < rows.length; i++) {
        var r = rows[i];
        if (!r || r.kind !== "cmd") continue;
        if (/^theme:/.test(r.act) || r.act === "mode:window") continue;
        var label = r.label.replace(/\u2026$/, "...");
        if (r.act === "mode:nav") label = "Go to address...";
        var item = { text: literal(label), shortcut: r.detail, action: "command", row: i };
        if (SCALE[r.act]) { item.text = SCALE[r.act]; scale.push(item); continue; }
        if (r.act === "chrome") { tail.push(item); continue; }
        out.push(item);
    }
    if (scale.length || tail.length) out.push({ separator: true });
    if (scale.length) out.push({ text: "Interface scale", icon: "scale", submenu: scale });
    return out.concat(tail);
}

// Favorites ▸: the pinned web apps (desktop entries webapp-<id>, from
// modules/web-apps.nix), by name, each with its lettermark (a theme icon).
// webApps: [{ id, name, icon }]; an item's webapp is the index into it.
function favorites(webApps) {
    var list = (webApps || []).map(function (a, i) { return { a: a, i: i }; })
        .filter(function (x) { return x.a && (x.a.name || x.a.id); });
    if (!list.length) return [{ text: "(Empty)", enabled: false }];
    list.sort(function (x, y) { return String(x.a.name || x.a.id).toLowerCase() < String(y.a.name || y.a.id).toLowerCase() ? -1 : 1; });
    return list.map(function (x) {
        return { text: literal(x.a.name || x.a.id), themeIcon: x.a.icon || "", action: "webapp", webapp: x.i };
    });
}

// Documents ▸: Recent Applications (Launcher.recent, most recent first, at
// most 15), as Win98's Documents held the recent items. A web app says so
// in the shortcut column. recent: [{ id, name, icon, kind }].
function documents(recent) {
    var out = [];
    var list = recent || [];
    for (var i = 0; i < list.length && out.length < 15; i++) {
        var r = list[i];
        if (!r || !(r.name || r.id)) continue;
        var own = appIcon(r.id, r.name);
        out.push({ text: literal(r.name || r.id), icon: own, themeIcon: own ? "" : (r.icon || ""),
            shortcut: r.kind === "webapp" ? "web app" : "", action: "recent", recent: i });
    }
    return out.length ? out : [{ text: "(Empty)", enabled: false }];
}

function settings() {
    return [
        { text: "&Display...", icon: "display", action: "picker" },
        { text: "S&ystem...", icon: "host", action: "system" },
        { separator: true },
        { text: "&Bluetooth", icon: "bluetooth-on", action: "open", control: "bt" },
        { text: "&Wi-Fi", icon: "wifi-4", action: "open", control: "wifi" },
        { text: "&Sound", icon: "volume-1", action: "open", control: "vol" },
        { text: "Brigh&tness", icon: "brightness", action: "open", control: "bri" }
    ];
}

// Start > Find: the Find window (Super+P) in each scope, and IE's Open
// dialog (Ctrl+L). Run... opens the Find window too, in All.
function findMenu() {
    return [
        { text: "&All...", icon: "find", shortcut: "Super+P", action: "find", scope: "all" },
        { separator: true },
        { text: "A&pplications...", icon: "programs", shortcut: "Ctrl+1", action: "find", scope: "app" },
        { text: "&Windows...", icon: "windows", shortcut: "Ctrl+2", action: "find", scope: "win" },
        { text: "&Commands...", icon: "commands", shortcut: "Ctrl+3", action: "find", scope: "cmd" },
        { separator: true },
        { text: "A&ddress...", icon: "globe", shortcut: "Ctrl+L", action: "find", scope: "address" }
    ];
}

// taskbarList: what a bar too narrow for its tray holds (the tray
// controls, the clock, the battery); empty while the bar has room.
// extra: { favorites, documents, host } (favorites() and documents()
// lists; the host name for Lock).
function top(programList, windowList, commandList, user, taskbarList, extra) {
    var x = extra || {};
    var taskbar = taskbarList && taskbarList.length
        ? [{ text: "T&askbar", icon: "windows", submenu: taskbarList }] : [];
    var host = x.host ? x.host.charAt(0).toUpperCase() + x.host.slice(1) : "";
    return [
        { text: "&Programs", icon: "programs", submenu: programList },
        { text: "Fa&vorites", icon: "favorites", submenu: x.favorites || favorites([]) },
        { text: "&Documents", icon: "documents", submenu: x.documents || documents([]) },
        { text: "&Windows", icon: "windows", submenu: windowList },
        { text: "&Commands", icon: "commands", submenu: commandList },
        { text: "&Settings", icon: "settings", submenu: settings() }
    ].concat(taskbar, [
        { separator: true },
        { text: "&Find", icon: "find-large", submenu: findMenu() },
        { text: "&Run...", icon: "run", action: "run" },
        { separator: true },
        { text: host ? "Loc&k " + host : "Loc&k", icon: "lock-computer", action: "lock" },
        { text: "&Log Off " + user + "...", icon: "logoff", action: "logoff" },
        { text: "Sh&ut Down...", icon: "shutdown", action: "shutdown" }
    ]);
}
