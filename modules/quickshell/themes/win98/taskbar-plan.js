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
// page first; the focused window last), then tray icons move into the tray
// chevron in bar-plan.js's overflow order, dictation last. Window titles
// and the Start label are readouts; every button is a control and moves
// into a chevron menu with its real name, never away.

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
// bar-plan.js overflowOrder, with dictation last.
var TRAY_OVERFLOW = ["oci", "disk", "builder", "bri", "bt", "wifi", "ntf", "vol", "dict"];

// A tray icon is 20 u; a badge wider than one digit adds 4 u a digit.
function trayWidth(badge) {
    var b = badge || "";
    return TICON + (b.length > 1 ? (b.length - 1) * 4 : 0);
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
    if (f) out.push(f.i);
    return layout(W, on, wins, pages, out, trayOut, input);
}

function layout(W, on, wins, pages, outW, outT, input) {
    var has = function (s) { return on.indexOf(s) >= 0; };
    var measure = input.measure;
    var startW = has("startIcon") ? START_ICON : startWidth(measure);
    var tray = input.tray.filter(function (t) { return outT.indexOf(t.id) < 0; });
    var clockText = has("clockShort") || !input.clock.ampm ? input.clock.time : input.clock.time + " " + input.clock.ampm;
    var trayW = 3 + 3 + tray.reduce(function (s, t) { return s + trayWidth(t.badge); }, 0)
        + (outT.length ? CHEV + 2 : 0) + 6 + measure(clockText, false) + 5 + 2;
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
    var taskFixed = groups.length * (BAND + TAG + GAP) + (outW.length ? CHEV + GAP : 0);
    var avail = W - 2 - 2 - startW - GAP - dictW - trayW - 3;
    var n = shown.length;
    var perBtn = has("titles") ? TBTN_ICON : TBTN_MIN;
    var room = avail - taskFixed - n * GAP;
    var fits = room >= n * perBtn;
    var bw = Math.max(perBtn, Math.min(TBTN_MAX, Math.floor(room / Math.max(1, n))));
    var steps = on.slice();
    if (outW.length) steps.push("windows»");
    if (outT.length) steps.push("tray»");
    return {
        fits: fits,
        steps: steps,
        startW: startW,
        startIcon: has("startIcon"),
        tray: tray.map(function (t) { return t.id; }),
        trayOut: outT.slice(),
        clockText: clockText,
        dictShow: dictShow,
        dictTextShow: !has("dictText"),
        groups: groups,
        taskOut: outW.slice(),
        bw: bw,
        icons: bw < LABEL_MIN,
        width: W
    };
}

// The windows chevron lists its windows by page.
function overflowWindows(windows, taskOut) {
    return taskOut.slice().sort(function (a, b) {
        return windows[a].page - windows[b].page || a - b;
    });
}
