.pragma library

// The Fleet view's layout as a pure function of its window's size: width
// decides the columns, height decides the row height, where the summary
// sits and whether the list scrolls. Ported from the approved mock's
// hudPlan (/tmp/hud-mock/hud.js); the thresholds are the mock's, measured
// again in Quickshell with ChicagoFLF through the caller's measurements.
//
// The caller measures text; this file never sees a font. m:
//   border     the window's side chrome (its edges and bevel)
//   chrome     its vertical chrome besides the 16-px title (edges, rules);
//              defaults to the mock's border + 3
//   rows       host rows to plan for (8 while loading, so the size holds)
//   nameW      widest host name at 14 px, capped by the caller (120)
//   head       {id: [label widths at 12 px, longest label first]}
//   fsLabelW   widest non-root filesystem label at 11 px + 4, or 0
//   pctW, tempW, failedW, notesW   "100%", "100°", "14", "14 failed" at 12 px
//   upLongW, upShortW   widest uptime or "seen" text in each form at 12 px

// Every size is an even number of logical pixels, so at scale 1.5 each
// edge lands on a whole device pixel and every hair stays sharp. The mock's
// 19-px header and short row and its 15-px footer became 20, 20 and 16.
var C = {
    TITLE: 16, INFO: 24, COLH: 20, FOOT: 16, ROW: 24, ROW_MIN: 20,
    SB: 16, TRI: 16, LAMP: 20, BAR_GAP: 6, MINW: 150
};

function even(v) { return Math.ceil(v / 2 - 1e-6) * 2; }

// Each level gives up one more thing. The name and the status light never
// yield; every value that leaves the row stays in the drill-down.
var LEVELS = [
    {pad: 8, bar: 56, up: "long", cols: ["cpu", "mem", "disk", "temp", "failed", "up"], gave: ""},
    {pad: 5, bar: 44, up: "long", cols: ["cpu", "mem", "disk", "temp", "failed", "up"], gave: "spacing"},
    {pad: 5, bar: 30, up: "short", cols: ["cpu", "mem", "disk", "temp", "failed", "up"], gave: "bar length, uptime to days"},
    // 30 px is the shortest bar that still reads as a proportion. Below it
    // bars go whole, CPU and memory first: disk is the only one with a tone.
    {pad: 4, bar: 30, barCols: ["disk"], up: "short", cols: ["cpu", "mem", "disk", "temp", "failed", "up"], gave: "CPU and memory bars"},
    {pad: 4, bar: 0, up: "short", cols: ["cpu", "mem", "disk", "temp", "failed", "up"], gave: "bars"},
    {pad: 4, bar: 0, up: "short", cols: ["cpu", "mem", "disk", "temp", "failed"], gave: "uptime column"},
    {pad: 3, bar: 0, up: "short", cols: ["cpu", "mem", "disk", "notes"], gave: "temp and failed merge into Notes"},
    {pad: 3, bar: 0, up: "short", cols: ["why"], gave: "values merge into one reason"},
    {pad: 2, bar: 0, up: "short", cols: [], gave: "the reason"}
];

var HEAD = {
    cpu: ["CPU"], mem: ["Memory", "Mem"], disk: ["Disk"], temp: ["Temp"], failed: ["Failed", "Fail"],
    up: ["Uptime", "Up"], notes: ["Notes"], why: ["Status"]
};

function barOn(level, id) {
    return level.bar > 0 && (!level.barCols || level.barCols.indexOf(id) >= 0);
}

function headWidth(m, id, level) {
    const widths = (m.head && m.head[id]) || [0];
    // The full label while bars are long; the shortest one after that.
    return level.bar >= 44 ? widths[0] : Math.min.apply(null, widths);
}

function colWidth(id, level, m) {
    const p = 2 * level.pad;
    const label = headWidth(m, id, level);
    if (id === "cpu" || id === "mem" || id === "disk") {
        const bar = barOn(level, id);
        const fs = id === "disk" && bar ? m.fsLabelW || 0 : 0;
        return p + Math.max(label, fs + (bar ? level.bar + C.BAR_GAP : 0) + m.pctW);
    }
    if (id === "temp") return p + Math.max(label, m.tempW);
    if (id === "failed") return p + Math.max(label, m.failedW);
    if (id === "up") return p + Math.max(label, level.up === "long" ? m.upLongW : m.upShortW);
    if (id === "notes") return p + Math.max(label, m.notesW);
    if (id === "why") return p + 64;   // a minimum; it takes the rest
    return 0;
}

// The label a header shows in its column: the first that fits.
function headLabel(id, level, m, width) {
    const labels = HEAD[id] || [id];
    const widths = (m.head && m.head[id]) || [];
    for (let i = 0; i < labels.length; i++) {
        if (i === labels.length - 1 || (widths[i] || 0) + 2 * level.pad <= width + 0.5) return labels[i];
    }
    return labels[0];
}

// Rows, the summary's place and the scroll bar, for a window h tall
// (null: as tall as it needs). detailH is an open host's drill-down.
function heightPlan(h, m, detailH) {
    const rows = Math.max(1, m.rows || 8);
    const fixed = C.TITLE + C.INFO + C.COLH + C.FOOT + (m.chrome !== undefined ? m.chrome : m.border + 3);
    let rowH = C.ROW, infoInTitle = false, scrolls = false, listH = null;
    if (h !== null && h !== undefined) {
        if (fixed + rows * C.ROW > h) rowH = C.ROW_MIN;
        if (fixed + rows * C.ROW_MIN > h) infoInTitle = true;
        listH = Math.max(0, h - fixed + (infoInTitle ? C.INFO : 0));
        scrolls = rows * rowH + (detailH || 0) > listH;
    }
    return {rows: rows, rowH: rowH, infoInTitle: infoInTitle, scrolls: scrolls, listH: listH};
}

/**
 * @param {number} w the window's width
 * @param {?number} h the window's height, or null for its natural height
 * @param {object} m measurements (see the top of this file)
 * @param {{detailH?: number}} opt
 */
function plan(w, h, m, opt) {
    const options = opt || {};
    const inner = w - m.border;
    const height = heightPlan(h, m, options.detailH || 0);
    const sb = height.scrolls ? C.SB : 0;
    for (let i = 0; i < LEVELS.length; i++) {
        const level = LEVELS[i];
        const widths = {};
        let sum = 0;
        for (const id of level.cols) { widths[id] = even(colWidth(id, level, m)); sum += widths[id]; }
        const nameW = even(m.nameW + 2 * level.pad);
        const total = C.TRI + C.LAMP + nameW + sum + sb;
        if (total <= inner || i === LEVELS.length - 1) {
            // The spare width goes to the reason column, else to the name, so
            // the row always ends on the window's right edge.
            const spare = Math.max(0, inner - total);
            let nameCol = nameW;
            if (level.cols.indexOf("why") >= 0) widths.why += spare;
            else nameCol += spare;
            const gave = [];
            for (let j = 1; j <= i; j++) gave.push(LEVELS[j].gave);
            return {
                level: i, pad: level.pad, bar: level.bar, barCols: level.barCols || null, up: level.up,
                cols: level.cols.slice(), widths: widths, nameW: nameCol,
                rowH: height.rowH, infoInTitle: height.infoInTitle, scrolls: height.scrolls, listH: height.listH,
                sb: sb, natural: Math.ceil(total + m.border), fits: total <= inner, gave: gave
            };
        }
    }
    return null;
}

// The narrowest and shortest a window may be dragged.
function minimum(m) {
    return {w: C.MINW, h: C.TITLE + C.COLH + C.FOOT + 2 * C.ROW_MIN + 8};
}

// The first variant that fits the room, else the last (the shortest).
function fit(variants, room, measure) {
    for (const text of variants) if (measure(text) <= room) return text;
    return variants[variants.length - 1];
}
