.pragma library
.import "glance-plan.js" as GlancePlan

// Window motion true to each desktop theme, as pure functions. Hyprland
// cuts every window under both themes (modules/hyprland/titlebars.lua:
// windows, fade and layers off); the shell draws the OS's own motion over
// the cut, from WindowMotion.qml's events:
//
//   event        Windows 98                       Mac OS 8 (Platinum)
//   minimize     caption: window -> its button    zoom rects: window -> its tile
//   restore      caption: button -> window        zoom rects: tile -> window
//   maximize     caption: old caption -> new      none (the zoom box cut)
//   unmaximize   caption: old caption -> new      none
//   open         none (a window appeared)         zoom rects: tile -> window
//   close        none                             zoom rects: window -> tile
//
// "Minimize" is the shared hide (WindowHider): Win98's minimize, Platinum's
// collapse box, Hide and Hide Others. 150 ms, nine frames at 60 Hz, the
// glance space's own timing (GlancePlan.frameAt). No alpha in any frame.
// Reduced motion is the cut: no frame is drawn.

var DURATION = GlancePlan.ZOOM_FRAMES * GlancePlan.FRAME;

var MOVES = {
    win98: { minimize: "caption", restore: "caption", maximize: "caption", unmaximize: "caption" },
    platinum: { minimize: "zoom", restore: "zoom", open: "zoom", close: "zoom" }
};

// From the window to its control ("out", toward the origin), or from the
// control to the window ("in"). For maximize the origin is the old caption.
var DIR = { minimize: "out", close: "out", restore: "in", open: "in", maximize: "in", unmaximize: "in" };

// "caption", "zoom" or "" (a cut) for one theme and event.
function style(theme, kind) {
    var m = MOVES[theme];
    return m && m[kind] ? m[kind] : "";
}

function key(address) {
    return String(address || "").replace(/^0x/, "");
}

// A row's client rect in global logical px, or null before Hyprland has
// said where and how big it is.
function rectOf(row) {
    if (!row || row.x === undefined || row.y === undefined || !(row.w > 0) || !(row.h > 0)) return null;
    return { x: row.x, y: row.y, w: row.w, h: row.h };
}

// What the motion owner keeps of each row: its rect, whether a screen shows
// it, its fullscreen state.
function snapshot(rows, shown) {
    var out = {};
    for (var i = 0; i < (rows || []).length; i++) {
        var r = rows[i];
        var k = key(r.address);
        if (k === "") continue;
        out[k] = { rect: rectOf(r), screen: r.screen || "", page: r.page, shown: !!shown(r),
            fullscreen: typeof r.fullscreen === "number" ? r.fullscreen : 0, title: r.title || "", appId: r.appId || "",
            active: !!r.active };
    }
    return out;
}

// The rows whose maximized state changed between two snapshots: Win98's
// Maximize and Restore (0 <-> 1). Fullscreen (2) has no motion.
function zooms(before, after) {
    var out = [];
    for (var k in after) {
        var a = before[k], b = after[k];
        if (!a || !a.rect || !b.rect || !b.shown) continue;
        var kind = a.fullscreen === 0 && b.fullscreen === 1 ? "maximize" : a.fullscreen === 1 && b.fullscreen === 0 ? "unmaximize" : "";
        if (kind === "") continue;
        out.push({ kind: kind, address: k, screen: b.screen, rect: a.rect, to: b.rect, title: b.title, appId: b.appId, active: b.active });
    }
    return out;
}

// The events for one WindowHider batch, before it runs. moves: window-hide.js
// moves (a string workspace hides, a number shows); known: the snapshot;
// state: the hider's state before the batch (a hidden window's home screen);
// remembered: rects kept at minimize; shownPages: screen -> the page it
// shows; focus: the address the batch focuses, or "".
// A hide is drawn only for a window a screen shows; a show only for a
// window that lands on its screen's shown page, or that the batch focuses.
function fromMoves(moves, known, state, remembered, shownPages, focus) {
    var out = [];
    for (var i = 0; i < (moves || []).length; i++) {
        var m = moves[i], k = key(m.address), e = known[k];
        if (typeof m.workspace === "string") {
            if (!e || !e.shown || !e.rect) continue;
            out.push({ kind: "minimize", address: k, screen: e.screen, rect: e.rect, title: e.title, appId: e.appId, active: e.active });
        } else {
            var home = state && state.windows ? state.windows[k] : null;
            var kept = remembered ? remembered[k] : null;
            var screen = (home && home.screen) || (kept && kept.screen) || (e ? e.screen : "");
            if (!(key(focus) === k || (shownPages && shownPages[screen] === m.workspace))) continue;
            out.push({ kind: "restore", address: k, screen: screen, rect: kept ? kept.rect : null,
                title: e ? e.title : "", appId: e ? e.appId : "", active: key(focus) === k });
        }
    }
    return out;
}

// openwindow>>ADDR,WORKSPACE,CLASS,TITLE and closewindow>>ADDR
function eventAddress(data) {
    return key(String(data || "").split(",")[0]);
}

// Win98's caption bar over a client rect (Hyprland's at is the client's
// corner, under its caption): the caption's height above it, as wide.
function captionOf(rect, height) {
    return { x: rect.x, y: rect.y - height, w: rect.w, h: height };
}
// A Platinum window's whole frame: its title bar and the client.
function frameOf(rect, bar) {
    return { x: rect.x, y: rect.y - bar, w: rect.w, h: rect.h + bar };
}
// A global rect in one screen's local px.
function local(rect, screen) {
    return rect ? { x: rect.x - screen.x, y: rect.y - screen.y, w: rect.w, h: rect.h } : null;
}

// One frame of one move, t ms after it starts: the rects to draw, origin
// (the control) toward target (the window) by each trailing progress.
//   caption: the newest rect only (one caption bar in flight);
//   zoom: the newest and three trailing (four outlines).
// The glance space's frames and easing (ease out toward the window, ease in
// toward the control), but spread over frames 0 to 8 so the last frame
// lands on its end: on the button or tile for a minimize, on the window
// for a restore. The glance space's own frames stop short (frame 8 of a
// dismiss is a fifth of the way out); a window has to arrive.
function progressAt(dir, j) {
    var s = Math.min(1, j / (GlancePlan.ZOOM_FRAMES - 1));
    return dir === "in" ? 1 - (1 - s) * (1 - s) : 1 - s * s;
}
function frame(styleName, kind, t, reduced) {
    var k = Math.max(0, Math.floor(t / GlancePlan.FRAME + 1e-6));
    var done = !!reduced || k >= GlancePlan.ZOOM_FRAMES;
    var dir = DIR[kind] || "in";
    var p = [];
    if (!done) {
        var from = styleName === "caption" ? k : k - 3;
        for (var j = Math.max(0, from); j <= k; j++) p.push(progressAt(dir, j));
    }
    return { progress: p, done: done, k: k };
}

function between(a, b, p) {
    return GlancePlan.between(a, b, p);
}
