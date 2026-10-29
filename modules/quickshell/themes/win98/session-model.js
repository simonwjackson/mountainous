.pragma library
// The Win98 session pieces as pure functions: the Shut Down dialog's
// choices and layout, System Properties' layout and facts, the volume
// and brightness pop-up, and the Layout window's yield plan. Sizes are in units (1 u = 2 device px at 1.5).
// Every threshold is a guess until it is measured on Myoko.

// Shut Down Myoko: Win98's choices plus Log off. `what` is the session
// command the Desktop runs (the same commands as Platinum's runSession).
// closes: the choice ends the session's windows (the red warning line).
function shutdownChoices(user) {
    return [
        { id: "standby", text: "Stand &by", what: "sleep", closes: false },
        { id: "shutdown", text: "&Shut down", what: "shutdown", closes: true },
        { id: "restart", text: "&Restart", what: "restart", closes: true },
        { id: "logoff", text: "&Log off " + (user || "simon"), what: "logout", closes: true }
    ];
}
var WARNING = "Open windows close without saving.";

// The choice the dialog opens on: the last one OK'd (Win98 remembered it),
// else Stand by.
function initialChoice(remembered) {
    var ids = shutdownChoices("").map(function (c) { return c.id; });
    var r = String(remembered || "").trim();
    return ids.indexOf(r) >= 0 ? r : "standby";
}

// The dialog: 316 u wide at most; the computer icon goes under 250 u;
// a short screen drops the warning line's reserved row before the
// window scrolls (Win98Window scrolls its body, the caption stays).
var SHUT = { width: 316, iconMin: 250 };
function shutPlan(widthU) {
    var w = Math.max(0, Math.min(SHUT.width, widthU - 4));
    return { width: w, icon: w >= SHUT.iconMin };
}

// System Properties ▸ General: 420 u at most; the picture goes above the
// facts under 340 u and goes under 220 u.
var SYS = { width: 420, stack: 340, picture: 220 };
function sysPlan(widthU) {
    var w = Math.max(0, Math.min(SYS.width, widthU - 4));
    return { width: w, stack: w < SYS.stack, picture: w >= SYS.picture };
}

// "1 day, 18:26", as Platinum's About writes the uptime.
function uptimeText(seconds) {
    if (!(seconds >= 0)) return "Unknown";
    var days = Math.floor(seconds / 86400);
    var hours = Math.floor(seconds % 86400 / 3600);
    var minutes = Math.floor(seconds % 3600 / 60);
    var clock = hours + ":" + (minutes < 10 ? "0" : "") + minutes;
    return days > 0 ? days + (days === 1 ? " day, " : " days, ") + clock : clock;
}

// The General sheet's facts, from the same readers as Platinum's About
// (SystemFacts.qml): [{ heading, lines: [text] }].
function sysFacts(f) {
    var host = f.host ? f.host.charAt(0).toUpperCase() + f.host.slice(1) : "Unknown";
    var v = f.version || {};
    var computer = [host];
    if (f.product) computer.push(f.product);
    var system = ["NixOS " + (v.nixosVersion || "Unknown")];
    if (f.generation) system.push("Generation " + f.generation);
    system.push("Revision: " + (v.configurationRevision || "Not recorded"));
    return [
        { heading: "System:", lines: system },
        { heading: "Registered to:", lines: [f.user || "simon"] },
        { heading: "Computer:", lines: computer },
        { heading: "Running for:", lines: [uptimeText(f.uptime)] }
    ];
}

// The volume and brightness pop-up: a raised box 40 u tall, 132 u wide at
// most, above its tray icon (or the place the icon moved to), kept 2 u
// inside the screen. Under 112 u the word goes and the value stays.
// anchorX, anchorW: the icon's place in units; screenW in units.
var POP = { width: 132, labelMin: 112, height: 40, hold: 1500, arm: 2000 };
function popupPlan(screenW, anchorX, anchorW) {
    var w = Math.max(0, Math.min(POP.width, screenW - 4));
    var centre = anchorX + anchorW / 2;
    var x = Math.max(2, Math.min(screenW - w - 2, Math.round(centre - w / 2)));
    // The block bar: 1 u bevel, 2 u in, 3-u blocks with 1-u gaps.
    var bar = w - 12;
    return { x: x, width: w, label: w >= POP.labelMin, bar: bar, blocks: Math.floor((bar - 4 + 1) / 4) };
}
function popupText(kind, value, muted) {
    return { label: kind === "vol" ? "Volume" : "Brightness", value: kind === "vol" && muted ? "Muted" : Math.round(value) + "%" };
}

// The Layout window (Win98LayoutWindow.qml): 316 u wide at most, 2 u
// inside the screen each side. The capacity group's content is the window
// less 52 u (frame 3, window padding 6, sheet 8 and group 9, each side);
// its three buttons share it with 6-u gaps.
//
// Width: a button under 40 u drops its picture (the label stays); under
// 34 u the buttons stand in one column.
// Height, when the window's natural height (natural, units) is over the
// room: these yield in order, each only while the window is still too
// tall, then the body scrolls (Win98Window keeps the caption):
//   tight   the sheet's gaps go from 10 u to 4 u and the groups' from 7 u
//           to 4 u (space first);
//   flat    the capacity buttons put the picture beside the label, 24 u
//           tall instead of 46 u (decoration);
//   intro   the sheet's first line moves into the caption ("Layout -
//           Built-in Display") (a readout, relocated);
//   status  the key hints in the status bar go; every key still works and
//           the access keys stay underlined (a readout).
// save: { tight, flat, intro, status }, what each step gives back in units.
var LAYOUT = { width: 316, inset: 52, gap: 6, picto: 40, column: 34, steps: ["tight", "flat", "intro", "status"] };
function layoutPlan(widthU, roomU, naturalU, save) {
    var w = Math.max(0, Math.min(LAYOUT.width, widthU - 4));
    var inner = Math.max(0, w - LAYOUT.inset);
    var button = Math.floor((inner - 2 * LAYOUT.gap) / 3);
    var columns = button >= LAYOUT.column ? 3 : 1;
    var picto = (columns === 3 ? button : inner) >= LAYOUT.picto;
    var steps = [];
    var left = naturalU;
    var s = save || {};
    for (var i = 0; i < LAYOUT.steps.length && roomU > 0 && left > roomU; i++) {
        var step = LAYOUT.steps[i];
        // One column is already flat.
        var gives = step === "flat" && columns === 1 ? 0 : (s[step] || 0);
        steps.push(step);
        left -= gives;
    }
    var has = function (x) { return steps.indexOf(x) >= 0; };
    return {
        width: w, inner: inner, columns: columns, picto: picto,
        button: columns === 3 ? button : inner,
        steps: steps, tight: has("tight"), flat: has("flat") || columns === 1,
        intro: !has("intro"), status: !has("status"),
        scrolls: roomU > 0 && left > roomU
    };
}
