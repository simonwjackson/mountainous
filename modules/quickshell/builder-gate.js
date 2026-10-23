.pragma library
// The remote-builder control's view logic, with no Qt in it, so node can run
// the same file the bar loads (see builder-gate.test.js).
//
// Input: what `nix-builder-gate status --json` prints, or what the gate
// writes to /run/nix-builder-gate/state.json. Both carry one object:
//   {accepting, reason, location, power, choice, running}
// Output: the words, tone and actions that the bar and the panel draw.

var REASONS = ["home", "away", "battery", "choice-on", "choice-off", "no-network"];
var LOCATIONS = ["home", "away", "unknown"];
var POWERS = ["ac", "battery"];
// The reasons that mean "accepting". Every other reason means "refusing".
var ACCEPTING_REASONS = ["home", "choice-on"];

// The bar's three forms, by the bar's width. The words are a readout, so they
// shorten first; the mark and both targets stay at every width.
//   wide   >= 1400  "Builds off: battery"
//   short  >= 560   "BLD 2"
//   tiny   below    the mark and the count only
// 1400 leaves room for the longest words beside myoko's OCI and Disks
// readouts, which keep their own words from 900. Guesses, measured only in
// the headless capture (builder-dev/capture.sh).
var WIDE_BAR = 1400;
var SHORT_BAR = 560;

// A sample is one of:
//   {kind: "loading"}                      before the first answer
//   {kind: "absent"}                       no nix-builder-gate on PATH
//   {kind: "error", detail: "..."}         the CLI failed or printed bad JSON
//   {kind: "ready", value: {...}}          a valid status object
function loading() { return {kind: "loading"}; }
function absent() { return {kind: "absent"}; }
function failure(detail) { return {kind: "error", detail: String(detail || "unknown error")}; }

// Strict, so the bar never draws a guess. Extra keys are allowed, so the
// gate can add fields without breaking the bar.
function parse(text) {
    var value;
    try {
        value = JSON.parse(String(text));
    } catch (e) {
        return failure("status was not JSON");
    }
    if (value === null || typeof value !== "object" || Array.isArray(value))
        return failure("status was not a JSON object");
    if (typeof value.accepting !== "boolean") return failure("accepting is not true or false");
    if (REASONS.indexOf(value.reason) < 0) return failure("unknown reason " + JSON.stringify(value.reason));
    if (LOCATIONS.indexOf(value.location) < 0) return failure("unknown location " + JSON.stringify(value.location));
    if (POWERS.indexOf(value.power) < 0) return failure("unknown power " + JSON.stringify(value.power));
    if (!(value.choice === "on" || value.choice === "off" || value.choice === null))
        return failure("unknown choice " + JSON.stringify(value.choice));
    if (typeof value.running !== "number" || !isFinite(value.running)
        || Math.floor(value.running) !== value.running || value.running < 0)
        return failure("running is not a count");
    // The answer must agree with the rule that gave it.
    if ((ACCEPTING_REASONS.indexOf(value.reason) >= 0) !== value.accepting)
        return failure("accepting disagrees with reason " + value.reason);
    if (value.reason === "choice-on" && value.choice !== "on")
        return failure("reason choice-on without choice on");
    if (value.reason === "choice-off" && value.choice !== "off")
        return failure("reason choice-off without choice off");
    return {kind: "ready", value: {
        accepting: value.accepting,
        reason: value.reason,
        location: value.location,
        power: value.power,
        choice: value.choice,
        running: value.running
    }};
}

// What the default rule would say here, without the manual choice.
// Home on mains accepts; anything else refuses.
function defaultAccepts(value) {
    return value.location === "home" && value.power === "ac";
}

function plural(n, one, many) { return n + " " + (n === 1 ? one : many); }

var PENDING_WORDS = {
    on: "Turning on…",
    off: "Turning off…",
    "default": "Using default…",
    stop: "Stopping…"
};

var ACTION_NAMES = {
    on: "turn builds on",
    off: "turn builds off",
    "default": "return to the default",
    stop: "stop the running builds"
};

var FAILED_WORDS = {
    on: "On failed",
    off: "Off failed",
    "default": "Default failed",
    stop: "Stop failed"
};

// The bar's words in a form from barPlan: "wide", "short" or "tiny".
function barText(sample, pending, actionError, form) {
    if (pending) return form === "wide" ? PENDING_WORDS[pending] : form === "short" ? "BLD …" : "…";
    if (actionError) return form === "wide" ? (FAILED_WORDS[actionError.command] || "Failed")
        : form === "short" ? "BLD !" : "!";
    if (sample.kind === "error") return form === "wide" ? "Builds !" : form === "short" ? "BLD !" : "!";
    if (sample.kind !== "ready") return form === "wide" ? "Builds …" : form === "short" ? "BLD …" : "…";
    var v = sample.value;
    if (form === "tiny") return v.running > 0 ? String(v.running) : "";
    if (form === "short") return v.running > 0 ? "BLD " + v.running : "BLD";
    if (v.running > 0) return (v.accepting ? "Building " : "Finishing ") + v.running;
    switch (v.reason) {
    case "home": return "Builds on";
    case "choice-on": return "On by you";
    case "choice-off": return "Off by you";
    case "away": return "Builds off: away";
    case "battery": return "Builds off: battery";
    case "no-network": return "Builds off: offline";
    }
    return "Builds !";
}

// One of: accent (accepting), muted (refusing by rule), primary (refusing
// by your choice), warning (an action failed), quiet (error, loading).
function tone(sample, pending, actionError) {
    if (actionError) return "warning";
    if (pending || sample.kind !== "ready") return "quiet";
    var v = sample.value;
    if (v.accepting) return "accent";
    return v.choice === "off" ? "primary" : "muted";
}

// The mark before the bar text: on, off, or none.
function mark(sample, pending) {
    if (pending || sample.kind !== "ready") return "none";
    return sample.value.accepting ? "on" : "off";
}

// What one click on the bar does. "on" or "off" sets a manual choice; "panel"
// opens the panel, because without a valid status there is no way to know
// which way a toggle goes.
function clickAction(sample, pending) {
    if (pending || sample.kind !== "ready") return "panel";
    return sample.value.accepting ? "off" : "on";
}

function headline(sample, pending) {
    if (pending) return PENDING_WORDS[pending];
    if (sample.kind === "error") return "Status unknown";
    if (sample.kind !== "ready") return "Checking…";
    var v = sample.value;
    if (v.accepting) return v.running > 0
        ? "Running " + plural(v.running, "build", "builds") + " for the fleet"
        : "Accepting builds";
    return "Refusing builds";
}

// Why, in one or two short sentences. A manual choice always says how long
// it lasts.
function reasonText(sample) {
    if (sample.kind === "error")
        return "nix-builder-gate failed: " + sample.detail + ". The bar shows no state until it answers.";
    if (sample.kind !== "ready") return "";
    var v = sample.value;
    switch (v.reason) {
    case "home": return "At home on mains power, so myoko accepts by default.";
    case "away": return "Away from home, so myoko refuses by default.";
    case "battery": return "On battery, so myoko refuses by default.";
    case "no-network": return "No network, so myoko refuses.";
    case "choice-on": return "You turned builds on. This lasts until myoko joins another network.";
    case "choice-off": return "You turned builds off. This lasts until myoko joins another network.";
    }
    return "";
}

// Facts behind the answer, as label/value pairs. A readout: it yields first.
function facts(sample) {
    if (sample.kind !== "ready") return [];
    var v = sample.value;
    return [
        {label: "Network", value: v.location === "unknown" ? "none" : v.location},
        {label: "Power", value: v.power === "ac" ? "mains" : "battery"},
        {label: "Running", value: String(v.running)}
    ];
}

// Builds that still run after the gate turned to refuse.
function runningNote(sample) {
    if (sample.kind !== "ready") return "";
    var v = sample.value;
    if (v.running === 0 || v.accepting) return "";
    return plural(v.running, "build", "builds") + " started before still "
        + (v.running === 1 ? "runs" : "run") + ". New builds are refused.";
}

// The panel's actions in keyboard order. Each keeps its place when it is
// disabled, so nothing jumps and nothing disappears.
//   id      what the gate is asked to do
//   key     its letter in the panel
//   detail  why it is disabled, when it is
function actions(sample, pending) {
    var ready = sample.kind === "ready" && !pending;
    var v = sample.kind === "ready" ? sample.value : null;
    var list = [];
    // While a command runs, every action waits, and one line says why.
    var waiting = pending ? "Waits for the current change" : "";
    list.push({
        id: "toggle",
        key: "T",
        label: "Accept builds",
        checked: !!(v && v.accepting),
        command: v ? (v.accepting ? "off" : "on") : "",
        enabled: ready,
        detail: waiting || (ready ? "" : "The switch waits for a valid status")
    });
    var fallback = v ? (defaultAccepts(v) ? "on" : "off") : "";
    list.push({
        id: "default",
        key: "D",
        label: v && v.choice !== null ? "Use default (" + fallback + ")" : "Use default",
        command: "default",
        // With no valid status the gate may still hold a choice, so the
        // way back to the default stays open.
        enabled: !pending && (sample.kind === "error" || (ready && v.choice !== null)),
        detail: !waiting && v && v.choice === null ? "No manual choice to clear" : ""
    });
    list.push({
        id: "stop",
        key: "X",
        label: v && v.running > 0 ? "Stop " + plural(v.running, "build", "builds") : "Stop builds",
        command: "stop",
        enabled: !pending && (sample.kind === "error" || (ready && v.running > 0)),
        detail: !waiting && v && v.running === 0 ? "No builds running" : ""
    });
    return list;
}

function actionErrorText(actionError) {
    if (!actionError) return "";
    var what = ACTION_NAMES[actionError.command] || actionError.command;
    var why = actionError.detail ? ": " + actionError.detail : "";
    return "Could not " + what + why;
}

// The bar's tooltip, as lines: the state, why, and what a click does.
function tooltip(sample, pending, actionError) {
    var lines = [];
    if (actionError) lines.push(actionErrorText(actionError));
    if (pending) {
        lines.push(PENDING_WORDS[pending]);
        return lines;
    }
    if (sample.kind !== "ready") {
        lines.push(sample.kind === "error" ? "Remote builds: status unknown" : "Remote builds: checking…");
        lines.push("Click for details");
        return lines;
    }
    var v = sample.value;
    var note = runningNote(sample);
    lines.push(headline(sample, ""));
    lines.push(reasonText(sample));
    if (note) lines.push(note);
    lines.push(v.accepting ? "Click to turn builds off. Right-click for more."
        : "Click to turn builds on. Right-click for more.");
    return lines;
}

// Move the panel's keyboard focus by delta over the enabled targets.
// targets: [{id, enabled}]; returns the new id.
function moveFocus(targets, current, delta) {
    var live = [];
    for (var i = 0; i < targets.length; i++) if (targets[i].enabled) live.push(targets[i].id);
    if (live.length === 0) return "";
    var at = live.indexOf(current);
    if (at < 0) return delta < 0 ? live[live.length - 1] : live[0];
    return live[(at + delta + live.length) % live.length];
}

// The bar control's layout. A pure function of the bar's width.
function barPlan(barWidth) {
    return {
        form: barWidth >= WIDE_BAR ? "wide" : barWidth >= SHORT_BAR ? "short" : "tiny",
        mark: true,
        opener: true
    };
}

// The panel's layout. A pure function of the screen's free width and height.
// Height decides structure. The readouts yield in order: the key hint, then
// the facts and the disabled reasons, then the reason's extra lines. Below
// 220 the headline replaces the panel's title and the reason goes (the bar's
// tooltip keeps it); below 180 the switch moves into that title row. What
// still does not fit scrolls, with the keyboard focus kept in view. The
// switch, the two buttons and the close button never yield. Width decides
// whether the two buttons share a row.
var PANEL_MAX_WIDTH = 340;
function panelPlan(width, height) {
    var cardWidth = Math.min(PANEL_MAX_WIDTH, Math.max(0, width - 12));
    return {
        cardWidth: cardWidth,
        maxHeight: Math.max(0, height - 44),
        showHint: height >= 340,
        showFacts: height >= 300,
        showDetail: height >= 300,
        reasonLines: height >= 260 ? 4 : 1,
        showReason: height >= 220,
        titleIsHeadline: height < 220,
        inlineSwitch: height < 180,
        buttonsInRow: cardWidth >= 300
    };
}
