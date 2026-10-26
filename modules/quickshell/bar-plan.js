.pragma library

// All widths are intrinsic content widths, without control padding. The
// caller measures fixed-width number boxes at their widest value. Omit a
// control only when its hardware/service is missing, never when switched off.
//
// metrics: controls:[{id,iconWidth,readoutWidth,compactReadoutWidth?}], markWidth, titleWidth,
// titleMinWidth, clockWidth, clockTimeWidth, chordWidth (0 without chord),
// batteryWidth (entire icon/percent content; 0 without battery), appIconWidth,
// appNameWidth, overflowWidth, dictationActionsWidth? (default 0).
// controls contains bar control IDs; overflow may also contain 'dictation'.
// show.dictationActions is true only while a nonempty actions group is inline.
// compactReadoutWidth defaults to 0; e.g. the disk issue count stays when
// its label yields. leftMax budgets the entire left group, not just the title.
// titleWidth/titleMinWidth cover only title/status content (including its dot),
// never actions. dictationActionsWidth is the whole button group: Retry + 6 +
// Dismiss, or Dismiss alone, with no leading gap. It defaults to zero.
// The left group's ordinary item gap is plan.gap. Its actions gap is 6 px.
//
// Below the old 191 px floor, battery, clock and Application move into ».
// Edges and clock clearance yield last. Below mark + » (36 px for the
// captured metrics), the Apple menu becomes the first overflow row. Only
// below »'s own width does that mark shrink. Zero width has no hit surface.
/**
 * @typedef {'bt'|'wifi'|'vol'|'bri'|'oci'|'disk'|'fleet'|'builder'|'ntf'} ControlId
 * @typedef {{id: ControlId, iconWidth: number, readoutWidth: number, compactReadoutWidth?: number}} Control
 * @param {number} width
 * @param {{controls: Control[], markWidth: number, titleWidth: number, titleMinWidth: number,
 * clockWidth: number, clockTimeWidth: number, chordWidth: number, batteryWidth: number,
 * appIconWidth: number, appNameWidth: number, overflowWidth: number, dictationActionsWidth?: number}} metrics
 * Control readoutWidth, compactReadoutWidth and appNameWidth are raw content
 * widths. The planner owns the 6 px icon/readout gap; do not include it here.
 */
function plan(width, metrics) {
    const yieldOrder = ["space", "ociLabel", "diskLabel", "fleetCount", "builderLabel", "appName", "clockDate", "btCount", "brightnessNumber", "volumeNumber", "notificationCount", "uncentre", "titleMin"];
    const overflowOrder = ["oci", "disk", "fleet", "builder", "bri", "bt", "wifi", "ntf", "vol"];
    const readouts = {oci: "ociLabel", disk: "diskLabel", fleet: "fleetCount", builder: "builderLabel", bt: "btCount", bri: "brightnessNumber", vol: "volumeNumber", ntf: "notificationCount"};
    const edge = 6, insideGap = 6, clockGap = 16, titleStub = 56;
    const dimension = function (value, name) {
        if (typeof value !== "number" || Number.isNaN(value) || value < 0) throw new Error("Invalid " + name + " width");
    };
    dimension(width, "container");
    if (!metrics || !Array.isArray(metrics.controls)) throw new Error("Invalid controls");
    for (const name of ["markWidth", "titleWidth", "titleMinWidth", "clockWidth", "clockTimeWidth", "chordWidth", "batteryWidth", "appIconWidth", "appNameWidth", "overflowWidth"]) dimension(metrics[name], name);
    const dictationActionsWidth = metrics.dictationActionsWidth === undefined ? 0 : metrics.dictationActionsWidth;
    dimension(dictationActionsWidth, "dictationActionsWidth");
    const ids = [];
    for (const control of metrics.controls) {
        if (!control || !overflowOrder.includes(control.id) || ids.includes(control.id)) throw new Error("Invalid or duplicate control");
        ids.push(control.id);
        dimension(control.iconWidth, "control icon");
        dimension(control.readoutWidth, "control readout");
        if (control.compactReadoutWidth !== undefined) {
            dimension(control.compactReadoutWidth, "compact readout");
        }
    }

    // Transient QML measurements can make a compact readout wider than the
    // full readout. Clamp without changing the caller's metrics, and retain
    // the full readout when yielding it would save no space.
    const compactWidth = function (control) {
        return Math.min(control.readoutWidth, control.compactReadoutWidth || 0);
    };
    const steps = yieldOrder.filter(function (step) {
        const control = metrics.controls.find(function (item) { return readouts[item.id] === step; });
        // Adding the optional builder must not add a no-op yield on hosts
        // without the gate, or change their existing layout steps.
        if ((step === "builderLabel" || step === "fleetCount") && !control) return false;
        return !control || compactWidth(control) < control.readoutWidth;
    });

    for (let count = 0; count <= steps.length; count++) {
        const applied = steps.slice(0, count);
        const yielded = function (key) { return applied.includes(key); };
        let pad = yielded("space") ? 5 : 8;
        const gap = yielded("space") ? 0 : 2;
        const centred = !yielded("uncentre");
        const clockContent = yielded("clockDate") ? metrics.clockTimeWidth : metrics.clockWidth;
        let centreW = metrics.chordWidth > 0 ? metrics.chordWidth : 2 * pad + clockContent;
        let mark = edge + 2 * pad + metrics.markWidth;
        const leftTextMin = yielded("titleMin") ? 0 : Math.min(metrics.titleMinWidth, metrics.titleWidth);
        let actionsOnBar = dictationActionsWidth > 0;
        const keptLeft = function () {
            const itemGap = metrics.titleWidth > 0 || actionsOnBar ? gap : 0;
            return mark + itemGap + (actionsOnBar ? insideGap + dictationActionsWidth : 0);
        };
        const controlWidth = function (control) {
            const readout = !yielded(readouts[control.id]) ? control.readoutWidth : compactWidth(control);
            return 2 * pad + control.iconWidth + (readout > 0 ? insideGap + readout : 0);
        };
        const rightWidth = function (controls, overflow) {
            let total = edge, items = controls.length;
            for (const control of controls) total += controlWidth(control);
            // The entire battery content, including its percent, never yields.
            if (metrics.batteryWidth > 0) { total += 2 * pad + metrics.batteryWidth; items++; }
            if (metrics.appIconWidth > 0 || (!yielded("appName") && metrics.appNameWidth > 0)) {
                total += 2 * pad + metrics.appIconWidth + (!yielded("appName") && metrics.appNameWidth > 0 ? insideGap + metrics.appNameWidth : 0);
                items++;
            }
            if (overflow.length > 0) { total += 2 * pad + metrics.overflowWidth; items++; }
            return total + gap * Math.max(0, items - 1);
        };
        const budget = function (right) {
            const available = centred ? (width - centreW) / 2 - clockGap : width - right - centreW - clockGap;
            return Math.min(keptLeft() + metrics.titleWidth, Math.max(keptLeft(), available));
        };
        const fits = function (right) {
            const left = keptLeft() + leftTextMin;
            return centred ? Math.max(left, right) <= (width - centreW) / 2 - clockGap : left + centreW + right + clockGap <= width;
        };
        const done = function (controls, overflow, right) {
            return {
                steps: applied.concat(overflow.length > 0 ? ["overflow"] : []).concat(!fits(right) ? ["underflow"] : []),
                pad: pad, gap: gap, centred: centred,
                controls: controls.map(function (control) { return control.id; }),
                overflow: overflow,
                show: {
                    ociLabel: !yielded("ociLabel"), diskLabel: !yielded("diskLabel"), fleetCount: !yielded("fleetCount"),
                    builderLabel: !yielded("builderLabel"), appName: !yielded("appName"),
                    clockDate: !yielded("clockDate"), btCount: !yielded("btCount"), brightnessNumber: !yielded("brightnessNumber"),
                    volumeNumber: !yielded("volumeNumber"), notificationCount: !yielded("notificationCount"),
                    title: metrics.titleWidth > 0 && budget(right) - keptLeft() >= titleStub,
                    dictationActions: actionsOnBar
                },
                leftMax: budget(right), centreW: centreW
            };
        };
        let controls = metrics.controls.slice(), overflow = [], right = rightWidth(controls, overflow);
        if (fits(right)) return done(controls, overflow, right);
        if (count === steps.length) {
            for (const id of overflowOrder) {
                if (!controls.some(function (control) { return control.id === id; })) continue;
                controls = controls.filter(function (control) { return control.id !== id; });
                overflow.push(id);
                right = rightWidth(controls, overflow);
                if (fits(right)) break;
            }
            if (!fits(right) && actionsOnBar) {
                actionsOnBar = false;
                overflow.push("dictation");
                right = rightWidth(controls, overflow);
            }
            // Do not spend a control's space on padding. This last reduction
            // runs only after every overflow option has been used.
            while (!fits(right) && pad > 0) {
                pad--;
                mark = edge + 2 * pad + metrics.markWidth;
                centreW = metrics.chordWidth > 0 ? metrics.chordWidth : 2 * pad + clockContent;
                right = rightWidth(controls, overflow);
            }
            const result = done(controls, overflow, right);
            return fits(right) ? result : compactPlan(width, metrics, result);
        }
    }
}

function compactPlan(width, metrics, result) {
    const show = result.show;
    show.title = false;
    show.battery = metrics.batteryWidth > 0;
    show.clock = true;
    show.app = metrics.appIconWidth > 0;
    show.mark = true;
    show.chord = metrics.chordWidth > 0;
    let edge = 6, clearance = 16;
    let clock = result.centreW;
    let more = metrics.overflowWidth;
    const total = function () {
        return 2 * edge + clearance + (show.mark ? metrics.markWidth : 0) + more
            + (show.battery ? metrics.batteryWidth : 0) + clock
            + (show.app ? metrics.appIconWidth : 0);
    };
    if (total() > width && show.battery) {
        show.battery = false;
        result.overflow.push("battery");
    }
    if (total() > width) {
        show.clock = false;
        show.chord = false; // Hints only; their controls are already in ».
        clock = 0;
        result.overflow.push("clock");
    }
    if (total() > width && show.app) {
        show.app = false;
        result.overflow.push("app");
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
    result.leftMax = edge + (show.mark ? metrics.markWidth : 0);
    result.centreW = clock;
    return result;
}
