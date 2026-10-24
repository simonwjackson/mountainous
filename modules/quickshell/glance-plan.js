.pragma library

// The glance space's layout and motion, as pure functions. Ported from the
// approved mock (/tmp/glance-mock/glance.js, sections 2 and 3).
//
// Layout: Clean Up order, as the Finder cleaned up its desktop. From the
// top right, down a column, then the next column to the left. Width never
// scrolls; when the width runs out the space scrolls vertically.

var GP = {TOP: 6, RIGHT: 8, BOTTOM: 8, LEFT: 8, GAP: 12, GAP_MIN: 6, SB: 15, TIGHT_W: 600, TIGHT_H: 400};

/**
 * @param {number} W the space's width
 * @param {number} H the space's height
 * @param {{id: string, w: number, h: number}[]} items in priority order, at
 *   their rest size (no host open, not shaded), so opening a host or using
 *   WindowShade never moves the other widgets.
 */
function plan(W, H, items, opt) {
    const sb = opt && opt.sb ? GP.SB : 0;
    const availW = Math.max(0, W - GP.LEFT - GP.RIGHT - sb);
    const availH = Math.max(0, H - GP.TOP - GP.BOTTOM);
    // Space yields first.
    const gap = availW < GP.TIGHT_W || availH < GP.TIGHT_H ? GP.GAP_MIN : GP.GAP;
    const cols = [];
    const usedW = function () {
        let s = 0;
        for (const c of cols) s += c.w;
        return s + gap * Math.max(0, cols.length - 1);
    };
    const widenOk = function (c, w) { return w <= c.w || usedW() - c.w + w <= availW; };
    for (const it of items) {
        const w = Math.min(it.w, availW), h = Math.min(it.h, availH);
        let col = null;
        for (const c of cols) if (c.h + gap + h <= availH && widenOk(c, w)) { col = c; break; }
        if (!col && (cols.length === 0 || usedW() + gap + w <= availW)) {
            col = {w: 0, h: -gap, items: []};
            cols.push(col);
        }
        if (!col) {
            // No width left: under the shortest column that can hold it.
            let best = null;
            for (const c of cols) if (widenOk(c, w) && (best === null || c.h < best.h)) best = c;
            col = best || cols[0];
        }
        const y = col.h + gap;
        col.items.push({id: it.id, y: y, w: w, h: h});
        col.h = y + h;
        col.w = Math.max(col.w, w);
    }
    let contentH = 0;
    for (const c of cols) contentH = Math.max(contentH, c.h);
    const scroll = contentH > availH;
    if (scroll && !(opt && opt.sb)) return plan(W, H, items, {sb: true});
    const rects = {};
    let xr = W - GP.RIGHT - sb;
    for (const c of cols) {
        for (const i of c.items) rects[i.id] = {x: xr - i.w, y: GP.TOP + i.y, w: i.w, h: i.h};
        xr -= c.w + gap;
    }
    return {rects: rects, cols: cols.length, gap: gap, scroll: scroll, sb: sb,
        contentH: contentH + GP.TOP + GP.BOTTOM, availW: availW, availH: availH};
}

/**
 * The final rects: remembered places (margins from the top right: {r, t})
 * apply only while nothing scrolls, so no widget can be left off screen.
 * Every rect is kept inside the space.
 */
function place(result, places, W, H) {
    const out = {};
    for (const id of Object.keys(result.rects)) {
        const r = Object.assign({}, result.rects[id]);
        const p = places ? places[id] : null;
        if (p && !result.scroll && Number.isFinite(p.r) && Number.isFinite(p.t)) {
            r.x = W - result.sb - p.r - r.w;
            r.y = p.t;
            r.remembered = true;
        }
        r.x = Math.max(0, Math.min(r.x, W - result.sb - r.w));
        // A dragged widget keeps at least its title bar on screen.
        if (!result.scroll) r.y = Math.max(0, Math.min(r.y, H - Math.min(r.h, 18)));
        out[id] = r;
    }
    return out;
}

// The margins a widget dragged to x, y is remembered by.
function remember(x, y, w, W, sb) {
    return {r: Math.round(W - (sb || 0) - x - w), t: Math.round(y)};
}

// ---------------------------------------------------------------- motion
// Frames at 60 Hz. Presence only: no alpha in any frame.
var FRAME = 1000 / 60;
var ZOOM_FRAMES = 9;   // 150 ms

/**
 * @param {'zoom'|'cut'} style
 * @param {'in'|'out'} dir
 * @param {number} t milliseconds since the key
 * @param {boolean} reduced reduced motion: every style is the cut
 * @returns {{background: boolean, widgets: boolean, outlines: number[]|null, done: boolean, k: number}}
 *   outlines: the progress (0 at the origin, 1 at the widget) of each of
 *   the four trailing outline rects drawn this frame.
 */
function frameAt(style, dir, t, reduced) {
    const k = Math.max(0, Math.floor(t / FRAME + 1e-6));
    if (style === "cut" || reduced) {
        return dir === "in" ? {background: true, widgets: true, outlines: null, done: true, k: k}
            : {background: false, widgets: false, outlines: null, done: true, k: k};
    }
    const progress = function (j) {
        const s = j / ZOOM_FRAMES;
        return dir === "in" ? 1 - (1 - s) * (1 - s) : 1 - s * s;
    };
    let outlines = null;
    if (k < ZOOM_FRAMES) {
        outlines = [];
        for (const j of [k - 3, k - 2, k - 1, k]) if (j >= 0) outlines.push(progress(j));
    }
    const done = k >= ZOOM_FRAMES;
    return dir === "in" ? {background: true, widgets: done, outlines: outlines, done: done, k: k}
        : {background: !done, widgets: false, outlines: outlines, done: done, k: k};
}

// One outline: the origin rect moved toward the widget's rect by p.
function between(origin, rect, p) {
    return {
        x: origin.x + (rect.x - origin.x) * p,
        y: origin.y + (rect.y - origin.y) * p,
        w: origin.w + (rect.w - origin.w) * p,
        h: origin.h + (rect.h - origin.h) * p
    };
}
