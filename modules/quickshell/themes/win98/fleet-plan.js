.pragma library
// The Win98 Fleet window, its Properties sheet and the Win98 glance space,
// as pure functions of the room they get. Ported from the approved mock
// (/tmp/win98-hud-mock/fleet98.js hudPlan98, app.js sheetRect and
// glancePlan98). Every length is in Win98 units (1 u = 2 physical px); the
// caller measures text in units and passes the numbers, so this file never
// sees a font.
//
// The Fleet levels are the shared fleet-plan.js levels in the same order,
// with the same never-yield rule (the name and the status icon stay), at
// Win98 metrics: Platinum's px times 0.75. Every value a row gives up stays
// in the Properties sheet and the row's tooltip.
//
// m, the caller's measurements (units):
//   border    the window's horizontal chrome around the list's rows
//   chrome    its vertical chrome besides the menu bar, the column headers
//             and the rows (caption, well, status bar, frame)
//   rows      host rows to plan for (8 while loading, so the size holds)
//   nameW     the widest host name
//   head      {id: [label widths, longest label first]}
//   fsLabelW  the widest non-root filesystem label of a trusted host, or 0
//   pctW, tempW, failedW, notesW   "100%", "100°", "14", "14 failed"
//   upLongW, upShortW              the widest uptime or "seen" text, each form

var C = {
    MENU: 19, COLH: 17, ROW: 18, ROW_MIN: 16, SB: 16, ICON: 19, NAME_MAX: 90, FS_MAX: 52,
    BAR_GAP: 4, MINW: 112, CELL_W: 96, CELL_H: 64, ICONS_PAD: 4
};

var LEVELS = [
    {pad: 6, bar: 42, up: "long", cols: ["cpu", "mem", "disk", "temp", "failed", "up"], gave: ""},
    {pad: 4, bar: 33, up: "long", cols: ["cpu", "mem", "disk", "temp", "failed", "up"], gave: "spacing"},
    {pad: 4, bar: 22, up: "short", cols: ["cpu", "mem", "disk", "temp", "failed", "up"], gave: "bar length, uptime to days"},
    {pad: 3, bar: 22, barCols: ["disk"], up: "short", cols: ["cpu", "mem", "disk", "temp", "failed", "up"], gave: "CPU and memory bars (numbers stay)"},
    {pad: 3, bar: 0, up: "short", cols: ["cpu", "mem", "disk", "temp", "failed", "up"], gave: "bars (numbers stay)"},
    {pad: 3, bar: 0, up: "short", cols: ["cpu", "mem", "disk", "temp", "failed"], gave: "uptime column (in Properties)"},
    {pad: 2, bar: 0, up: "short", cols: ["cpu", "mem", "disk", "notes"], gave: "temp and failed merge into Notes"},
    {pad: 2, bar: 0, up: "short", cols: ["why"], gave: "values merge into one reason"},
    {pad: 2, bar: 0, up: "short", cols: [], gave: "the reason (in Properties and the tooltip)"}
];

var HEAD = {
    cpu: ["CPU"], mem: ["Memory", "Mem"], disk: ["Disk"], temp: ["Temp"], failed: ["Failed", "Fail"],
    up: ["Uptime", "Up"], notes: ["Notes"], why: ["Status"]
};

function barOn(level, id) {
    return level.bar > 0 && (!level.barCols || level.barCols.indexOf(id) >= 0);
}

function headWidth(m, id, level) {
    var widths = (m.head && m.head[id]) || [0];
    return level.bar >= 33 ? widths[0] : Math.min.apply(null, widths);
}

function colWidth(id, level, m) {
    var p = 2 * level.pad;
    var label = headWidth(m, id, level);
    if (id === "cpu" || id === "mem" || id === "disk") {
        var bar = barOn(level, id);
        var fs = id === "disk" && bar ? m.fsLabelW || 0 : 0;
        return p + Math.max(label, fs + (bar ? level.bar + C.BAR_GAP : 0) + m.pctW);
    }
    if (id === "temp") return p + Math.max(label, m.tempW);
    if (id === "failed") return p + Math.max(label, m.failedW);
    if (id === "up") return p + Math.max(label, level.up === "long" ? m.upLongW : m.upShortW);
    if (id === "notes") return p + Math.max(label, m.notesW);
    if (id === "why") return p + 48;   // a minimum; it takes the rest
    return 0;
}

// The Name column: the 16-u host icon and its gap, the name, the padding.
function nameWidth(level, m) {
    return C.ICON + Math.min(m.nameW, C.NAME_MAX) + 2 * level.pad + 2;
}

// The label a header shows in its column: the first that fits.
function headLabel(id, level, m, width) {
    var labels = HEAD[id] || [id];
    var widths = (m.head && m.head[id]) || [];
    for (var i = 0; i < labels.length; i++) {
        if (i === labels.length - 1 || (widths[i] || 0) + 2 * level.pad <= width + 0.5) return labels[i];
    }
    return labels[0];
}

// Large Icons: 96 x 64-u cells, as many columns as fit (at least one).
function iconGrid(innerW, n) {
    var cols = Math.max(1, Math.floor(Math.max(0, innerW - 2 * C.ICONS_PAD) / C.CELL_W));
    var cellW = Math.max(1, Math.floor(Math.max(0, innerW - 2 * C.ICONS_PAD) / cols));
    var rows = Math.ceil(Math.max(0, n) / cols);
    return {cols: cols, cellW: cellW, rows: rows, height: rows * C.CELL_H + 2 * C.ICONS_PAD};
}

/**
 * Height decides structure, in the shared order: the rows shrink 18 -> 16 u,
 * then the menu bar folds into the caption's control menu (Win98's place
 * for a window's commands), then the list scrolls and the caption names
 * the problem hosts.
 * @param {?number} h the window's height, or null for its natural height
 * @param {object} m measurements
 * @param {{icons?: boolean, iconsH?: number}} opt Large Icons: the grid's
 *   height replaces the rows, and the column headers go.
 */
function heightPlan(h, m, opt) {
    var o = opt || {};
    var rows = Math.max(1, m.rows || 8);
    var head = o.icons ? 0 : C.COLH;
    var fixed = m.chrome + C.MENU + head;
    var rowH = C.ROW, menuInCap = false, scrolls = false, listH = null;
    var need = function (rh) { return o.icons ? (o.iconsH || 0) : rows * rh; };
    if (h !== null && h !== undefined) {
        if (fixed + need(C.ROW) > h) rowH = C.ROW_MIN;
        if (fixed + need(C.ROW_MIN) > h) menuInCap = true;
        listH = Math.max(0, h - fixed + (menuInCap ? C.MENU : 0));
        scrolls = need(rowH) > listH + 1e-9;
    }
    return {rows: rows, rowH: rowH, menuInCap: menuInCap, scrolls: scrolls, listH: listH,
        natural: fixed + need(C.ROW)};
}

/**
 * @param {number} w the window's width
 * @param {?number} h its height, or null for its natural height
 * @param {object} m measurements
 * @param {object} opt see heightPlan
 */
function plan(w, h, m, opt) {
    var inner = w - m.border;
    var height = heightPlan(h, m, opt);
    var sb = height.scrolls ? C.SB : 0;
    for (var i = 0; i < LEVELS.length; i++) {
        var level = LEVELS[i];
        var widths = {};
        var sum = 0;
        for (var c = 0; c < level.cols.length; c++) {
            var id = level.cols[c];
            widths[id] = colWidth(id, level, m);
            sum += widths[id];
        }
        var nw = nameWidth(level, m);
        var total = nw + sum + sb;
        if (total <= inner || i === LEVELS.length - 1) {
            // The spare width goes to the reason column, else to the name,
            // so the row always ends on the list's right edge.
            var spare = Math.max(0, inner - total);
            var nameCol = nw;
            if (level.cols.indexOf("why") >= 0) widths.why += spare;
            else nameCol += spare;
            var gave = [];
            for (var j = 1; j <= i; j++) gave.push(LEVELS[j].gave);
            return {
                level: i, pad: level.pad, bar: level.bar, barCols: level.barCols || null, up: level.up,
                cols: level.cols.slice(), widths: widths, nameW: nameCol,
                rowH: height.rowH, menuInCap: height.menuInCap, scrolls: height.scrolls, listH: height.listH,
                sb: sb, natural: Math.ceil(total + m.border), naturalH: height.natural,
                fits: total <= inner, gave: gave
            };
        }
    }
    return null;
}

// The first variant that fits the room, else the last (the shortest).
function fit(variants, room, measure) {
    for (var i = 0; i < variants.length; i++) if (measure(variants[i]) <= room) return variants[i];
    return variants[variants.length - 1];
}

// ---------------------------------------------------------------- places
// The standalone window and the glance space's first slot share margins, so
// Fleet stands in one place in both hosts: 6 u from the right edge and 4 u
// above the taskbar (Platinum's 8 and 6 px at 1.5), where the tray windows
// rise. The glance space's margins and gaps for glance-plan.js.
var GP = {TOP: 4, RIGHT: 6, BOTTOM: 4, LEFT: 6, GAP: 9, GAP_MIN: 4, SB: 16, TIGHT_W: 450, TIGHT_H: 300};

// The standalone window in a work area W x H (above the taskbar).
function standaloneRect(W, H, w, h) {
    var ww = Math.min(w, Math.max(0, W - GP.LEFT - GP.RIGHT));
    var hh = Math.min(h, Math.max(0, H - GP.TOP - GP.BOTTOM));
    return {x: Math.max(0, W - GP.RIGHT - ww), y: Math.max(0, H - GP.BOTTOM - hh), w: ww, h: hh};
}

// The Properties sheet: beside Fleet on the left, bottom-aligned, 300 u
// wide and at least 360 u tall (one size for every tab, as Win98's sheets
// had). With less than 220 u to the left it opens over Fleet. Always inside
// area ({x, y, w, h}).
var PROPS = {W: 300, MINW: 220, H: 360};
function sheetRect(fr, area) {
    var roomL = fr.x - area.x - GP.GAP;
    var w = Math.min(PROPS.W, Math.max(PROPS.MINW, roomL), area.w);
    var h = Math.min(area.h, Math.max(fr.h, PROPS.H));
    if (roomL >= PROPS.MINW) return {x: fr.x - GP.GAP - w, y: Math.max(area.y, fr.y + fr.h - h), w: w, h: h, beside: true};
    return {x: Math.max(area.x, Math.min(fr.x + fr.w - w, area.x + area.w - w)),
        y: Math.max(area.y, Math.min(fr.y + fr.h - h, area.y + area.h - h)), w: w, h: h, beside: false};
}

// ---------------------------------------------------------------- motion
// Win98's caption animation from the Glance taskbar button, on the shared
// glance-plan.js frameAt("zoom", ...) timing: frames 0-8 draw one caption
// per accessory, frame 9 the windows (150 ms); the dismiss is the mirror;
// reduced motion is the cut. The caption is the newest of the shared
// trailing outlines (Win98 drew one rectangle, not a trail).
function captionProgress(frame) {
    return frame && frame.outlines && frame.outlines.length ? frame.outlines[frame.outlines.length - 1] : null;
}
// One caption bar: the origin rect moved toward the accessory's caption.
function captionRect(origin, target, p) {
    return {
        x: Math.round(origin.x + (target.x - origin.x) * p),
        y: Math.round(origin.y + (target.y - origin.y) * p),
        w: Math.max(1, Math.round(origin.w + (target.w - origin.w) * p)),
        h: Math.max(1, Math.round(origin.h + (target.h - origin.h) * p))
    };
}
