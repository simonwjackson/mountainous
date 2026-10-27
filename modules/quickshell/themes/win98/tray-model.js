.pragma library
// What the Win98 tray draws for each control: the icon, the count badge and
// the tooltip, as pure functions of plain values the Desktop reads from the
// shared data owners. The wording is the approved mock's (tipText in
// /tmp/win98-mock/win98.js); only the builder's lines come from
// builder-gate.js, without its "Click ..." line, because a click opens the
// window here.

// The order icons sit in, left to right; the clock follows.
var ORDER = ["dict", "bt", "wifi", "vol", "bri", "oci", "disk", "fleet", "builder", "ntf", "bat"];

// The Super+O chord's keys (hyprland.lua topbar-access submap).
var CHORD = { bt: "B", wifi: "W", vol: "S", bri: "L", oci: "C", disk: "D", fleet: "F", builder: "R" };

var LABEL = {
    start: "Start", dict: "Dictation", bt: "Bluetooth", wifi: "Wi-Fi", vol: "Sound", bri: "Brightness",
    oci: "OCI egress", disk: "Server storage", fleet: "Fleet", builder: "Remote builds", ntf: "Notifications",
    bat: "Battery", clock: "Date/Time", more: "More icons", tasks: "More windows"
};

function dots(s) { return String(s).replace(/\u2026/g, "..."); }

function volumeIcon(muted, percent) {
    if (muted) return "volume-muted";
    if (percent <= 0) return "volume-0";
    return percent <= 50 ? "volume-1" : "volume-2";
}

// Four rungs; a slashed icon is the radio off.
function wifiLevel(connected, signal) {
    if (!connected) return 0;
    return signal >= 0.75 ? 4 : signal >= 0.5 ? 3 : signal >= 0.25 ? 2 : 1;
}
function wifiIcon(off, level) { return off ? "wifi-off" : "wifi-" + level; }

function ociIcon(tone) {
    return tone === "danger" ? "oci-danger" : tone === "warning" ? "oci-warning" : tone === "muted" ? "oci-muted" : "oci-normal";
}

// StorageHealth: the first check is grey, a failed or stale check warns.
function diskIcon(state, worst) {
    if (state === "loading") return "disk-muted";
    if (state !== "ready") return "disk-warn";
    return worst === "bad" ? "disk-bad" : worst === "warn" ? "disk-warn" : "disk-ok";
}

function bellIcon(viewKind, count) {
    return viewKind === "ready" && count > 0 ? "bell" : "bell-muted";
}

// look: { off, grey, wait, warn, unknown } from builder-gate.js.
function builderIcon(look) {
    if (look.wait) return "builder-wait";
    if (look.warn) return "builder-warn";
    if (look.unknown) return "builder-unknown";
    if (look.off) return look.grey ? "builder-off-grey" : "builder-off";
    return look.grey ? "builder-grey" : "builder";
}

function micIcon(state) {
    return state === "failed" ? "mic-failed" : state === "working" ? "mic-working" : "mic-recording";
}

function batteryIcon(indicator) {
    return indicator === "bolt" ? "battery-bolt" : indicator === "plug" ? "battery-plug" : "battery";
}
function batteryColor(tone) {
    return tone === "danger" ? "#ff0000" : tone === "warning" ? "#e0c000" : "#00a000";
}

function notificationCount(count) { return count > 99 ? "99+" : String(count); }

function badge(id, d) {
    if (id === "disk") return d.disk.state === "ready" && d.disk.issues > 0 ? String(d.disk.issues) : "";
    if (id === "ntf") return d.ntf.view === "ready" ? notificationCount(d.ntf.count) : d.ntf.view === "offline" ? "!" : "";
    if (id === "builder") return d.builder.ready && !d.builder.pending && d.builder.running > 0 ? String(d.builder.running) : "";
    return "";
}

// 12-hour time with AM or PM, as Win98's tray clock.
function clock(date) {
    var h = date.getHours();
    var m = date.getMinutes();
    return { time: (h % 12 || 12) + ":" + (m < 10 ? "0" : "") + m, ampm: h < 12 ? "AM" : "PM" };
}

function tooltip(id, d) {
    if (id === "start") return "Click here to begin.";
    if (id === "vol") return "Volume " + (d.vol.muted ? "muted" : d.vol.percent + "%") + (d.vol.name ? "\n" + d.vol.name : "");
    if (id === "bat") {
        return d.bat.percent + "% " + (d.bat.onBattery ? "remaining"
            : d.bat.indicator === "plug" ? "on AC, full" : d.bat.indicator === "bolt" ? "charging" : "on AC");
    }
    if (id === "oci") {
        if (d.oci.state !== "ready") return "OCI egress: " + dots(d.oci.stateText);
        return "OCI egress this month\n" + d.oci.rows.map(function (r) { return r.name + " " + r.value; }).join("\n");
    }
    if (id === "disk") {
        return "Server storage: " + dots(d.disk.label).replace(/^Disks /, "").replace("...", "checking...")
            + "\n" + dots(d.disk.statusText);
    }
    if (id === "ntf") {
        if (d.ntf.view === "offline") return "Notifications offline\nnotifyd is not answering.";
        if (d.ntf.view === "connecting") return "Connecting to notifyd...";
        return (d.ntf.count > 0 ? notificationCount(d.ntf.count) + " notifications" : "No notifications")
            + (d.ntf.urgent > 0 ? "\n" + d.ntf.urgent + " urgent" : "")
            + (d.ntf.badgeKind !== "none" && d.ntf.badgeText ? "\n" + d.ntf.badgeText : "");
    }
    if (id === "bt") {
        if (!d.bt.present) return "No Bluetooth adapter";
        return "Bluetooth " + (d.bt.count > 0 ? d.bt.count + " connected" : d.bt.on ? "on" : "off");
    }
    if (id === "wifi") {
        if (!d.wifi.present) return "No Wi-Fi adapter";
        if (!d.wifi.hw) return "Wi-Fi blocked by the radio switch";
        if (!d.wifi.enabled) return "Wi-Fi off";
        return d.wifi.name ? "Wi-Fi " + d.wifi.name + ", " + Math.round(d.wifi.signal * 100) + "%" : "Wi-Fi on, not connected";
    }
    if (id === "bri") return "Brightness " + d.bri.level + "%";
    if (id === "clock") return d.clock.date;
    if (id === "dict") return d.dict.text;
    // The fleet's summary with the problem hosts named (beszel-model.js
    // summaryVariants), and how old it is when Beszel stopped answering.
    if (id === "fleet") return d.fleet.summary + (d.fleet.stale ? "\n" + d.fleet.age : "");
    if (id === "builder") {
        return d.builder.tooltip.map(dots).filter(function (l) { return !/^Click /.test(l); }).join("\n");
    }
    return LABEL[id] || id;
}

// What the tray chevron's menu shows beside each name: the value the tray
// would have drawn (the Platinum top bar's words, by control).
function overflowValue(id, d) {
    if (id === "bt") return !d.bt.on ? "Off" : d.bt.count > 0 ? d.bt.count + " connected" : "On";
    if (id === "wifi") return d.wifi.name || "Not connected";
    if (id === "vol") return d.vol.muted ? "Muted" : d.vol.percent + "%";
    if (id === "bri") return d.bri.level + "%";
    if (id === "oci") return d.oci.state === "ready" ? d.oci.rows.map(function (r) { return r.value; }).join(" ") : dots(d.oci.stateText);
    if (id === "disk") return dots(d.disk.label).replace(/^Disks /, "");
    if (id === "fleet") return d.fleet.short;
    if (id === "builder") return dots(d.builder.barText);
    if (id === "ntf") return d.ntf.view === "ready" ? notificationCount(d.ntf.count) : d.ntf.view === "offline" ? "offline" : "";
    if (id === "dict") return d.dict.text;
    return "";
}

// The dictation band's words (the same words the Platinum top bar uses).
function dictationText(statusText, backendLabel, queueCount, queueText) {
    var v = statusText;
    if (backendLabel) v += " \u00b7 " + backendLabel;
    if (queueCount > 1) v += " \u00b7 " + queueText;
    return v;
}
