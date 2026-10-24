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
