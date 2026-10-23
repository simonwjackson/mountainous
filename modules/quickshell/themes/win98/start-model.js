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

// windows: [{ title, page, icon }] in lane order.
function windows(list) {
    if (!list.length) return [{ text: "(No windows)", enabled: false }];
    return list.map(function (w, i) {
        return { text: literal(shortTitle(w.title)), icon: w.icon || "doc", shortcut: "Page " + w.page, action: "window", window: i };
    });
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

function settings() {
    return [
        { text: "&Display...", icon: "display", action: "picker" },
        { separator: true },
        { text: "&Bluetooth", icon: "bluetooth-on", action: "open", control: "bt" },
        { text: "&Wi-Fi", icon: "wifi-4", action: "open", control: "wifi" },
        { text: "&Sound", icon: "volume-1", action: "open", control: "vol" },
        { text: "Brigh&tness", icon: "brightness", action: "open", control: "bri" }
    ];
}

// taskbarList: what a bar too narrow for its tray holds (the tray
// controls, the clock, the battery); empty while the bar has room.
function top(programList, windowList, commandList, user, taskbarList) {
    var taskbar = taskbarList && taskbarList.length
        ? [{ text: "T&askbar", icon: "windows", submenu: taskbarList }] : [];
    return [
        { text: "&Programs", icon: "programs", submenu: programList },
        { text: "&Windows", icon: "windows", submenu: windowList },
        { text: "&Commands", icon: "commands", submenu: commandList },
        { text: "&Settings", icon: "settings", submenu: settings() }
    ].concat(taskbar, [
        { separator: true },
        { text: "&Run...", icon: "run", action: "run" },
        { separator: true },
        { text: "&Log Off " + user + "...", icon: "logoff", action: "logoff" }
    ]);
}
