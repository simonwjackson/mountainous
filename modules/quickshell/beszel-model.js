.pragma library

// list_systems rows are display data. Time is supplied by the caller in epoch
// milliseconds; history contains earlier rows for this host (same lastSeen
// schema). The panel owns retention. No clock or mutable history lives here.
function sampleTime(value) {
    return typeof value === "number" ? value
        : typeof value === "string" ? Date.parse(value.replace(" ", "T")) : NaN;
}

function atLeast(value, threshold) {
    return typeof value === "number" && Number.isFinite(value) && value >= threshold;
}

function sustainedLoad(host, history, now) {
    const cutoff = now - 300000;
    const samples = (Array.isArray(history) ? history : []).concat([host])
        .filter(sample => sample && Number.isFinite(sampleTime(sample.lastSeen)) && sampleTime(sample.lastSeen) <= now)
        .slice().sort((a, b) => sampleTime(a.lastSeen) - sampleTime(b.lastSeen));
    // Keep one sample at/before the window to prove five minutes of coverage.
    let start = -1;
    for (let i = 0; i < samples.length; i++) {
        if (sampleTime(samples[i].lastSeen) <= cutoff) start = i;
    }
    if (start < 0) return false;
    const window = samples.slice(start);
    if (now - sampleTime(window[window.length - 1].lastSeen) > 180000) return false;
    for (let i = 1; i < window.length; i++) {
        if (sampleTime(window[i].lastSeen) - sampleTime(window[i - 1].lastSeen) > 180000) return false;
    }
    return ["cpuPercent", "memoryPercent"].some(metric => window.every(sample => atLeast(sample[metric], 90)));
}

/**
 * @param {object} host A list_systems row.
 * @param {object[]} history Earlier rows for this host; never mutated.
 * @param {number} now Epoch milliseconds (explicit for deterministic aging).
 * @param {object[]} smartDevices Optional list_smart_devices.devices, matched by system/name.
 * @returns {'normal'|'muted'|'warning'|'danger'}
 */
function hostTone(host, history, now, smartDevices) {
    if (!host) return "muted";
    const failedSmart = (Array.isArray(smartDevices) ? smartDevices : []).some(device =>
        device && (device.system === host.name || device.system === host.id && host.id !== undefined)
        // The MCP tool also emits healthy:false for UNKNOWN, not a failure.
        && (device.healthy === false && device.smartState !== "UNKNOWN" || device.smartState === "FAILED"
            || Array.isArray(device.attributes) && device.attributes.some(attribute => attribute && attribute.failing === true)));
    if (failedSmart) return "danger";
    if (["up", "down"].indexOf(host.status) < 0) return "muted";
    if (host.status === "down") {
        return ["fuji", "ibuki", "rakku", "tate", "unzen", "yari"].indexOf(host.name) >= 0 ? "danger" : "muted";
    }
    const disks = [host.diskPercent].concat(Object.values(host.extraFilesystemPercent || {}));
    const failedServices = host.services && host.services.failed;
    if (atLeast(failedServices, 0) && failedServices > 0
        || disks.some(value => atLeast(value, 95)) || atLeast(host.temperatureC, 100)) return "danger";
    const age = now - sampleTime(host.lastSeen);
    if (disks.some(value => atLeast(value, 85)) || atLeast(host.temperatureC, 85)
        || !Number.isFinite(age) || age > 180000 || sustainedLoad(host, history, now)) return "warning";
    return "normal";
}

// Both fleet functions take the helper's systems array or its unavailable/error
// word. Histories are keyed by host name; SMART input is the optional full array.
function fleetTone(hosts, historyByHost, now, smartDevices) {
    if (!Array.isArray(hosts) || hosts.length === 0) return "muted";
    const tones = hosts.map(host => hostTone(host, (historyByHost || {})[host.name], now, smartDevices));
    for (const tone of ["danger", "warning", "normal"]) {
        if (tones.indexOf(tone) >= 0) return tone;
    }
    return "muted";
}

function summaryText(hosts, historyByHost, now, smartDevices) {
    if (!Array.isArray(hosts)) return "Beszel --";
    const problems = hosts.filter(host => ["danger", "warning"].indexOf(
        hostTone(host, (historyByHost || {})[host.name], now, smartDevices)) >= 0).length;
    return hosts.length + (hosts.length === 1 ? " host" : " hosts") + " · "
        + problems + (problems === 1 ? " problem" : " problems");
}

// ---------------------------------------------------------------- views
// What the Fleet views draw for one host and for the fleet. hostTone stays
// the one rule; hostView explains it. Untrusted values (a host that is not
// up) never set a tone of their own and are drawn greyed.
var DESKTOPS = ["myoko", "hiyori"];
var RANK = {normal: 0, quiet: 0, muted: 0, warning: 1, danger: 2};

function num(value) {
    return typeof value === "number" && Number.isFinite(value) ? value : null;
}

// The root filesystem first, then every extra filesystem by name.
function filesystems(host) {
    const out = [{name: "/", pct: num(host && host.diskPercent)}];
    const extra = host && host.extraFilesystemPercent && typeof host.extraFilesystemPercent === "object"
        ? host.extraFilesystemPercent : {};
    for (const name of Object.keys(extra).sort()) out.push({name: name, pct: num(extra[name])});
    return out;
}

function fsTone(pct) {
    return pct === null ? "normal" : pct >= 95 ? "danger" : pct >= 85 ? "warning" : "normal";
}

function tempTone(c) {
    return c === null || c === 0 ? "normal" : c >= 100 ? "danger" : c >= 85 ? "warning" : "normal";
}

function fmtPct(pct) {
    if (pct === null || pct === undefined || !Number.isFinite(pct)) return "--";
    if (pct > 0 && pct < 0.5) return "<1%";
    return Math.round(pct) + "%";
}

// 0 °C is the VMs' "no sensor"; it reads as a dash, never as a value.
function fmtTemp(c, long) {
    if (c === null || c === undefined || !Number.isFinite(c) || c === 0) return "--";
    return long ? c.toFixed(1) + " °C" : Math.round(c) + "°";
}

// Beszel's "1d 3h 16m": two units ("long"), or the first only ("short").
function fmtUptime(text, mode) {
    if (typeof text !== "string" || text.trim() === "") return "--";
    const parts = text.trim().split(/\s+/);
    return mode === "short" ? parts[0] : parts.slice(0, 2).join(" ");
}

function ago(ms) {
    if (!Number.isFinite(ms)) return "never";
    const m = Math.max(0, Math.round(ms / 60000));
    if (m < 1) return "just now";
    if (m < 60) return m + " min ago";
    const h = Math.round(m / 60);
    if (h < 48) return h + " h ago";
    return Math.round(h / 24) + " days ago";
}

function agoShort(ms) {
    if (!Number.isFinite(ms)) return "--";
    const m = Math.max(0, Math.round(ms / 60000));
    return m < 60 ? m + "m" : m < 2880 ? Math.round(m / 60) + "h" : Math.round(m / 1440) + "d";
}

// Which metric held at 90% or more for five minutes, or "".
function sustainedMetric(host, history, now) {
    if (!sustainedLoad(host, history, now)) return "";
    // sustainedLoad already proved coverage; name the metric that held.
    const cutoff = now - 300000;
    const samples = (Array.isArray(history) ? history : []).concat([host])
        .filter(sample => sample && Number.isFinite(sampleTime(sample.lastSeen)) && sampleTime(sample.lastSeen) <= now);
    let startTime = -Infinity;
    for (const sample of samples) {
        const t = sampleTime(sample.lastSeen);
        if (t <= cutoff && t > startTime) startTime = t;
    }
    const window = samples.filter(sample => sampleTime(sample.lastSeen) >= startTime);
    for (const metric of ["cpuPercent", "memoryPercent"]) {
        if (window.every(sample => atLeast(sample[metric], 90))) return metric;
    }
    return "";
}

function failedSmartDevices(host, smartDevices) {
    return (Array.isArray(smartDevices) ? smartDevices : []).filter(device =>
        device && (device.system === host.name || device.system === host.id && host.id !== undefined)
        && (device.healthy === false && device.smartState !== "UNKNOWN" || device.smartState === "FAILED"
            || Array.isArray(device.attributes) && device.attributes.some(attribute => attribute && attribute.failing === true)));
}

/**
 * One host as the Fleet views draw it.
 * @returns {{name, status, trusted, tone, reasons: {tone, text, short}[], cpu, mem, disk, temp, failed, uptime, seen, host}}
 */
function hostView(host, history, now, smartDevices) {
    const status = host.status;
    const trusted = status === "up";
    const tone = hostTone(host, history, now, smartDevices);
    const fss = filesystems(host);
    let worstFs = fss[0];
    for (const fs of fss) if ((fs.pct === null ? -1 : fs.pct) > (worstFs.pct === null ? -1 : worstFs.pct)) worstFs = fs;
    const failed = host.services ? num(host.services.failed) : null;
    const c = num(host.temperatureC);
    const seen = sampleTime(host.lastSeen);
    const reasons = [];
    for (const device of failedSmartDevices(host, smartDevices)) {
        const disk = String(device.name || "disk").replace(/^\/dev\//, "");
        reasons.push({tone: "danger", text: disk + " failed SMART", short: disk + " SMART"});
    }
    if (status === "down") {
        reasons.push({tone: DESKTOPS.indexOf(host.name) >= 0 ? "muted" : "danger",
            text: "Down, seen " + ago(now - seen), short: "Down"});
    } else if (status === "paused") {
        reasons.push({tone: "muted", text: "Paused in Beszel", short: "Paused"});
    } else if (status !== "up") {
        reasons.push({tone: "muted", text: "Waiting for its first report", short: "Pending"});
    }
    if (trusted) {
        if (failed !== null && failed > 0) {
            reasons.push({tone: "danger", text: failed + (failed === 1 ? " failed unit" : " failed units"),
                short: failed + " failed"});
        }
        const sorted = fss.slice().sort((a, b) => (b.pct === null ? 0 : b.pct) - (a.pct === null ? 0 : a.pct));
        for (const fs of sorted) {
            const t = fsTone(fs.pct);
            if (t !== "normal") reasons.push({tone: t, text: (fs.name === "/" ? "Disk" : fs.name) + " " + fmtPct(fs.pct),
                short: (fs.name === "/" ? "disk" : fs.name) + " " + fmtPct(fs.pct)});
        }
        if (tempTone(c) !== "normal") reasons.push({tone: tempTone(c), text: fmtTemp(c, true), short: fmtTemp(c)});
        const metric = sustainedMetric(host, history, now);
        if (metric !== "") {
            const label = metric === "cpuPercent" ? "CPU" : "Memory";
            reasons.push({tone: "warning", text: label + " at 90% or more for 5 min", short: label + " " + fmtPct(host[metric])});
        }
        const age = now - seen;
        if (!Number.isFinite(age) || age > 180000) {
            reasons.push({tone: "warning", text: "No report " + (Number.isFinite(age) ? "for " + ago(age).replace(/ ago$/, "") : "yet"),
                short: Number.isFinite(age) ? agoShort(age) + " old" : "no report"});
        }
    }
    reasons.sort((a, b) => RANK[b.tone] - RANK[a.tone]);
    return {
        name: host.name, status: status, trusted: trusted, tone: tone, reasons: reasons,
        cpu: {pct: num(host.cpuPercent)},
        mem: {pct: num(host.memoryPercent)},
        disk: {pct: worstFs.pct, fs: worstFs.name, tone: trusted ? fsTone(worstFs.pct) : "normal"},
        fss: fss,
        temp: {c: c === 0 ? null : c, noSensor: c === 0, tone: trusted ? tempTone(c) : "normal"},
        failed: {n: failed, total: host.services ? num(host.services.total) : null,
            tone: trusted && failed !== null && failed > 0 ? "danger" : "normal"},
        uptime: typeof host.uptime === "string" ? host.uptime : null,
        seen: seen,
        host: host
    };
}

/**
 * The fleet: the helper's systems array or its unavailable/error word.
 * smartDevices is every SMART device the drill-downs have fetched so far.
 */
function fleetView(hosts, historyByHost, now, smartDevices) {
    if (!Array.isArray(hosts)) {
        return {state: hosts === "error" ? "error" : hosts === "loading" ? "loading" : "unavailable",
            tone: "muted", hosts: [], problems: []};
    }
    const views = hosts.map(host => hostView(host, (historyByHost || {})[host.name], now, smartDevices));
    const problems = views.filter(view => RANK[view.tone] > 0);
    return {state: "ready", tone: fleetTone(hosts, historyByHost, now, smartDevices), hosts: views, problems: problems};
}

function plural(n, word) { return n + " " + word + (n === 1 ? "" : "s"); }

// The summary shortens before it is cut: full, then shorter, then the count.
function summaryVariants(fleet, withNames, prefix) {
    const p = prefix || "";
    if (fleet.state === "loading") return [p + "Asking Beszel…", "Loading…"];
    if (fleet.state !== "ready") return [p + "Beszel --", "Beszel --"];
    if (fleet.hosts.length === 0) return [p + "No hosts in Beszel", "No hosts"];
    const n = fleet.problems.length;
    const words = n ? plural(n, "problem") : "no problems";
    const names = n && withNames ? ": " + fleet.problems.map(view => view.name).join(", ") : "";
    return [p + plural(fleet.hosts.length, "host") + " · " + words + names, p + words + names, words + names, words, n ? String(n) : "ok"];
}

// Name order by default; "status" puts the worst first, then the muted,
// then by name; a value column puts the largest first.
function sortHosts(views, sort) {
    const out = (Array.isArray(views) ? views : []).slice();
    const byName = (a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
    const keys = {
        cpu: view => view.cpu.pct, mem: view => view.mem.pct, disk: view => view.disk.pct,
        temp: view => view.temp.c, failed: view => view.failed.n,
        up: view => { const m = /(\d+)d/.exec(view.uptime || ""); return m ? Number(m[1]) : 0; }
    };
    if (sort === "status") {
        out.sort((a, b) => RANK[b.tone] - RANK[a.tone] || (b.tone === "muted") - (a.tone === "muted") || byName(a, b));
    } else if (keys[sort]) {
        const key = keys[sort];
        out.sort((a, b) => (key(b) === null ? -1 : key(b)) - (key(a) === null ? -1 : key(a)) || byName(a, b));
    } else {
        out.sort(byName);
    }
    return out;
}

// The bar's readout: the light's shape and tone, and its text: a count only
// when there are problems, "--" without data.
function barReadout(fleet) {
    if (fleet.state === "loading") return {shape: "pending", tone: "muted", text: ""};
    if (fleet.state !== "ready") return {shape: "down", tone: "muted", text: "--"};
    const n = fleet.problems.length;
    return {shape: "up", tone: fleet.hosts.length ? fleet.tone : "muted", text: n > 0 ? String(n) : ""};
}

// Keep about five minutes of samples per host for the CPU and memory rule:
// one sample at or before the window plus everything after it, newest last,
// one per lastSeen. The input is never mutated.
function trimHistory(samples, now, keepMs) {
    const keep = keepMs === undefined ? 420000 : keepMs;
    const seen = {};
    const out = [];
    for (const sample of (Array.isArray(samples) ? samples : [])) {
        const t = sampleTime(sample && sample.lastSeen);
        if (!Number.isFinite(t) || t > now || seen[t]) continue;
        seen[t] = true;
        out.push(sample);
    }
    out.sort((a, b) => sampleTime(a.lastSeen) - sampleTime(b.lastSeen));
    let start = 0;
    for (let i = 0; i < out.length; i++) if (sampleTime(out[i].lastSeen) <= now - keep) start = i;
    return out.slice(start);
}

// beszel-status host <name>: {system, metrics, failed, smart}. Anything else
// is an unavailable/error word. Each part may be null when its call failed.
function parseDetail(text, name) {
    const value = typeof text === "string" ? text.trim() : "";
    if (value === "unavailable" || value === "error" || value === "") return {state: value || "error"};
    let data;
    try { data = JSON.parse(value); } catch (e) { return {state: "error"}; }
    if (!data || typeof data !== "object" || data.system !== name) return {state: "error"};
    const points = Array.isArray(data.metrics) ? data.metrics.filter(p => p && typeof p === "object").map(p => ({
        t: sampleTime(p.t), cpu: num(p.cpu), mem: num(p.mem), disk: num(p.disk), net: num(p.net)
    })).filter(p => Number.isFinite(p.t)).sort((a, b) => a.t - b.t) : null;
    const failed = Array.isArray(data.failed) ? data.failed.filter(u => typeof u === "string") : null;
    const smart = Array.isArray(data.smart) ? data.smart.filter(d => d && typeof d === "object" && d.system === name) : null;
    return {state: "ready", system: name, metrics: points, failed: failed, smart: smart};
}

// One sparkline's series and its labels, from parsed metric points.
function series(points, key) {
    const values = (Array.isArray(points) ? points : []).map(p => p[key]).filter(v => v !== null && v !== undefined);
    if (values.length === 0) return {values: [], max: 0, now: null};
    return {values: values, max: Math.max.apply(null, values), now: values[values.length - 1]};
}

function fmtRate(mbps) {
    if (mbps === null || mbps === undefined || !Number.isFinite(mbps)) return "--";
    return (mbps < 0.1 ? mbps.toFixed(2) : mbps.toFixed(1)) + " MB/s";
}

// "Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz" -> "Intel Core i7-9700K".
function cleanCpu(text) {
    if (typeof text !== "string" || text.trim() === "") return "--";
    return text.replace(/\((R|TM)\)/g, "").replace(/\s+CPU\s+@.*$/, "").replace(/\s{2,}/g, " ").trim();
}
