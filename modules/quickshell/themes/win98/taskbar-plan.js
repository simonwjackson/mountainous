.pragma library
// The Win98 taskbar's layout as one pure function of its width, ported
// from the approved mock (/tmp/win98-mock/win98.js plan()). Every length
// is in Win98 units (1 u = 2 physical px).
//
// Steps yield in order, and nothing is removed:
//   1. clockShort  the clock drops "PM"
//   2. dictText    the dictation band drops its status text (its buttons stay)
//   3. titles      window buttons drop their titles (icons only)
//   4. startIcon   the Start button drops its label
// Then windows move into the windows chevron (other pages first, the last
// page first), then tray icons move into the tray chevron in bar-plan.js's
// overflow order, dictation last, then the focused window. Then the
// readouts leave the bar for the tray chevron: the clock, then the battery.
// Then two last structures:
//   compact  Start and one chevron, which holds the tray controls, the
//            windows, the clock and the battery;
//   start    Start alone; its menu gains a Taskbar cascade with the tray
//            controls, the clock and the battery (Start > Windows already
//            lists every window).
// Window titles and the Start label are readouts; every button is a
// control and moves into a menu with its real name, never away.
//
// Extras: the Glance button (while the glance space shows) and a minimized
// Fleet window's button stand in their own band at the right end of the
// task area, after the windows. They keep their place through every step
// of the full structure (icons only once titles go); in the compact and
// start structures they move into the same menu as the windows.
//
// The plan fits at every width from MIN_WIDTH (28 u, 37.3 logical px at
// scale 1.5) up. Below that only Start remains, as wide as the bar allows;
// everything is still reachable through it.

var START_ICON = 24;
var BAND = 12;
var CHEV = 12;
var TAG = 16;
var TICON = 20;
var TBTN_MAX = 160;
var TBTN_MIN = 72;
var TBTN_ICON = 26;
var GAP = 3;
var LABEL_MIN = 46;
var STEPS = ["clockShort", "dictText", "titles", "startIcon"];
var MIN_WIDTH = 2 + START_ICON + 2;
// bar-plan.js overflowOrder, with dictation last.
var TRAY_OVERFLOW = ["oci", "disk", "fleet", "builder", "bri", "bt", "wifi", "ntf", "vol", "dict"];

// A tray icon is 20 u; a badge wider than one digit adds 4 u a digit.
function trayWidth(badge) {
    var b = badge || "";
    return TICON + (b.length > 1 ? (b.length - 1) * 4 : 0);
}

// An extra button: its icon and label, at most a window button's width.
function extraWidth(label, bold, measure, iconsOnly) {
    if (iconsOnly) return TBTN_ICON;
    return Math.min(TBTN_MAX, 3 + 16 + 3 + measure(label, !!bold) + 5);
}

function startWidth(measure) {
    return 3 + 16 + 3 + measure("Start", true) + 5;
}

// input: {
//   windows: [{ page, focused }] in lane order,
//   showingPage,
//   tray: [{ id, badge }] in tray order (dict first when shown),
//   clock: { time, ampm },
//   dict: { visible, failed, canRetry, text },
//   extras: [{ id, label, bold }] (optional; see above),
//   measure(text, bold) -> whole units
// }
function plan(W, input) {
    var wins = input.windows.map(function (w, i) {
        return { page: w.page, focused: !!w.focused, i: i };
    });
    var pages = [];
    wins.forEach(function (w) { if (pages.indexOf(w.page) < 0) pages.push(w.page); });
    pages.sort(function (a, b) { return a - b; });
    for (var n = 0; n <= STEPS.length; n++) {
        var r = layout(W, STEPS.slice(0, n), wins, pages, [], [], input);
        if (r.fits) return r;
    }
    var on = STEPS.slice();
    var out = [];
    var trayOut = [];
    var order = wins.slice().sort(function (a, b) {
        var sa = a.page === input.showingPage ? 1 : 0;
        var sb = b.page === input.showingPage ? 1 : 0;
        return (sa - sb) || (b.page - a.page) || (b.i - a.i);
    });
    for (var k = 0; k < order.length; k++) {
        if (order[k].focused) continue;
        out.push(order[k].i);
        var r2 = layout(W, on, wins, pages, out, trayOut, input);
        if (r2.fits) return r2;
    }
    var present = input.tray.map(function (t) { return t.id; });
    for (var t = 0; t < TRAY_OVERFLOW.length; t++) {
        if (present.indexOf(TRAY_OVERFLOW[t]) < 0) continue;
        trayOut.push(TRAY_OVERFLOW[t]);
        var r3 = layout(W, on, wins, pages, out, trayOut, input);
        if (r3.fits) return r3;
    }
    var f = wins.filter(function (w) { return w.focused; })[0];
    if (f) {
        out.push(f.i);
        var r4 = layout(W, on, wins, pages, out, trayOut, input);
        if (r4.fits) return r4;
    }
    // The readouts go before the bar changes shape.
    var r5 = layout(W, on, wins, pages, out, trayOut, input, { clockOut: true });
    if (r5.fits) return r5;
    if (present.indexOf("bat") >= 0) trayOut.push("bat");
    var r6 = layout(W, on, wins, pages, out, trayOut, input, { clockOut: true });
    if (r6.fits) return r6;
    var r7 = layout(W, on, wins, pages, out, trayOut, input, { clockOut: true, structure: "compact" });
    if (r7.fits) return r7;
    return layout(W, on, wins, pages, out, trayOut, input, { clockOut: true, structure: "start" });
}

function layout(W, on, wins, pages, outW, outT, input, opts) {
    var o = opts || {};
    var structure = o.structure || "full";
    var has = function (s) { return on.indexOf(s) >= 0; };
    var measure = input.measure;
    var startW = has("startIcon") ? START_ICON : startWidth(measure);
    var tray = input.tray.filter(function (t) { return outT.indexOf(t.id) < 0; });
    var clockText = has("clockShort") || !input.clock.ampm ? input.clock.time : input.clock.time + " " + input.clock.ampm;
    var chevron = outT.length > 0 || !!o.clockOut
        || (structure === "compact" && (outW.length > 0 || (input.extras || []).length > 0));
    var trayW = structure === "start" ? 0
        : 3 + 3 + tray.reduce(function (s, t) { return s + trayWidth(t.badge); }, 0)
            + (chevron ? CHEV + 2 : 0) + (o.clockOut ? 0 : 6 + measure(clockText, false) + 5) + 2;
    var dict = input.dict || { visible: false };
    var dictW = 0;
    var dictShow = false;
    if (dict.visible && outT.indexOf("dict") < 0) {
        var acts = dict.failed ? (dict.canRetry ? measure("Retry", false) + 14 + 4 : 0) + measure("Dismiss", false) + 14 + 4 : 0;
        dictShow = !has("dictText") || acts > 0;
        dictW = dictShow ? BAND + (has("dictText") ? 0 : measure(dict.text, false) + 6) + acts : 0;
    }
    var shown = wins.filter(function (w) { return outW.indexOf(w.i) < 0; });
    var groups = pages.map(function (p) {
        return { page: p, windows: shown.filter(function (w) { return w.page === p; }).map(function (w) { return w.i; }) };
    }).filter(function (g) { return g.windows.length > 0; });
    var tasksChevron = outW.length > 0 && structure === "full";
    var extras = input.extras || [];
    var extraW = {};
    var extrasW = 0;
    if (structure === "full" && extras.length) {
        extrasW = BAND;
        extras.forEach(function (x) {
            extraW[x.id] = extraWidth(x.label, x.bold, measure, has("titles"));
            extrasW += extraW[x.id] + GAP;
        });
    }
    var taskFixed = groups.length * (BAND + TAG + GAP) + (tasksChevron ? CHEV + GAP : 0) + extrasW;
    var n = shown.length;
    var perBtn = has("titles") ? TBTN_ICON : TBTN_MIN;
    // Start alone: 2 u each side while there is room, then less.
    var startX = structure === "start" ? Math.max(0, Math.min(2, Math.floor((W - 1) / 2))) : 2;
    if (structure === "start") startW = Math.max(1, Math.min(startW, W - 2 * startX));
    var avail = W - 2 - 2 - startW - GAP - dictW - trayW - 3;
    var room = avail - taskFixed - n * GAP;
    var fits = structure === "start" ? W >= MIN_WIDTH : avail >= 0 && room >= n * perBtn;
    var bw = Math.max(perBtn, Math.min(TBTN_MAX, Math.floor(room / Math.max(1, n))));
    var steps = on.slice();
    if (outW.length) steps.push("windows»");
    if (outT.length) steps.push("tray»");
    if (o.clockOut) steps.push("clockOut");
    if (outT.indexOf("bat") >= 0) steps.push("batteryOut");
    if (structure !== "full") steps.push("compact");
    if (structure === "start") steps.push("start");
    // Where each part stands, in units, as the bar draws it.
    var trayBox = structure === "start" ? null : { x: W - 2 - (trayW - 3), w: trayW - 3 };
    var right = trayBox ? trayBox.x - 3 : W - 2;
    var dictBox = dictShow && structure !== "start" ? { x: right - dictW, w: dictW } : null;
    var tasksAll = Math.max(0, (dictBox ? dictBox.x : right) - 2 - startW);
    var tasksBox = { x: 2 + startW, w: Math.max(0, tasksAll - extrasW) };
    var extrasBox = extrasW > 0 ? { x: tasksBox.x + tasksBox.w, w: Math.min(extrasW, tasksAll) } : null;
    return {
        fits: fits,
        steps: steps,
        structure: structure,
        startW: startW,
        startIcon: has("startIcon"),
        tray: tray.map(function (t) { return t.id; }),
        trayOut: outT.slice(),
        clockOut: !!o.clockOut,
        chevron: chevron && structure !== "start",
        tasksChevron: tasksChevron,
        clockText: clockText,
        dictShow: dictShow && structure !== "start",
        dictTextShow: !has("dictText"),
        groups: groups,
        taskOut: outW.slice(),
        bw: bw,
        extras: structure === "full" ? extras.map(function (x) { return x.id; }) : [],
        extrasOut: structure === "full" ? [] : extras.map(function (x) { return x.id; }),
        extraW: extraW,
        icons: bw < LABEL_MIN,
        startX: startX,
        boxes: { start: { x: startX, w: startW }, tasks: tasksBox, extras: extrasBox, dict: dictBox, tray: trayBox,
                 used: taskFixed - extrasW + n * (bw + GAP) },
        width: W
    };
}

// The windows chevron lists its windows by page; inside a page, in the
// order they left the bar (the mock's stable sort of its overflow list).
function overflowWindows(windows, taskOut) {
    return taskOut.slice().sort(function (a, b) {
        return windows[a].page - windows[b].page || taskOut.indexOf(a) - taskOut.indexOf(b);
    });
}
