.pragma library

// All widths are intrinsic content widths, without control padding. The
// caller measures fixed-width number boxes at their widest value. Omit a
// control only when its hardware/service is missing, never when switched off.
//
// metrics: controls:[{id,iconWidth,readoutWidth,compactReadoutWidth?}], markWidth, titleWidth,
// titleMinWidth, clockWidth, clockTimeWidth, chordWidth (0 without chord),
// batteryWidth (entire icon/percent content; 0 without battery), appIconWidth,
// appNameWidth, overflowWidth. The result's controls/overflow are ID arrays.
// compactReadoutWidth defaults to 0; e.g. the disk issue count stays when
// its label yields. leftMax budgets the entire left group, not just the title.
/**
 * @typedef {'bt'|'wifi'|'vol'|'bri'|'oci'|'disk'|'ntf'} ControlId
 * @typedef {{id: ControlId, iconWidth: number, readoutWidth: number, compactReadoutWidth?: number}} Control
 * @param {number} width
 * @param {{controls: Control[], markWidth: number, titleWidth: number, titleMinWidth: number,
 * clockWidth: number, clockTimeWidth: number, chordWidth: number, batteryWidth: number,
 * appIconWidth: number, appNameWidth: number, overflowWidth: number}} metrics
 * Control readoutWidth, compactReadoutWidth and appNameWidth are raw content
 * widths. The planner owns the 6 px icon/readout gap; do not include it here.
 */
function plan(width, metrics) {
    const yieldOrder = ["space", "ociLabel", "diskLabel", "appName", "clockDate", "btCount", "brightnessNumber", "volumeNumber", "notificationCount", "uncentre", "titleMin"];
    const overflowOrder = ["oci", "disk", "bri", "bt", "wifi", "ntf", "vol"];
    const readouts = {oci: "ociLabel", disk: "diskLabel", bt: "btCount", bri: "brightnessNumber", vol: "volumeNumber", ntf: "notificationCount"};
    const edge = 6, insideGap = 6, clockGap = 16, titleStub = 56;
    const dimension = function (value, name) {
        if (typeof value !== "number" || Number.isNaN(value) || value < 0) throw new Error("Invalid " + name + " width");
    };
    dimension(width, "container");
    if (!metrics || !Array.isArray(metrics.controls)) throw new Error("Invalid controls");
    for (const name of ["markWidth", "titleWidth", "titleMinWidth", "clockWidth", "clockTimeWidth", "chordWidth", "batteryWidth", "appIconWidth", "appNameWidth", "overflowWidth"]) dimension(metrics[name], name);
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
        return !control || compactWidth(control) < control.readoutWidth;
    });

    for (let count = 0; count <= steps.length; count++) {
        const applied = steps.slice(0, count);
        const yielded = function (key) { return applied.includes(key); };
        const pad = yielded("space") ? 5 : 8;
        const gap = yielded("space") ? 0 : 2;
        const centred = !yielded("uncentre");
        const centreW = metrics.chordWidth > 0 ? metrics.chordWidth : 2 * pad + (yielded("clockDate") ? metrics.clockTimeWidth : metrics.clockWidth);
        const mark = edge + 2 * pad + metrics.markWidth;
        const leftMin = yielded("titleMin") ? 0 : Math.min(metrics.titleMinWidth, metrics.titleWidth);
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
            return Math.max(0, centred ? (width - centreW) / 2 - clockGap : width - right - centreW - clockGap);
        };
        const fits = function (right) {
            return centred ? Math.max(mark + leftMin, right) <= (width - centreW) / 2 - clockGap : mark + leftMin + centreW + right + clockGap <= width;
        };
        const done = function (controls, overflow, right) {
            return {
                steps: applied.concat(overflow.length > 0 ? ["overflow"] : []),
                pad: pad, gap: gap, centred: centred,
                controls: controls.map(function (control) { return control.id; }),
                overflow: overflow,
                show: {
                    ociLabel: !yielded("ociLabel"), diskLabel: !yielded("diskLabel"), appName: !yielded("appName"),
                    clockDate: !yielded("clockDate"), btCount: !yielded("btCount"), brightnessNumber: !yielded("brightnessNumber"),
                    volumeNumber: !yielded("volumeNumber"), notificationCount: !yielded("notificationCount"),
                    title: metrics.titleWidth > 0 && budget(right) - mark >= titleStub
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
            // Even below the physical minimum, retain every capability in ».
            return done(controls, overflow, right);
        }
    }
}
