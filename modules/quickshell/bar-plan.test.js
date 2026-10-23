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
    assert.deepEqual(Array.from(plan.steps).filter(s => s !== "overflow"), expectedSteps.slice(0, Math.min(plan.steps.length, expectedSteps.length)), "yield order at " + width);
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
for (const compactReadoutWidth of [-1, Infinity, 25]) {
    assert.throws(() => model.plan(100, {...metrics, controls: [{id: "disk", iconWidth: 16, readoutWidth: 24, compactReadoutWidth}]}), /compact/i);
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
console.log("bar-plan: 3001 widths, ordered yields, overflow, hardware absence and chord pass");
