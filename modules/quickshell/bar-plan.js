.pragma library

// The Platinum top bar's layout as one pure function of its width:
// direction A, "Quiet glyphs" (the approved mock, /tmp/bar-calm). The
// icons carry the values (speaker waves, sun rays, a cloud meter, the
// battery fill, a dot on the bell and on a busy hammer). A readout is on
// the bar only while it warns: an OCI profile at 50% or more, a disk
// issue count, the fleet's problem count, a builder failure, an urgent
// or unsynced notification count, a low battery's percent. The Wi-Fi "!"
// (radio on, no network) never yields. The Application menu's name shows
// only when the window title does not already name the app.
//
// The ladder, in order:
//   1. Spacing yields (pad 8 -> 5, gap 2 -> 0).
//   2. Readouts yield in YIELD_ORDER. The window title gives way to the
//      numbers: a warning outlasts it.
//   3. Controls move into » in OVERFLOW_ORDER, then dictation's Retry and
//      Dismiss together (one group).
//   4. Padding goes, one logical pixel at a time.
//   5. Below that floor (191 px for the captured metrics), battery, clock
//      and Application move into ». Clock clearance and edges go last.
//      Below mark + » the Apple menu is »'s first row, and below »'s own
//      width » shrinks to the container.
// A control hides only when its hardware or service is missing; it never
// leaves the bar for any other reason except into ».
//
// metrics (raw content widths; the planner adds every pad and gap, the
// 6 px between an icon and its readout included):
//   controls: [{id, iconWidth, readoutWidth, compactReadoutWidth?}]
//     readoutWidth is what the control shows while it warns (0 when calm);
//     compactReadoutWidth (default 0) is what stays once its words yield,
//     e.g. the disk issue count without " issue".
//   markWidth, titleWidth, titleMinWidth, dictationActionsWidth? (default 0)
//   clockWidth          the time alone ("12:59"); the date is in its menu
//   chordWidth          Super+O's key caps with their names; 0 without it
//   chordCompactWidth?  the key caps alone (default chordWidth)
//   batteryWidth        the battery icon; 0 without a battery
//   batteryReadoutWidth? the percent box, only while it warns (default 0)
//   appIconWidth, appNameWidth (0 while the title names the app)
//   overflowWidth       »
//
// Every item is drawn as an even number of logical pixels
// (PlatinumMetrics.even), so the plan counts each one the same way and
// what it fits is what the bar draws.
/**
 * @typedef {'bt'|'wifi'|'vol'|'bri'|'oci'|'disk'|'fleet'|'builder'|'ntf'} ControlId
 * @typedef {{id: ControlId, iconWidth: number, readoutWidth: number, compactReadoutWidth?: number}} Control
 */

var YIELD_ORDER = ["space", "appName", "diskLabel", "uncentre", "titleMin", "builderLabel",
    "ociNumber", "ntfCount", "fleetCount", "batteryPct"];
var OVERFLOW_ORDER = ["oci", "disk", "fleet", "builder", "bri", "bt", "wifi", "ntf", "vol"];
var READOUTS = {oci: "ociNumber", disk: "diskLabel", fleet: "fleetCount", builder: "builderLabel", ntf: "ntfCount"};
var EDGE = 6, INSIDE_GAP = 6, CLOCK_GAP = 16, TITLE_STUB = 56;
var PAD = 8, PAD_TIGHT = 5, GAP = 2;
var COMPACT_ORDER = ["battery", "clock", "app"];

function even(v) { return Math.ceil(v / 2 - 1e-6) * 2; }

function dimension(value, name) {
    if (typeof value !== "number" || Number.isNaN(value) || value < 0) throw new Error("Invalid " + name + " width");
}

function validate(width, metrics) {
    dimension(width, "container");
    if (!metrics || !Array.isArray(metrics.controls)) throw new Error("Invalid controls");
    for (const name of ["markWidth", "titleWidth", "titleMinWidth", "clockWidth", "chordWidth", "batteryWidth",
        "appIconWidth", "appNameWidth", "overflowWidth"]) dimension(metrics[name], name);
    for (const name of ["dictationActionsWidth", "chordCompactWidth", "batteryReadoutWidth"])
        if (metrics[name] !== undefined) dimension(metrics[name], name);
    const ids = [];
    for (const control of metrics.controls) {
        if (!control || OVERFLOW_ORDER.indexOf(control.id) < 0 || ids.indexOf(control.id) >= 0) throw new Error("Invalid or duplicate control");
        ids.push(control.id);
        dimension(control.iconWidth, "control icon");
        dimension(control.readoutWidth, "control readout");
        if (control.compactReadoutWidth !== undefined) dimension(control.compactReadoutWidth, "compact readout");
    }
}

/**
 * @param {number} width the bar's logical width
 * @param {object} metrics see above
 */
function plan(width, metrics) {
    validate(width, metrics);
    if (!(metrics.chordWidth > 0)) return fit(width, metrics, 0, false);
    // Super+O replaces the clock with key caps. Their names are a readout:
    // they show while the whole hint takes at most half the bar, or while
    // they fit without making anything but spacing yield.
    const named = metrics.chordWidth;
    const caps = metrics.chordCompactWidth > 0 ? Math.min(metrics.chordCompactWidth, named) : named;
    if (named <= width * 0.5) return fit(width, metrics, named, true);
    const capsPlan = fit(width, metrics, caps, false);
    const namedPlan = fit(width, metrics, named, true);
    const calm = namedPlan.steps.filter(function (s) { return s !== "space"; }).length === 0;
    return calm && namedPlan.steps.length <= capsPlan.steps.length ? namedPlan : capsPlan;
}

function fit(width, metrics, chordW, chordNames) {
    const actionsW = metrics.dictationActionsWidth || 0;
    const batteryReadout = metrics.batteryWidth > 0 ? (metrics.batteryReadoutWidth || 0) : 0;
    const hasApp = metrics.appIconWidth > 0 || metrics.appNameWidth > 0;
    // The right group's items in bar order: the controls, then the battery
    // and the Application menu. » stands between the controls and the
    // battery; the clock (or the chord) leads the group once uncentred.
    const items = metrics.controls.map(function (c) {
        return {id: c.id, icon: c.iconWidth, readout: c.readoutWidth,
            compact: Math.min(c.readoutWidth, c.compactReadoutWidth || 0), key: READOUTS[c.id], control: true};
    });
    if (metrics.batteryWidth > 0) items.push({id: "battery", icon: metrics.batteryWidth, readout: batteryReadout, compact: 0, key: "batteryPct"});
    if (hasApp) items.push({id: "app", icon: metrics.appIconWidth, readout: metrics.appNameWidth, compact: 0, key: "appName"});
    // A step that would save no space is not taken.
    const steps = YIELD_ORDER.filter(function (k) {
        if (k === "space" || k === "uncentre") return true;
        if (k === "titleMin") return metrics.titleWidth > 0;
        return items.some(function (it) { return it.key === k && it.compact < it.readout; });
    });

    for (let count = 0; count <= steps.length; count++) {
        const applied = steps.slice(0, count);
        const yielded = function (k) { return applied.indexOf(k) >= 0; };
        let pad = yielded("space") ? PAD_TIGHT : PAD;
        const gap = yielded("space") ? 0 : GAP;
        const centred = !yielded("uncentre");
        let actionsOnBar = actionsW > 0;
        const centreW = function () { return chordW > 0 ? chordW : even(2 * pad + metrics.clockWidth); };
        const keptLeft = function () {
            const mark = EDGE + even(2 * pad + metrics.markWidth);
            const itemGap = metrics.titleWidth > 0 || actionsOnBar ? gap : 0;
            return mark + itemGap + (actionsOnBar ? INSIDE_GAP + actionsW : 0);
        };
        const leftTextMin = yielded("titleMin") ? 0 : Math.min(metrics.titleMinWidth, metrics.titleWidth);
        const shown = function (it) { return yielded(it.key) ? it.compact : it.readout; };
        const itemW = function (it) {
            const r = shown(it);
            return even(2 * pad + it.icon + (r > 0 ? INSIDE_GAP + r : 0));
        };
        const rightW = function (bar, overflow) {
            let total = EDGE, n = 0;
            for (const it of bar) { total += itemW(it); n++; }
            if (overflow.length > 0) { total += even(2 * pad + metrics.overflowWidth); n++; }
            if (!centred) { total += centreW(); n++; }
            return total + gap * Math.max(0, n - 1);
        };
        const fits = function (right) {
            const left = keptLeft() + leftTextMin;
            return centred ? Math.max(left, right) <= (width - centreW()) / 2 - CLOCK_GAP
                : left + right + CLOCK_GAP <= width;
        };
        const budget = function (right) {
            const available = centred ? (width - centreW()) / 2 - CLOCK_GAP : width - right - CLOCK_GAP;
            return Math.min(keptLeft() + metrics.titleWidth, Math.max(keptLeft(), available));
        };
        const done = function (bar, overflow, right) {
            const show = {
                title: metrics.titleWidth > 0 && budget(right) - keptLeft() >= TITLE_STUB,
                dictationActions: actionsOnBar,
                battery: metrics.batteryWidth > 0, clock: true, app: hasApp, mark: true,
                chord: chordW > 0, chordNames: chordW > 0 && chordNames
            };
            for (const k of YIELD_ORDER) if (k !== "space" && k !== "uncentre" && k !== "titleMin") show[k] = !yielded(k);
            return {
                steps: applied.concat(overflow.length > 0 ? ["overflow"] : []).concat(!fits(right) ? ["underflow"] : []),
                pad: pad, gap: gap, centred: centred, edge: EDGE,
                controls: bar.filter(function (it) { return it.control; }).map(function (it) { return it.id; }),
                overflow: overflow, show: show,
                leftMax: budget(right), centreW: centreW(), chordWidth: chordW,
                chordPlace: chordW > 0 ? (centred ? "centre" : "right") : ""
            };
        };
        let bar = items.slice(), overflow = [], right = rightW(bar, overflow);
        if (fits(right)) return done(bar, overflow, right);
        if (count < steps.length) continue;
        for (const id of OVERFLOW_ORDER) {
            if (!bar.some(function (it) { return it.id === id; })) continue;
            bar = bar.filter(function (it) { return it.id !== id; });
            overflow.push(id);
            right = rightW(bar, overflow);
            if (fits(right)) break;
        }
        // Retry and Dismiss move as one group, after every control.
        if (!fits(right) && actionsOnBar) {
            actionsOnBar = false;
            overflow.push("dictation");
            right = rightW(bar, overflow);
        }
        // Padding goes only after every overflow option has been used.
        while (!fits(right) && pad > 0) {
            pad--;
            right = rightW(bar, overflow);
        }
        const result = done(bar, overflow, right);
        return fits(right) ? result : compactPlan(width, metrics, result, chordW);
    }
    return null;
}

// Below the floor: battery, clock and Application move into », then the
// clock clearance and the edges shrink, then the Apple menu becomes »'s
// first row, and last » itself takes what width is left.
function compactPlan(width, metrics, result, chordW) {
    const show = result.show;
    show.title = false;
    let edge = EDGE, clearance = CLOCK_GAP;
    let clock = result.centreW;
    let more = metrics.overflowWidth;
    // Every readout has yielded here, so the battery and the Application
    // menu are their icons alone; the pad is zero.
    const total = function () {
        return 2 * edge + clearance + (show.mark ? even(metrics.markWidth) : 0) + more
            + (show.battery ? even(metrics.batteryWidth) : 0) + clock
            + (show.app ? even(metrics.appIconWidth) : 0);
    };
    for (const id of COMPACT_ORDER) {
        if (total() <= width) break;
        if (id === "battery" && show.battery) { show.battery = false; result.overflow.push("battery"); }
        if (id === "clock") {
            show.clock = false;
            show.chord = false; // Hints only; their controls are already in ».
            show.chordNames = false;
            clock = 0;
            result.overflow.push("clock");
        }
        if (id === "app" && show.app) { show.app = false; result.overflow.push("app"); }
    }
    clearance = Math.max(0, clearance - Math.max(0, total() - width));
    edge = Math.max(0, edge - Math.max(0, total() - width) / 2);
    if (total() > width) {
        show.mark = false;
        result.overflow.unshift("apple");
        more = Math.min(width, more);
    }
    result.steps = result.steps.filter(function (step) { return step !== "underflow"; });
    result.steps.push("compact");
    result.edge = edge;
    result.overflowIconWidth = more;
    result.leftMax = edge + (show.mark ? even(metrics.markWidth) : 0);
    result.centreW = clock;
    result.chordWidth = show.chord ? chordW : 0;
    result.chordPlace = show.chord ? "right" : "";
    return result;
}

// Where each item of the plan stands, in logical px from the bar's left
// edge: what PlatinumTopBar's rows draw, computed the same way. The
// right group is a Row anchored at the right edge; uncentred, the clock
// or Super+O's key caps lead it. Used by the tests and by the transient
// tag and Balloon Help to find a control's place.
//   widths: {id: drawn width} for every item the bar shows (controls,
//   "more", "battery", "app"); the clock and the chord come from the plan.
function place(width, metrics, p, widths) {
    const order = [];
    if (!p.centred && p.show.chord) order.push({id: "chord", w: p.chordWidth});
    else if (!p.centred && p.show.clock !== false) order.push({id: "clock", w: p.centreW});
    for (const id of p.controls) order.push({id: id, w: widths[id]});
    if (p.overflow.length > 0) order.push({id: "more", w: widths.more});
    if (p.show.battery) order.push({id: "battery", w: widths.battery});
    if (p.show.app !== false && (metrics.appIconWidth > 0 || metrics.appNameWidth > 0)) order.push({id: "app", w: widths.app});
    const out = {};
    let x = width - p.edge;
    for (let i = order.length - 1; i >= 0; i--) {
        x -= order[i].w;
        out[order[i].id] = {x: x, w: order[i].w};
        if (i > 0) x -= p.gap;
    }
    if (p.centred) {
        if (p.show.chord) out.chord = {x: even(width / 2 - p.chordWidth / 2), w: p.chordWidth};
        else if (p.show.clock !== false) out.clock = {x: even(width / 2 - p.centreW / 2), w: p.centreW};
    }
    out.rightStart = order.length ? out[order[0].id].x : width - p.edge;
    return out;
}

// The transient tag: after a volume or brightness change it hangs under
// its control (under » when the control overflowed) for 1.5 s with the
// icon, a level well and the number. It escapes the bar, so it never moves
// the bar's items. It stays inside the screen, and it drops its well
// before it would clip; below its slim width it does not show (the value
// is in the menu).
var TAG = {inset: 6, pad: 8, icon: 16, gap: 8, well: 64, slimGap: 6, hold: 1500};
function tagPlan(width, anchorX, anchorWidth, numberWidth) {
    const full = TAG.pad + TAG.icon + TAG.gap + TAG.well + TAG.gap + numberWidth + TAG.pad;
    const slim = TAG.pad + TAG.icon + TAG.slimGap + numberWidth + TAG.pad;
    const room = width - 2 * TAG.inset;
    if (room < slim) return {show: false, x: 0, width: 0, well: 0};
    const w = full <= room ? full : slim;
    const centre = anchorX + anchorWidth / 2;
    const x = Math.max(TAG.inset, Math.min(width - TAG.inset - w, Math.round(centre - w / 2)));
    return {show: true, x: x, width: w, well: full <= room ? TAG.well : 0};
}

// Balloon Help under a bar title: the full value of the item under the
// pointer. It is as wide as its text wants (wantWidth, text and padding),
// at most 300 px and the screen less its insets; longer text wraps. The
// balloon hangs to the left of its tail, so it stays on the screen at the
// right end of the bar; its tail points at the title.
var BALLOON = {inset: 6, maxWidth: 300, tailFromRight: 30, tailMin: 14};
function balloonPlan(width, anchorX, anchorWidth, wantWidth) {
    const want = wantWidth === undefined ? BALLOON.maxWidth : wantWidth;
    const w = Math.max(0, Math.min(BALLOON.maxWidth, want, width - 2 * BALLOON.inset));
    const centre = anchorX + anchorWidth / 2;
    const x = Math.max(BALLOON.inset, Math.min(width - BALLOON.inset - w, Math.round(centre - w + BALLOON.tailFromRight)));
    const tail = Math.max(Math.min(BALLOON.tailMin, w / 2), Math.min(w - Math.min(BALLOON.tailMin, w / 2), centre - x));
    return {x: x, width: w, tail: tail};
}
