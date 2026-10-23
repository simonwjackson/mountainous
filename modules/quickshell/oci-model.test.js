const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const model = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/oci-model.js", "utf8").replace(/^\.pragma library\s*$/m, ""), model);
const rows = [{name: "DEFAULT", percent: "86.9"}, {name: "family", percent: "4.1"}];
assert.equal(model.rowRule(rows[0]).tone, "danger");
assert.equal(model.rowRule(rows[1]).tone, "normal", "a healthy row never inherits the worst row's tone");
for (const [percent, tone] of [[0, "normal"], [49.9, "normal"], [50, "warning"], [79.9, "warning"], [80, "danger"], [120, "danger"]]) {
    const result = model.rowRule({name: "DEFAULT", percent});
    assert.equal(result.name, "DEFAULT");
    assert.equal(result.value, percent.toFixed(1) + "%");
    assert.equal(result.tone, tone);
    assert.equal(result.failed, false);
}
for (const percent of ["--", "", " ", null, undefined, NaN, Infinity, -1, "NaN", "38%", {}, true]) {
    const result = model.rowRule({name: "DEFAULT", percent});
    assert.equal(result.name, "DEFAULT");
    assert.equal(result.value, "Failed", "failed rows must not print --%");
    assert.equal(result.tone, "warning");
    assert.equal(result.failed, true);
}
assert.equal(model.rowRule(null).value, "Failed");
console.log("oci-model: per-row tones and failure values pass");
