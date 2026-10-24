const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const model = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/bar-plan.js", "utf8").replace(/^\.pragma library\s*$/m, ""), model);
const metrics = {
    controls: ["bt", "wifi", "vol", "bri", "oci", "disk", "ntf"].map(id => ({id, iconWidth: 16, readoutWidth: id === "oci" ? 160 : id === "wifi" ? 0 : 24})),
    markWidth: 20, titleWidth: 200, titleMinWidth: 96, clockWidth: 112, clockTimeWidth: 48,
    chordWidth: 0, batteryWidth: 56, appIconWidth: 16, appNameWidth: 70, overflowWidth: 16
};
const expectedSteps = ["space", "ociLabel", "diskLabel", "appName", "clockDate", "btCount", "brightnessNumber", "volumeNumber", "notificationCount", "uncentre", "titleMin"];
const overflowOrder = ["oci", "disk", "bri", "bt", "wifi", "ntf", "vol"];
const generous = model.plan(3000, metrics);
assert.equal(generous.steps.length, 0);
assert.equal(generous.controls.length, 7);
assert.equal(generous.overflow.length, 0);
assert.equal(generous.show.title, true);
assert.equal(generous.centred, true);
assert.equal(generous.pad, 8);
assert.equal(generous.gap, 2);
let previous = generous;
const transitions = [];
for (let width = 2999; width >= 0; width--) {
    const plan = model.plan(width, metrics);
    const all = [...plan.controls, ...plan.overflow];
    assert.deepEqual([...all].sort(), metrics.controls.map(c => c.id).sort(), "no control disappears at " + width);
    assert.equal(new Set(all).size, 7);
    assert.deepEqual(Array.from(plan.steps).filter(s => s !== "overflow" && s !== "underflow"), expectedSteps.slice(0, Math.min(plan.steps.length, expectedSteps.length)), "yield order at " + width);
    assert.deepEqual(Array.from(plan.overflow), overflowOrder.slice(0, plan.overflow.length));
    assert.ok(plan.overflow.length >= previous.overflow.length, "overflow is monotonic");
    assert.ok(plan.steps.length >= previous.steps.length, "yielding is monotonic");
    if (plan.steps.length !== previous.steps.length || plan.overflow.length !== previous.overflow.length) transitions.push(width);
    if (plan.overflow.length) {
        for (const key of ["ociLabel", "diskLabel", "appName", "clockDate", "btCount", "brightnessNumber", "volumeNumber", "notificationCount"]) assert.equal(plan.show[key], false);
    }
    assert.ok(plan.leftMax >= 0);
    assert.ok(plan.centreW >= 0);
    previous = plan;
}
assert.ok(transitions.length >= 10, "the sweep exercises yield and overflow boundaries at +/-1 px");
assert.equal(model.plan(600, metrics).overflow.length, 0, "readouts yield before controls");
assert.equal(model.plan(320, metrics).overflow[0], "oci");
const compact = {...metrics, controls: metrics.controls.map(c => c.id === "disk" ? {...c, compactReadoutWidth: 24} : c)};
assert.equal(model.plan(3000, compact).steps.length, 0, "compact width does not change the wide layout");
assert.ok(model.plan(400, compact).overflow.length > model.plan(400, metrics).overflow.length,
    "the disk issue count still consumes width after its label yields");
for (const compactReadoutWidth of [-1, NaN, -Infinity]) {
    assert.throws(() => model.plan(100, {...metrics, controls: [{id: "disk", iconWidth: 16, readoutWidth: 24, compactReadoutWidth}]}), /compact/i);
}
// Captured from the real TopBar in round 1, before DESIGN's gap correction.
const captured = {
    controls: [
        {id: "bt", iconWidth: 16, readoutWidth: 17},
        {id: "wifi", iconWidth: 16, readoutWidth: 0},
        {id: "vol", iconWidth: 16, readoutWidth: 36},
        {id: "bri", iconWidth: 16, readoutWidth: 36},
        {id: "oci", iconWidth: 16, readoutWidth: 246.90625},
        {id: "disk", iconWidth: 16, readoutWidth: 25.234375, compactReadoutWidth: 0},
        {id: "ntf", iconWidth: 16, readoutWidth: 6, compactReadoutWidth: 12.984375}
    ],
    markWidth: 20, titleWidth: 322, titleMinWidth: 96, clockWidth: 103, clockTimeWidth: 45,
    chordWidth: 0, batteryWidth: 66, appIconWidth: 16, appNameWidth: 63, overflowWidth: 16
};
for (const width of [0, 1, 100, 320, 600, 1920, 3000, Infinity]) {
    const result = model.plan(width, captured);
    assert.equal(result.show.notificationCount, true, "larger compact readout keeps the full readout at " + width);
    assert.equal(result.steps.includes("notificationCount"), false, "skip a yield that saves no space");
}
for (const readoutWidth of [0, 6, 24]) {
    for (const compactReadoutWidth of [readoutWidth, readoutWidth + 0.125, readoutWidth + 1000000, Infinity]) {
        const input = {...metrics, controls: [{id: "ntf", iconWidth: 16, readoutWidth, compactReadoutWidth}]};
        const clamped = {...input, controls: [{...input.controls[0], compactReadoutWidth: readoutWidth}]};
        for (const width of [0, 0.125, 100, 320, 600, 3000]) {
            const result = model.plan(width, input);
            assert.equal(result.show.notificationCount, true, "equal/larger compact width keeps the full readout");
            assert.equal(result.steps.includes("notificationCount"), false);
            assert.equal(JSON.stringify(result), JSON.stringify(model.plan(width, clamped)), "clamp without mutating the input");
            assert.equal(input.controls[0].compactReadoutWidth, compactReadoutWidth);
        }
    }
}
const missing = {...metrics, controls: metrics.controls.filter(c => !["bt", "bri"].includes(c.id))};
assert.equal(model.plan(0, missing).overflow.length, 5, "only hardware-present controls are planned");
const chord = model.plan(900, {...metrics, chordWidth: 300});
assert.equal(chord.centreW, 300, "chord uses its measured width, not the clock's width");
assert.ok(chord.leftMax <= 900 - 300, "title cannot overlap the chord");
assert.throws(() => model.plan(-1, metrics), /width/i);
assert.throws(() => model.plan(NaN, metrics), /width/i);
assert.throws(() => model.plan(100, {...metrics, batteryWidth: -1}), /batteryWidth/i);
assert.throws(() => model.plan(100, {...metrics, controls: [{id: "other", iconWidth: 16, readoutWidth: 0}]}), /control/i);
assert.throws(() => model.plan(100, {...metrics, controls: [metrics.controls[0], metrics.controls[0]]}), /control/i);
const fixtures = JSON.parse(fs.readFileSync(process.argv[3] || __dirname + "/bar-fixtures.json", "utf8"));
const failed = fixtures.failedDictationMetrics;
// Budget the exact retained content, independently of the planner. In
// particular, no left-group cap may take space away from the mark or buttons.
function assertKeptControlsFit(width, input) {
    const result = model.plan(width, input);
    assert.ok(Number.isInteger(result.pad), "padding uses whole logical pixels");
    const mark = 6 + 2 * result.pad + input.markWidth;
    const actions = result.show.dictationActions && input.dictationActionsWidth > 0 ? 6 + input.dictationActionsWidth : 0;
    const leftGap = input.titleWidth > 0 || actions > 0 ? result.gap : 0;
    assert.ok(result.leftMax >= mark + leftGap + actions, "left controls have full width at " + width);
    const mapping = {bt: "btCount", vol: "volumeNumber", bri: "brightnessNumber", oci: "ociLabel", disk: "diskLabel", fleet: "fleetCount", builder: "builderLabel", ntf: "notificationCount"};
    let right = 6, count = 0;
    for (const id of result.controls) {
        const item = input.controls.find(c => c.id === id);
        const readout = result.show[mapping[id]] !== false ? item.readoutWidth : Math.min(item.readoutWidth, item.compactReadoutWidth || 0);
        right += 2 * result.pad + item.iconWidth + (readout > 0 ? 6 + readout : 0);
        count++;
    }
    if (input.batteryWidth > 0) { right += 2 * result.pad + input.batteryWidth; count++; }
    if (input.appIconWidth > 0 || (result.show.appName && input.appNameWidth > 0)) {
        right += 2 * result.pad + input.appIconWidth + (result.show.appName && input.appNameWidth > 0 ? 6 + input.appNameWidth : 0);
        count++;
    }
    if (result.overflow.length) { right += 2 * result.pad + input.overflowWidth; count++; }
    right += result.gap * Math.max(0, count - 1);
    if (!result.steps.includes("underflow")) {
        assert.ok(result.leftMax + result.centreW + right + 16 <= width + 0.00001,
            "retained controls, mark, battery and clock fit at " + width);
    }
    const all = result.controls.concat(result.overflow.filter(id => id !== "dictation"));
    assert.deepEqual(Array.from(all).sort(), input.controls.map(c => c.id).sort());
    if (result.overflow.includes("dictation")) {
        assert.equal(result.controls.length, 0, "dictation actions overflow after all other controls");
        assert.equal(result.show.dictationActions, false);
    }
    return result;
}
for (const width of [1920, 600, 400, 320, 200, 191]) {
    const result = assertKeptControlsFit(width, failed);
    assert.equal(result.steps.includes("underflow"), false, "the captured metrics support " + width);
}
const wideFailed = model.plan(1920, failed);
assert.equal(wideFailed.show.dictationActions, true);
assert.equal(wideFailed.leftMax - 6, 2 * wideFailed.pad + failed.markWidth + wideFailed.gap + failed.titleWidth + 6 + failed.dictationActionsWidth,
    "mark + inter-item gap + status + exactly one actions gap + actions, without the outer edge");
const withoutActions = {...failed, dictationActionsWidth: 0};
const noActionsPlan = model.plan(1920, withoutActions);
assert.equal(noActionsPlan.leftMax - 6, 2 * noActionsPlan.pad + failed.markWidth + noActionsPlan.gap + failed.titleWidth,
    "no actions means no actions gap");
const dismissOnly = {...failed, dictationActionsWidth: 74};
const dismissPlan = model.plan(1920, dismissOnly);
assert.equal(dismissPlan.leftMax - 6, 2 * dismissPlan.pad + failed.markWidth + dismissPlan.gap + failed.titleWidth + 6 + 74,
    "Dismiss alone still has exactly one leading actions gap");
assert.equal(JSON.stringify(model.plan(600, metrics)), JSON.stringify(model.plan(600, {...metrics, dictationActionsWidth: 0})), "new metric defaults to zero");
for (const dictationActionsWidth of [-1, NaN]) assert.throws(() => model.plan(600, {...metrics, dictationActionsWidth}), /dictationActionsWidth/i);
assert.equal(model.plan(320, failed).show.dictationActions, false);
assert.equal(model.plan(200, failed).pad, 0, "padding falls below five only after every control overflows");
// Captured floor: mark20 + battery66 + clock45 + app16 + overflow16 +
// two edges6 + the clock clearance16 = 191 logical pixels, at zero padding.
assert.equal(model.plan(191, failed).pad, 0);
assert.equal(model.plan(190, failed).steps.includes("underflow"), true, "below the supported floor is explicit, not silent clipping");
for (let width = 0; width <= 1920; width++) {
    const result = assertKeptControlsFit(width, failed);
    assert.equal(result.steps.includes("underflow"), width < 191, "metrics-derived floor at " + width);
    if (result.pad < 5) {
        assert.equal(result.controls.length, 0);
        assert.equal(result.show.dictationActions, false);
    }
}
for (const fixture of fixtures.states) {
    if (fixture.dictation) assertKeptControlsFit(fixture.width, failed);
    if (fixture.ociRows) {
        const input = {...withoutActions, controls: failed.controls.map(c => c.id === "oci" ? {...c, readoutWidth: fixture.ociRows.length * 120} : c)};
        const result = assertKeptControlsFit(fixture.width, input);
        assert.equal(fixture.ociRows.length, 8);
        assert.equal(fixture.open, "oci");
        assert.equal(fixture.anchor, "more");
        assert.ok(result.overflow.includes("oci"), "the eight-profile menu is reachable from »");
    }
}
// A host without the gate must keep the old layout, including its yield
// steps. Only the newly exposed show.builderLabel field is additive.
for (const fixture of fixtures.builderAbsentPlans) {
    const actual = JSON.parse(JSON.stringify(model.plan(fixture.width, metrics)));
    delete actual.show.builderLabel;
    delete actual.show.fleetCount;
    assert.deepEqual(actual, fixture.plan, "builder absent keeps the old plan at " + fixture.width);
}
const builderMetrics = {...metrics, controls: metrics.controls.slice()};
builderMetrics.controls.splice(6, 0, {id: "builder", iconWidth: 16, readoutWidth: 96, compactReadoutWidth: 24});
const builderOverflowOrder = ["oci", "disk", "builder", "bri", "bt", "wifi", "ntf", "vol"];
for (const width of [1920, 600, 400, 320]) {
    const result = assertKeptControlsFit(width, builderMetrics);
    assert.equal(result.controls.concat(result.overflow).filter(id => id === "builder").length, 1, "builder never disappears at " + width);
    assert.deepEqual(Array.from(result.overflow), builderOverflowOrder.slice(0, result.overflow.length));
}
assert.equal(model.plan(1920, builderMetrics).show.builderLabel, true);
assert.ok(model.plan(320, builderMetrics).overflow.includes("builder"));
for (let width = 0; width <= 1920; width++) {
    const result = assertKeptControlsFit(width, builderMetrics);
    assert.deepEqual(Array.from(result.overflow), builderOverflowOrder.slice(0, result.overflow.length));
    if (result.steps.includes("builderLabel")) {
        const label = result.steps.indexOf("builderLabel");
        assert.ok(result.steps.indexOf("diskLabel") < label);
        if (result.steps.includes("appName")) assert.ok(label < result.steps.indexOf("appName"));
    }
}
const builderFixture = fixtures.states.find(f => f.builder);
assert.ok(builderFixture.builder.present && builderFixture.width === 320);
assertKeptControlsFit(builderFixture.width, builderMetrics);
// The Fleet readout: a light (12 px) and a problem count. Its count yields
// right after the disk label, and the control overflows right after Disks.
// Without it (Win98, no Beszel owner) every plan above is unchanged, which
// the fixture comparison already proves.
const fleetMetrics = {...builderMetrics, controls: builderMetrics.controls.slice()};
fleetMetrics.controls.splice(6, 0, {id: "fleet", iconWidth: 12, readoutWidth: 10, compactReadoutWidth: 0});
const fleetOverflowOrder = ["oci", "disk", "fleet", "builder", "bri", "bt", "wifi", "ntf", "vol"];
assert.equal(model.plan(1920, fleetMetrics).show.fleetCount, true);
assert.deepEqual(Array.from(model.plan(1920, fleetMetrics).controls).slice(5, 8), ["disk", "fleet", "builder"]);
let fleetSeen = {count: false, overflow: false};
for (let width = 0; width <= 1920; width++) {
    const result = assertKeptControlsFit(width, fleetMetrics);
    assert.equal(result.controls.concat(result.overflow).filter(id => id === "fleet").length, 1, "the readout never disappears at " + width);
    assert.deepEqual(Array.from(result.overflow), fleetOverflowOrder.slice(0, result.overflow.length));
    if (result.steps.includes("fleetCount")) {
        fleetSeen.count = true;
        const at = result.steps.indexOf("fleetCount");
        assert.ok(result.steps.indexOf("diskLabel") < at && at < result.steps.indexOf("builderLabel") + (result.steps.includes("builderLabel") ? 0 : 99));
        assert.equal(result.show.fleetCount, false);
    }
    if (result.overflow.includes("fleet")) {
        fleetSeen.overflow = true;
        assert.ok(result.overflow.includes("disk"), "Disks overflows before the readout");
        assert.equal(result.show.fleetCount, false, "readouts yield before controls overflow");
    }
}
assert.ok(fleetSeen.count && fleetSeen.overflow, "the sweep reaches the count's yield and the control's overflow");
// "--" and a two-digit count are wider than no count; equal widths skip the step.
assert.equal(model.plan(400, {...fleetMetrics, controls: fleetMetrics.controls.map(c => c.id === "fleet" ? {...c, readoutWidth: 0} : c)}).steps.includes("fleetCount"), false);
console.log("bar-plan: width sweeps, dictation actions, 191px floor, exact gaps, builder presence/absence and the Fleet readout pass");
