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

// ---------------------------------------------------------------- views
{
    const same = (a, b, m) => assert.equal(JSON.stringify(a), JSON.stringify(b), m);
    const view = (fields, history = [], smart = []) => model.hostView(host(fields), history, now, smart);
    // hostView explains hostTone; it never disagrees with it.
    const cases = [{}, {status: "down"}, {name: "myoko", status: "down"}, {status: "paused"}, {status: "pending"},
        {services: {failed: 2, total: 60}}, {diskPercent: 85}, {extraFilesystemPercent: {towada: 96}}, {temperatureC: 85},
        {temperatureC: 100}, {lastSeen: now - 4 * minute}, {cpuPercent: 90}];
    for (const fields of cases) assert.equal(view(fields).tone, tone(fields), JSON.stringify(fields));
    same(view({}).reasons, [], "a healthy host has no reasons");
    const unzen = view({services: {failed: 2, total: 60}, extraFilesystemPercent: {towada: 96}, temperatureC: 71});
    same(Array.from(unzen.reasons, r => r.text), ["2 failed units", "towada 96%"]);
    assert.equal(unzen.disk.fs, "towada");
    assert.equal(unzen.disk.tone, "danger");
    assert.equal(view({status: "down", lastSeen: now - 13 * minute}).reasons[0].text, "Down, seen 13 min ago");
    assert.equal(view({name: "hiyori", status: "down"}).reasons[0].tone, "muted");
    const down = view({status: "down", diskPercent: 99, temperatureC: 120, services: {failed: 3}});
    assert.equal(down.trusted, false);
    assert.equal(down.disk.tone, "normal", "a down host's stale values set no tone");
    assert.equal(down.temp.tone, "normal");
    assert.equal(down.reasons.length, 1, "only the status explains a down host");
    assert.equal(view({temperatureC: 0}).temp.noSensor, true);
    assert.equal(view({temperatureC: 0}).temp.c, null);
    assert.equal(view({temperatureC: 104.6}).reasons[0].tone, "danger");
    assert.equal(view({lastSeen: now - 4 * minute}).reasons[0].text, "No report for 4 min");
    const hot = history(95, 0);
    assert.equal(view({cpuPercent: 95}, hot).reasons[0].text, "CPU at 90% or more for 5 min");
    assert.equal(model.sustainedMetric(host({memoryPercent: 91}), history(0, 91), now), "memoryPercent");
    assert.equal(model.sustainedMetric(host({}), [], now), "");
    assert.equal(view({}, [], [{system: "unzen", name: "/dev/sdc", smartState: "FAILED"}]).reasons[0].text, "sdc failed SMART");
    assert.equal(view({extraFilesystemPercent: null}).fss.length, 1, "live null extra filesystems");
    same(Array.from(view({extraFilesystemPercent: {b: 1, a: 2}}).fss, f => f.name), ["/", "a", "b"]);

    // Formats.
    assert.equal(model.fmtPct(null), "--");
    assert.equal(model.fmtPct(0), "0%");
    assert.equal(model.fmtPct(0.2), "<1%");
    assert.equal(model.fmtPct(37.5), "38%");
    assert.equal(model.fmtPct(NaN), "--");
    assert.equal(model.fmtTemp(0), "--");
    assert.equal(model.fmtTemp(91.94), "92°");
    assert.equal(model.fmtTemp(91.94, true), "91.9 °C");
    assert.equal(model.fmtUptime("1d 3h 16m", "long"), "1d 3h");
    assert.equal(model.fmtUptime("1d 3h 16m", "short"), "1d");
    assert.equal(model.fmtUptime("", "short"), "--");
    assert.equal(model.fmtUptime(null, "long"), "--");
    assert.equal(model.ago(20000), "just now");
    assert.equal(model.ago(13 * minute), "13 min ago");
    assert.equal(model.ago(5 * 60 * minute), "5 h ago");
    assert.equal(model.ago(72 * 60 * minute), "3 days ago");
    assert.equal(model.ago(NaN), "never");
    assert.equal(model.agoShort(13 * minute), "13m");
    assert.equal(model.agoShort(3 * 60 * minute), "3h");
    assert.equal(model.agoShort(NaN), "--");
    assert.equal(model.fmtRate(0.012), "0.01 MB/s");
    assert.equal(model.fmtRate(1.61), "1.6 MB/s");
    assert.equal(model.cleanCpu("Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz"), "Intel Core i7-9700K");
    assert.equal(model.cleanCpu(null), "--");

    // The fleet, its summary and its bar readout.
    const fleetHosts = ["fuji", "hiyori", "ibuki", "myoko", "rakku", "tate", "unzen", "yari"].map(name =>
        host({name, services: {failed: name === "unzen" ? 2 : 0}, status: name === "hiyori" ? "down" : "up"}));
    const fleetNow = model.fleetView(fleetHosts, {}, now);
    assert.equal(fleetNow.state, "ready");
    assert.equal(fleetNow.tone, "danger");
    same(Array.from(fleetNow.problems, v => v.name), ["unzen"]);
    same(Array.from(model.summaryVariants(fleetNow, true)),
        ["8 hosts · 1 problem: unzen", "1 problem: unzen", "1 problem: unzen", "1 problem", "1"]);
    assert.equal(model.summaryVariants(fleetNow, false, "Fleet: ")[0], "Fleet: 8 hosts · 1 problem");
    same(Array.from(model.sortHosts(fleetNow.hosts, "name"), v => v.name), ["fuji", "hiyori", "ibuki", "myoko", "rakku", "tate", "unzen", "yari"]);
    same(Array.from(model.sortHosts(fleetNow.hosts, "status"), v => v.name).slice(0, 2), ["unzen", "hiyori"], "worst first, then muted");
    same(Array.from(model.sortHosts(model.fleetView([host({name: "a", cpuPercent: 3}), host({name: "b", cpuPercent: 30}), host({name: "c"})], {}, now).hosts, "cpu"), v => v.name), ["b", "a", "c"]);
    same(model.barReadout(fleetNow), {shape: "up", tone: "danger", text: "1"});
    same(model.barReadout(model.fleetView([host()], {}, now)), {shape: "up", tone: "normal", text: ""});
    same(model.barReadout(model.fleetView([], {}, now)), {shape: "up", tone: "muted", text: ""});
    for (const word of ["unavailable", "error"]) {
        const f = model.fleetView(word, {}, now);
        assert.equal(f.state, word);
        same(model.barReadout(f), {shape: "down", tone: "muted", text: "--"});
        assert.equal(model.summaryVariants(f, true)[0], "Beszel --");
    }
    same(model.barReadout(model.fleetView("loading", {}, now)), {shape: "pending", tone: "muted", text: ""});
    assert.equal(model.summaryVariants(model.fleetView("loading", {}, now), true)[0], "Asking Beszel…");
    assert.equal(model.summaryVariants(model.fleetView([], {}, now), true)[0], "No hosts in Beszel");
    assert.equal(model.summaryVariants(model.fleetView([host()], {}, now), true)[0], "1 host · no problems");

    // History retention: enough for the five-minute rule, one per sample.
    const samples = Array.from({length: 12}, (_, i) => ({lastSeen: now - (11 - i) * minute, cpuPercent: 95}));
    const kept = model.trimHistory(samples.concat(samples.slice(-2)).reverse(), now);
    assert.equal(kept[kept.length - 1].lastSeen, now);
    assert.equal(kept.length, 8, "7 minutes and one sample before them");
    assert.equal(new Set(kept.map(s => s.lastSeen)).size, kept.length);
    assert.equal(model.sustainedMetric(host({cpuPercent: 95}), kept, now), "cpuPercent", "trimmed history still proves five minutes");
    assert.equal(model.trimHistory([{lastSeen: now + minute}, {lastSeen: "bad"}], now).length, 0);

    // The drill-down helper's output.
    const detail = model.parseDetail(JSON.stringify({system: "unzen",
        metrics: [{t: "2026-10-23 21:14:00Z", cpu: 9, mem: 10, disk: 33, net: 0.01}, {t: "2026-10-23 21:13:00Z", cpu: 5, mem: 10, disk: 33, net: 0}],
        failed: ["snapraid-sync.service", 3], smart: [{system: "unzen", name: "/dev/sda"}, {system: "ibuki"}]}), "unzen");
    assert.equal(detail.state, "ready");
    same(Array.from(detail.metrics, p => p.cpu), [5, 9], "oldest first");
    same(Array.from(detail.failed), ["snapraid-sync.service"]);
    assert.equal(detail.smart.length, 1);
    assert.equal(model.parseDetail(JSON.stringify({system: "unzen", metrics: null, failed: null, smart: null}), "unzen").metrics, null);
    for (const text of ["unavailable", "error", "", "{", JSON.stringify({system: "ibuki"})]) {
        assert.notEqual(model.parseDetail(text, "unzen").state, "ready", text);
    }
    same(model.series(detail.metrics, "cpu"), {values: [5, 9], max: 9, now: 9});
    same(model.series([], "cpu"), {values: [], max: 0, now: null});
    assert.equal(JSON.stringify(fleet), before, "views do not mutate input");
    console.log("beszel-model: views, formats, sort, readout, history and drill-down parsing pass");
}
