// The same pure rules QML imports; no compositor is needed.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const model = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/battery.js", "utf8").replace(/^\.pragma library\s*$/m, ""), model);
for (const [percent, tone] of [[0, "danger"], [10, "danger"], [10.1, "warning"], [20, "warning"], [20.1, "normal"], [100, "normal"]]) {
    assert.equal(model.rule(percent, false, false, true).tone, tone);
    assert.equal(model.rule(percent, false, false, true).indicator, "none");
    assert.equal(model.rule(percent, true, false, false).tone, "normal", "AC does not warn");
}
assert.equal(model.rule(8, true, false, false).indicator, "bolt");
assert.equal(model.rule(100, false, true, false).indicator, "plug");
assert.equal(model.rule(80, false, false, false).indicator, "none", "AC alone does not imply charging or full");
assert.equal(model.rule(100, true, true, false).indicator, "plug", "full wins");
assert.equal(model.rule(8, true, true, true).indicator, "none", "battery power wins over stale device flags");
for (const invalid of [undefined, null, NaN, Infinity, -1, 101, "10"]) {
    assert.equal(model.rule(invalid, false, false, true).tone, "normal", "unknown percent cannot warn");
}
console.log("battery: thresholds and UPower charging/full states pass");
