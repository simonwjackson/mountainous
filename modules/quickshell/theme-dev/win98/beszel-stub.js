// DEV HARNESS (not delivered): a stand-in for the beszel-status helper
// (modules/quickshell/beszel-status.sh), answering from the approved
// mocks' fleet fixtures (fleet-fixtures.json, a copy of
// /tmp/win98-hud-mock/data/platinum-fixtures.js). The fixture's name is in
// $XDG_STATE_HOME/fleet-fixture; the harness writes it.
//
//   node beszel-stub.js              the systems, list_systems' shape
//   node beszel-stub.js host <name>  {system, metrics, failed, smart}
//
// Timestamps move with the clock, so every sample is as old now as it was
// at the fixture's own "now". "stale-fail" answers unavailable (the hub
// stopped answering after a good sample); loading answers only once the
// fixture changes.
const fs = require("fs");
const path = require("path");
const all = JSON.parse(fs.readFileSync(path.join(__dirname, "fleet-fixtures.json"), "utf8"));
const fixtureFile = path.join(process.env.XDG_STATE_HOME || "/tmp", "fleet-fixture");
function current() {
    try { return fs.readFileSync(fixtureFile, "utf8").trim() || "unzen-problem"; } catch (e) { return "unzen-problem"; }
}
let name = current();
// Loading: no answer while the fixture stays "loading" (at most a minute,
// so nothing outlives a session); then the answer for the next fixture.
if (name === "loading") {
    const started = Date.now();
    const wait = setInterval(() => {
        const next = current();
        if (next !== "loading" || Date.now() - started > 60000) { clearInterval(wait); name = next; main(); }
    }, 200);
} else main();

function main() {
    if (name === "stale-fail" || name === "unavailable") { console.log("unavailable"); return; }
    const fx = all[name === "stale" ? "stale" : name];
    if (!fx || fx.helper === "unavailable") { console.log("unavailable"); return; }
    if (fx.helper === "error") { console.log("error"); return; }
    const shift = Date.now() - Date.parse(fx.now);
    const at = s => typeof s === "string" && s ? new Date(Date.parse(s.replace(" ", "T")) + shift).toISOString().replace("T", " ") : s;
    const systems = fx.systems.map(s => Object.assign({}, s, { lastSeen: at(s.lastSeen) }));
    const args = process.argv.slice(2);
    if (args[0] !== "host") { console.log(JSON.stringify(systems)); return; }
    const host = systems.find(s => s.name === args[1]);
    if (!host) { console.log("error"); return; }
    // 30 one-minute points over the last hour's half, as the helper's
    // get_system_metrics call (1 h, 30 points).
    const metrics = [];
    for (let i = 0; i < 30; i++) {
        const t = new Date(Date.now() - (29 - i) * 120000).toISOString().replace("T", " ");
        const wob = Math.sin(i / 3 + host.name.length) * 0.5 + 0.5;
        metrics.push({ t, cpu: Math.round(Math.max(0, (host.cpuPercent || 0) * (0.6 + 0.8 * wob)) * 10) / 10,
            mem: host.memoryPercent, disk: host.diskPercent,
            net: Math.round((host.bandwidthMbPerSec || 0) * (0.3 + 1.4 * wob) * 1000) / 1000 });
    }
    const capacityGb = c => { if (!c) return null; const [n, u] = String(c).split(" "); return Number(n) * (u === "TB" ? 1000 : 1); };
    const smart = (fx.smart || []).filter(d => d.system === host.name).map(d => {
        const st = d.status || d.smartState || "UNKNOWN";
        return { system: d.system, name: d.name, model: d.model, capacityGb: d.capacityGb || capacityGb(d.capacity),
            smartState: st, healthy: st === "PASSED", temperatureC: d.temperatureC, powerOnHours: d.powerOnHours, attributes: [] };
    });
    console.log(JSON.stringify({ system: host.name, metrics, failed: (fx.failedUnits || {})[host.name] || [], smart }));
}
