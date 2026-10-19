// Execute the same QML model without a compositor or a network connection.
const fs = require("fs");
const vm = require("vm");
const assert = require("assert");
const model = {};
vm.runInNewContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, "")
    + "\nObject.assign(model, {parse, ageState});", {model});
const now = 1760860000000;
const row = (level, time = now / 1000) => `unzen\t${level}\t${"long message ".repeat(40)}\t${time}\n`;
for (const level of ["ok", "warn", "bad", "unreachable"]) {
    const sample = model.parse(row(level), now);
    assert.equal(sample.state, "ready");
    assert.equal(sample.rows.length, 1);
    assert.equal(sample.rows[0].level, level);
}
assert.equal(model.parse(row("ok").repeat(50), now).rows.length, 50);
for (const data of ["", "bad input", "unzen\tok\tmissing time", row("invalid"), row("ok", "NaN"), row("ok", now / 1000 + 121), row("ok") + "partial"]) {
    assert.equal(model.parse(data, now).state, "error", data);
}
assert.equal(model.parse(row("ok", now / 1000 - 601), now).state, "stale");
assert.equal(model.ageState("ready", now - 600000, now), "ready");
assert.equal(model.ageState("ready", now - 600001, now), "stale");
assert.equal(model.ageState("ready", now + 120001, now), "stale");
assert.equal(model.ageState("error", now, now), "error");
assert.equal(model.ageState("loading", now, now), "loading");
console.log("storage-health model: valid, empty, partial, error, long, many, future, stale passed");
