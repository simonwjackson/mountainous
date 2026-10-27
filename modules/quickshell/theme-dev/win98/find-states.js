// Fixtures for the Win98 Find window and Open dialog in the harness: the
// parity mock's data.js and its item 2 states (/tmp/tandem/win98-parity-mock,
// states.js f-* and a-*), in the omni service's shapes. Development only.
.pragma library

// Windows as the harness's toplevels read them. at and size are logical px
// on a 1920x1200 screen whose taskbar is 38 px tall.
var LEFT = { at: [0, 0], size: [958, 1160] };
var RIGHT = { at: [962, 0], size: [958, 1160] };
function w(appId, title, page, extra) {
    var o = { appId: appId, title: title, page: page };
    for (var k in (extra || {})) o[k] = extra[k];
    return o;
}
var BASE = [
    w("com.mitchellh.ghostty", "simon@myoko: ~/code/github/simonwjackson/mountainous", 1, { focused: true, at: LEFT.at, size: LEFT.size }),
    w("chrome-github.com__-Default", "Pull requests - simonwjackson/mountainous", 1, { at: RIGHT.at, size: RIGHT.size }),
    w("signal", "Signal", 2),
    w("dev.zed.Zed", "bar-plan.js - mountainous", 2),
    w("com.obsproject.Studio", "OBS 31.1.2 - Profile: myoko - Scenes: Desk", 3),
    w("chromium-browser", "Windows 98 - Wikipedia - Chromium", 3)
];
var EXTRA = [
    ["com.mitchellh.ghostty", "htop", 1], ["chrome-music.youtube.com__-Default", "YouTube Music", 2], ["dev.zed.Zed", "TopBar.qml - mountainous", 2],
    ["transmission-gtk", "Transmission", 3], ["com.mitchellh.ghostty", "ssh zao", 4], ["com.mitchellh.ghostty", "ssh unzen", 4],
    ["chrome-mail.google.com__-Default", "Gmail - Inbox (3) - simon@kamoi.example", 4], ["firefox", "Mozilla Firefox", 5],
    ["com.mitchellh.ghostty", "nix build .#nixosConfigurations.zao.config.system.build.toplevel", 5],
    ["chrome-grafana.kamoi.example__-Default", "Grafana - Storage - towada cache and bcachefs members, last 24 hours", 5],
    ["signal", "Signal - Aiko", 6], ["dev.zed.Zed", "shell.qml - mountainous", 6], ["com.mitchellh.ghostty", "journalctl -fu quickshell", 6],
    ["com.mitchellh.ghostty", "btop", 6], ["chrome-calendar.google.com__-Default", "Google Calendar - Week of October 26", 6],
    ["firefox", "Supercalifragilisticexpialidocious_no_breaks_in_this_title_at_all", 6]
].map(function (a) { return w(a[0], a[1], a[2]); });
var TABLET = [
    w("firefox", "Mozilla Firefox", 1, { screen: "SUNSHINE" }),
    w("com.mitchellh.ghostty", "ssh rakku", 1, { screen: "SUNSHINE" })
];

// OmniBar.appRows: { label, detail, entry { id, icon } }.
var APPS = [
    ["Chromium", "chromium", "Web Browser"], ["Firefox", "firefox", "Web Browser"], ["Files", "org.gnome.Nautilus", "File Manager"],
    ["Ghostty", "com.mitchellh.ghostty", "Terminal"], ["GitHub", "webapp-github", ""], ["Gmail", "webapp-gmail", ""],
    ["Google Calendar", "webapp-calendar", ""], ["Grafana", "webapp-grafana", ""], ["Htop", "htop", "Process Viewer"],
    ["NixOS Manual", "nixos-manual", ""], ["OBS Studio", "com.obsproject.Studio", "Streaming"], ["Signal", "signal", "Messenger"],
    ["Sunshine", "sunshine", "Game stream host"], ["Syncthing", "syncthing", ""], ["Text Editor", "org.gnome.TextEditor", "Text Editor"],
    ["Transmission", "transmission", "BitTorrent Client"], ["YouTube Music", "webapp-ytmusic", ""], ["Zed", "dev.zed.Zed", "Text Editor"]
].map(function (a) { return { kind: "app", label: a[0], detail: a[2], entry: { id: a[1], name: a[0], icon: a[1] } }; });

// Launcher.recent, most recent first.
var RECENT = [
    { id: "dev.zed.Zed", name: "Zed", icon: "dev.zed.Zed", kind: "app" },
    { id: "webapp-ytmusic", name: "YouTube Music", icon: "webapp-ytmusic", kind: "webapp" },
    { id: "signal", name: "Signal", icon: "signal", kind: "app" },
    { id: "com.mitchellh.ghostty", name: "Ghostty", icon: "com.mitchellh.ghostty", kind: "app" },
    { id: "com.obsproject.Studio", name: "OBS Studio", icon: "com.obsproject.Studio", kind: "app" },
    { id: "webapp-grafana", name: "Grafana", icon: "webapp-grafana", kind: "webapp" },
    { id: "transmission", name: "Transmission", icon: "transmission", kind: "app" }
].map(function (r, i) { r.argv = [r.id]; r.lastLaunched = 1000 - i; return r; });

// CdpBrowser.pages.
var PAGES = [
    { id: "p1", title: "Pull requests - simonwjackson/mountainous", url: "https://github.com/simonwjackson/mountainous/pulls", host: "github.com" },
    { id: "p2", title: "NixOS/nixpkgs: Nix Packages collection & NixOS", url: "https://github.com/NixOS/nixpkgs", host: "github.com" },
    { id: "p3", title: "YouTube Music", url: "https://music.youtube.com/", host: "music.youtube.com" },
    { id: "p4", title: "Windows 98 - Wikipedia", url: "https://en.wikipedia.org/wiki/Windows_98", host: "en.wikipedia.org" },
    { id: "p5", title: "Grafana - Storage", url: "https://grafana.kamoi.example/d/storage?orgId=1&from=now-24h&to=now&var-host=towada", host: "grafana.kamoi.example" }
];

// The states. windows: "base", "extra" (22) or "tablet" (two screens);
// mode/query: the service's entry; caller: the window it acts on (index);
// drop: Look in open on that row; list/pick: Open's drop-down; tip: the
// in-place tip on the selected row; steps: Down presses after opening.
var STATES = [
    { id: "f-rest", label: "Super+P: untouched", windows: "base", mode: "root" },
    { id: "f-typing", label: "Typing \"fi\"", windows: "base", mode: "root", query: "fi" },
    { id: "f-scope-pop", label: "Look in: the scope list open", windows: "base", mode: "root", drop: 2 },
    { id: "f-scope-win", label: "Windows scope, two screens", windows: "tablet", mode: "window" },
    { id: "f-none", label: "Nothing found: \"qx7\"", windows: "base", mode: "app", query: "qx7" },
    { id: "f-addr-row", label: "An address typed: \"nixos.org\"", windows: "base", mode: "root", query: "nixos.org" },
    { id: "f-long", label: "22 windows: the list scrolls", windows: "extra", mode: "root", steps: 20 },
    { id: "f-cut", label: "A cut title shows in full on hover", windows: "extra", mode: "window", query: "gra", tip: true },
    { id: "f-recent", label: "Applications scope leads with recent", windows: "base", mode: "app" },
    { id: "f-empty", label: "No windows, nothing launched", windows: "alone", mode: "root", noRecent: true },
    { id: "a-open", label: "Ctrl+L on a web app: Open, the address selected", windows: "base", mode: "nav", caller: 1 },
    { id: "a-list", label: "Typing \"git\": open pages listed", windows: "base", mode: "nav", caller: 1, typed: "git", list: true, pick: 1 },
    { id: "a-new", label: "Ctrl+L on a terminal: opens a new window", windows: "base", mode: "nav", caller: 0, query: "nixos.org/manual" }
];

function stateById(id) {
    for (var i = 0; i < STATES.length; i++) if (STATES[i].id === id) return STATES[i];
    return null;
}
function stateIds() { return STATES.map(function (s) { return s.id; }); }
function windowsFor(id) {
    var s = stateById(id);
    if (!s) return null;
    var base = BASE.map(function (x) { return Object.assign({}, x); });
    if (s.windows === "extra") return base.concat(EXTRA.map(function (x) { return Object.assign({}, x); }));
    if (s.windows === "tablet") return base.concat(TABLET.map(function (x) { return Object.assign({}, x); }));
    if (s.windows === "alone") return [base[0]];
    return base;
}
