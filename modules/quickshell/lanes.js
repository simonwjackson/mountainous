.pragma library
// Each screen is its own lane: its dock lists its own windows, and its top
// bar names its own front window. shell.qml and OmniBar.qml import this.
//
// Plain functions over Quickshell's Hyprland objects, so they run without a
// compositor; scripts/test-quickshell-lanes feeds them plain objects of the
// same shape. Quickshell 0.3.1 gives a toplevel its `workspace`, a workspace
// its `id`, `monitor` and `active` (shown on its monitor), and a monitor its
// `name`, which is the output name a ShellScreen also reports.
//
// Hyprland nulls a window's workspace, and a workspace's monitor, while it
// moves or closes them. Every function here treats a missing link as "not on
// any screen" rather than failing, and the window reappears on the next
// event.

// The page a window is on, or -1 while it is between pages.
function pageOf(t) {
    return (t && t.workspace) ? t.workspace.id : -1;
}

// The output a window is on, or "" while that is unknown.
function screenOf(t) {
    const ws = t ? t.workspace : null;
    return (ws && ws.monitor && ws.monitor.name) ? ws.monitor.name : "";
}

// True when the window's page is the one its screen is showing.
function isShown(t) {
    return !!(t && t.workspace && t.workspace.active);
}

// One screen's windows, ordered along its pages. Special workspaces have
// negative ids and are not part of any strip.
function windowsOn(toplevels, screen) {
    const out = [];
    // "" is screenOf's "unknown", not a screen. Without this, a screen
    // whose name has not arrived yet would collect every window in
    // transit.
    if (!screen) return out;
    for (const t of toplevels) {
        if (pageOf(t) > 0 && screenOf(t) === screen) out.push(t);
    }
    // By page, and in the compositor's order inside a page. Qt's engine
    // sorts unstably, so the original position breaks ties.
    const at = out.slice();
    out.sort(function (a, b) { return pageOf(a) - pageOf(b) || at.indexOf(a) - at.indexOf(b); });
    return out;
}

// The window a screen's top bar names.
//
// The focused window, when it is on this screen. Otherwise the window that
// last had focus here, while its page is still the one showing. Otherwise
// the first window on the page this screen shows. So the bar under a screen
// you are not using keeps naming what that screen shows, rather than
// echoing the other screen.
function frontWindow(toplevels, screen, active, remembered) {
    const mine = windowsOn(toplevels, screen);
    if (active && mine.indexOf(active) >= 0) return active;
    // indexOf, not a property read: a remembered window that has closed is
    // no longer in the list, and its object may already be gone.
    if (remembered && mine.indexOf(remembered) >= 0 && isShown(remembered)) return remembered;
    for (const t of mine) {
        if (isShown(t)) return t;
    }
    return null;
}

// What a person calls a screen. Output names mean nothing to them.
function screenLabel(name) {
    if (name === "SUNSHINE") return "tablet"; // modules/second-screen.py OUTPUT
    if (name.indexOf("eDP") === 0) return "laptop";
    return name === "" ? "elsewhere" : name;
}

// The omni bar's window rows, grouped by screen. The screen you are on comes
// first, then the others by name; inside a group, most recently focused
// first. Each row carries `screen` (an output name) and `order` (focus
// history, lower is more recent).
function groupRows(rows, here) {
    const out = rows.slice();
    out.sort(function (a, b) {
        const ah = a.screen === here ? 0 : 1;
        const bh = b.screen === here ? 0 : 1;
        if (ah !== bh) return ah - bh;
        if (a.screen !== b.screen) return a.screen < b.screen ? -1 : 1;
        return a.order - b.order;
    });
    return out;
}

// True when a row starts a new screen's group in a list of several screens.
// The first row starts one too, so every group has a heading.
function startsGroup(rows, index) {
    const row = rows[index];
    if (!row || row.kind !== "window") return false;
    let screens = 0;
    const seen = {};
    for (const r of rows) {
        if (r.kind === "window" && !seen[r.screen]) { seen[r.screen] = true; screens++; }
    }
    if (screens < 2) return false;
    for (let i = index - 1; i >= 0; i--) {
        if (rows[i].kind === "window") return rows[i].screen !== row.screen;
    }
    return true;
}
