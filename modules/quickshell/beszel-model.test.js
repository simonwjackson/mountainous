const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const model = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/beszel-model.js", "utf8").replace(/^\.pragma library\s*$/m, ""), model);
const now = Date.parse("2026-10-23T21:15:00Z");
const minute = 60000;
const host = (fields = {}) => ({name: "unzen", status: "up", lastSeen: "2026-10-23 21:15:00Z", ...fields});
const tone = (fields, history = [], smart = []) => model.hostTone(host(fields), history, now, smart);
assert.equal(tone({}), "normal");
for (const name of ["fuji", "ibuki", "rakku", "tate", "unzen", "yari"]) {
    assert.equal(tone({name, status: "down"}), "danger");
}
for (const name of ["myoko", "hiyori"]) {
    assert.equal(tone({name, status: "down", diskPercent: 100, services: {failed: 3}}), "muted", "ignore stale down-desktop values");
}
for (const status of ["paused", "pending", "unknown"]) {
    assert.equal(tone({status, diskPercent: 100}), "muted");
}
assert.equal(model.hostTone(null, [], now), "muted");
assert.equal(tone({services: {failed: 1}}), "danger");
assert.equal(tone({services: {failed: 0.5}}), "danger");
for (const [value, expected] of [[0, "normal"], [84.9, "normal"], [85, "warning"], [94.9, "warning"], [95, "danger"], [100, "danger"]]) {
    assert.equal(tone({diskPercent: value}), expected);
    assert.equal(tone({extraFilesystemPercent: {towada: value}}), expected);
}
for (const [temperatureC, expected] of [[0, "normal"], [84.9, "normal"], [85, "warning"], [99.9, "warning"], [100, "danger"]]) {
    assert.equal(tone({temperatureC}), expected);
}
for (const invalid of [null, "100", NaN, Infinity, {}, true]) {
    assert.equal(tone({diskPercent: invalid, temperatureC: invalid, extraFilesystemPercent: {towada: invalid}}), "normal");
}
assert.equal(tone({lastSeen: now - 3 * minute}), "normal");
assert.equal(tone({lastSeen: now - 3 * minute - 1}), "warning");
assert.equal(tone({lastSeen: "bad date"}), "warning");
assert.equal(tone({lastSeen: now - 4 * minute, diskPercent: 95}), "danger");
const history = (cpuPercent, memoryPercent) => Array.from({length: 6}, (_, i) => ({lastSeen: now - (5 - i) * minute, cpuPercent, memoryPercent}));
for (const metric of ["cpuPercent", "memoryPercent"]) {
    const samples = history(0, 0).map(sample => ({...sample, [metric]: 90}));
    assert.equal(tone({[metric]: 90}, samples), "warning", "five minutes at threshold");
    assert.equal(tone({[metric]: 90}, samples.slice(1)), "normal", "less than five minutes is not sustained");
    assert.equal(tone({[metric]: 89.9}, samples), "normal", "current recovery ends the streak");
    assert.equal(tone({[metric]: 90}, samples.map((sample, i) => i === 2 ? {...sample, [metric]: 89.9} : sample)), "normal");
    assert.equal(tone({[metric]: 90}, [samples[0], samples[5]]), "normal", "a missing five-minute span is not continuous history");
    assert.equal(tone({[metric]: 90}, samples.slice().reverse()), "warning", "history ordering does not change the result");
}
assert.equal(tone({cpuPercent: 100}), "normal", "a single spike is not sustained");
assert.equal(tone({}, history(100, 100).map(sample => ({...sample, lastSeen: sample.lastSeen - 10 * minute}))), "normal", "old high values do not count");
assert.equal(tone({}, [], [{system: "unzen", smartState: "FAILED"}]), "danger");
assert.equal(tone({}, [], [{system: "unzen", healthy: false}]), "danger");
assert.equal(tone({name: "hiyori", status: "down"}, [], [{system: "hiyori", smartState: "FAILED"}]), "danger", "explicit failed SMART data overrides a sleeping desktop's muted tone");
assert.equal(tone({}, [], [{system: "unzen", attributes: [{failing: true}]}]), "danger");
assert.equal(tone({}, [], [{system: "ibuki", healthy: false}]), "normal", "SMART verdicts stay with their host");
assert.equal(tone({}, [], [{system: "unzen", smartState: "PASSED", healthy: true}]), "normal");
assert.equal(tone({}, [], [{system: "unzen", smartState: "UNKNOWN", healthy: false}]), "normal", "the tool's unknown SMART verdict is not a failed disk");
assert.equal(tone({smartState: "FAILED", healthy: false}), "normal", "only explicit drill-down input affects SMART tone");
const fleet = [host(), host({name: "hiyori", status: "down"}), host({name: "ibuki", diskPercent: 85})];
const before = JSON.stringify(fleet);
assert.equal(model.fleetTone(fleet, {}, now), "warning");
assert.equal(model.summaryText(fleet, {}, now), "3 hosts · 1 problem");
assert.equal(model.fleetTone([host(), host({name: "hiyori", status: "down"})], {}, now), "normal");
assert.equal(model.fleetTone([host({name: "hiyori", status: "down"})], {}, now), "muted");
assert.equal(model.fleetTone(fleet.concat(host({name: "fuji", status: "down"})), {}, now), "danger");
assert.equal(model.summaryText(fleet.concat(host({name: "fuji", status: "down"})), {}, now), "4 hosts · 2 problems");
assert.equal(model.summaryText([host()], {}, now), "1 host · 0 problems");
assert.equal(model.summaryText([], {}, now), "0 hosts · 0 problems");
assert.equal(model.summaryText(["fuji", "ibuki", "rakku", "tate", "unzen", "yari", "myoko", "hiyori"].map(name =>
    host({name, services: {failed: name === "unzen" ? 1 : 0}})), {}, now), "8 hosts · 1 problem");
assert.equal(model.fleetTone([], {}, now), "muted");
for (const state of ["unavailable", "error"]) {
    assert.equal(model.fleetTone(state, {}, now), "muted");
    assert.equal(model.summaryText(state, {}, now), "Beszel --");
}
assert.equal(model.fleetTone([host({cpuPercent: 90})], {unzen: history(90, 0)}, now), "warning");
assert.equal(model.fleetTone([host()], {}, now, [{system: "unzen", healthy: false}]), "danger");
assert.equal(JSON.stringify(fleet), before, "model does not mutate input");
console.log("beszel-model: status, thresholds, sustained load, freshness, SMART and fleet summaries pass");
