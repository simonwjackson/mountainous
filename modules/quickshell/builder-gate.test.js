// Run builder-gate.js, the same file QML loads, without a compositor.
//   node builder-gate.test.js builder-gate.js
const fs = require("fs");
const vm = require("vm");
const assert = require("assert");

// Top-level functions and vars land on the context, as QML exposes them.
const g = {};
vm.runInNewContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, ""), g);

const status = (over) => Object.assign({
    accepting: true, reason: "home", location: "home", power: "ac", choice: null, running: 0
}, over);
const ready = (over) => {
    const s = g.parse(JSON.stringify(status(over)));
    assert.equal(s.kind, "ready", JSON.stringify(over) + " " + (s.detail || ""));
    return s;
};

// ---- parse: every state in the contract
const states = {
    home: status(),
    away: status({accepting: false, reason: "away", location: "away"}),
    battery: status({accepting: false, reason: "battery", power: "battery"}),
    choiceOn: status({reason: "choice-on", location: "away", choice: "on"}),
    choiceOff: status({accepting: false, reason: "choice-off", choice: "off"}),
    noNetwork: status({accepting: false, reason: "no-network", location: "unknown"}),
};
for (const [name, value] of Object.entries(states)) {
    assert.equal(g.parse(JSON.stringify(value)).kind, "ready", name);
    // The gate's own pretty output, with a trailing newline, also parses.
    assert.equal(g.parse(JSON.stringify(value, null, 2) + "\n").kind, "ready", name + " pretty");
}
// Unknown extra fields are allowed.
assert.equal(g.parse(JSON.stringify(status({since: 123}))).kind, "ready");
assert.equal(ready({running: 1000000}).value.running, 1000000);

// ---- parse: bad input is an error, never a guess
const bad = [
    "", " ", "null", "[]", "42", "\"home\"", "{", "{\"accepting\":true}",
    JSON.stringify(status()).slice(0, -3),
    JSON.stringify(status({accepting: "true"})),
    JSON.stringify(status({accepting: null})),
    JSON.stringify(status({reason: "Home"})),
    JSON.stringify(status({reason: undefined})),
    JSON.stringify(status({location: "work"})),
    JSON.stringify(status({power: "mains"})),
    JSON.stringify(status({choice: "default"})),
    JSON.stringify(status({choice: true})),
    JSON.stringify(status({running: -1})),
    JSON.stringify(status({running: 1.5})),
    JSON.stringify(status({running: "2"})),
    JSON.stringify(status({running: null})),
    JSON.stringify(status({running: 1e400})),
    // The answer and the rule disagree.
    JSON.stringify(status({accepting: false, reason: "home"})),
    JSON.stringify(status({accepting: true, reason: "away"})),
    JSON.stringify(status({accepting: true, reason: "choice-on", choice: null})),
    JSON.stringify(status({accepting: false, reason: "choice-off", choice: "on"})),
    "Error: cannot read /run/nix-builder-gate/state.json",
];
for (const text of bad) {
    const s = g.parse(text);
    assert.equal(s.kind, "error", text);
    assert.ok(s.detail.length > 0, text);
}

// ---- the bar's words in each form
const wide = (over, pending) => g.barText(ready(over), pending || "", null, "wide");
const short = (over, pending) => g.barText(ready(over), pending || "", null, "short");
const tiny = (over, pending) => g.barText(ready(over), pending || "", null, "tiny");
assert.equal(wide(states.home), "Builds on");
assert.equal(wide(states.away), "Builds off: away");
assert.equal(wide(states.battery), "Builds off: battery");
assert.equal(wide(states.choiceOn), "On by you");
assert.equal(wide(states.choiceOff), "Off by you");
assert.equal(wide(states.noNetwork), "Builds off: offline");
assert.equal(wide({running: 2}), "Building 2");
assert.equal(wide(Object.assign({}, states.choiceOff, {running: 3})), "Finishing 3");
assert.equal(wide({running: 1000000}), "Building 1000000");
assert.equal(wide(states.home, "off"), "Turning off…");
assert.equal(wide(states.home, "stop"), "Stopping…");
assert.equal(short(states.home), "BLD");
assert.equal(short(states.away), "BLD");
assert.equal(short({running: 2}), "BLD 2");
assert.equal(short(states.home, "on"), "BLD …");
assert.equal(tiny(states.home), "");
assert.equal(tiny({running: 2}), "2");
assert.equal(tiny(states.home, "on"), "…");
const failed = {command: "off", detail: "polkit authorization failed"};
assert.equal(g.barText(ready(states.home), "", failed, "wide"), "Off failed");
assert.equal(g.barText(ready(states.home), "", failed, "short"), "BLD !");
assert.equal(g.barText(ready(states.home), "", failed, "tiny"), "!");
assert.equal(g.barText(g.failure("x"), "", null, "wide"), "Builds !");
assert.equal(g.barText(g.failure("x"), "", null, "short"), "BLD !");
assert.equal(g.barText(g.failure("x"), "", null, "tiny"), "!");
assert.equal(g.barText(g.loading(), "", null, "wide"), "Builds …");
// The longest wide words, which WIDE_BAR must leave room for.
const longest = Object.values(states).map((o) => wide(o)).reduce((x, y) => x.length >= y.length ? x : y);
assert.equal(longest.length, 19, longest);
// Every short form fits the short budget, every tiny form the tiny one.
for (const over of Object.values(states).concat([{running: 99}])) {
    assert.ok(short(over).length <= 6, short(over));
    assert.ok(tiny(over).length <= 2, tiny(over));
}

// ---- tone, mark
assert.equal(g.tone(ready(states.home), "", null), "accent");
assert.equal(g.tone(ready(states.choiceOn), "", null), "accent");
assert.equal(g.tone(ready(states.away), "", null), "muted");
assert.equal(g.tone(ready(states.choiceOff), "", null), "primary");
assert.equal(g.tone(g.failure("x"), "", null), "quiet");
assert.equal(g.tone(ready(states.home), "off", null), "quiet");
assert.equal(g.tone(ready(states.home), "", {command: "off", detail: "x"}), "warning");
assert.equal(g.mark(ready(states.home), ""), "on");
assert.equal(g.mark(ready(states.battery), ""), "off");
assert.equal(g.mark(g.failure("x"), ""), "none");
assert.equal(g.mark(ready(states.home), "off"), "none");
// A manual choice shows in the words alone. The title draws no outline
// (latch) for it, so the view has no latch rule.
assert.equal(g.latched, undefined);

// ---- one click
assert.equal(g.clickAction(ready(states.home), ""), "off");
assert.equal(g.clickAction(ready(states.away), ""), "on");
assert.equal(g.clickAction(ready(states.choiceOff), ""), "on");
assert.equal(g.clickAction(ready(states.choiceOn), ""), "off");
assert.equal(g.clickAction(g.failure("x"), ""), "panel");
assert.equal(g.clickAction(g.loading(), ""), "panel");
assert.equal(g.clickAction(ready(states.home), "off"), "panel");

// ---- a manual choice says how long it lasts, in the panel and the tooltip
for (const s of [states.choiceOn, states.choiceOff]) {
    assert.match(g.reasonText(ready(s)), /until myoko joins another network/);
    assert.match(g.tooltip(ready(s), "", null).join("\n"), /until myoko joins another network/);
}
for (const s of [states.home, states.away, states.battery, states.noNetwork])
    assert.match(g.reasonText(ready(s)), /default|No network/);
assert.match(g.reasonText(g.failure("status exited 2")), /status exited 2/);
assert.match(g.tooltip(ready(states.home), "", null).slice(-1)[0], /^Click to turn builds off/);
assert.match(g.tooltip(ready(states.away), "", null).slice(-1)[0], /^Click to turn builds on/);
assert.match(g.tooltip(g.failure("x"), "", null).join("\n"), /Click for details/);
assert.match(g.tooltip(ready(states.home), "", {command: "off", detail: "permission denied"})[0],
    /^Could not turn builds off: permission denied$/);
assert.equal(g.runningNote(ready(Object.assign({}, states.away, {running: 1}))),
    "1 build started before still runs. New builds are refused.");
assert.equal(g.runningNote(ready({running: 2})), "");
assert.equal(g.headline(ready({running: 1}), ""), "Running 1 build for the fleet");
assert.equal(g.headline(ready(states.away), ""), "Refusing builds");

// ---- the panel's actions: always three, in order, never removed
const ids = (list) => list.map((a) => a.id).join(",");
const byId = (list, id) => list.filter((a) => a.id === id)[0];
for (const sample of [ready(states.home), ready(states.choiceOff), ready({running: 4}), g.failure("x"), g.loading()]) {
    for (const pending of ["", "off"]) assert.equal(ids(g.actions(sample, pending)), "toggle,default,stop");
}
let a = g.actions(ready(states.home), "");
assert.deepEqual([byId(a, "toggle").enabled, byId(a, "toggle").command, byId(a, "toggle").checked], [true, "off", true]);
assert.equal(byId(a, "default").enabled, false);
assert.equal(byId(a, "default").detail, "No manual choice to clear");
assert.equal(byId(a, "stop").enabled, false);
assert.equal(byId(a, "stop").detail, "No builds running");
a = g.actions(ready(states.choiceOff), "");
assert.equal(byId(a, "toggle").command, "on");
assert.equal(byId(a, "default").enabled, true);
// Home on mains: the default would accept.
assert.equal(byId(a, "default").label, "Use default (on)");
assert.equal(byId(g.actions(ready(states.choiceOn), ""), "default").label, "Use default (off)");
a = g.actions(ready({running: 2}), "");
assert.equal(byId(a, "stop").enabled, true);
assert.equal(byId(a, "stop").label, "Stop 2 builds");
assert.equal(byId(g.actions(ready({running: 1}), ""), "stop").label, "Stop 1 build");
// While a command runs, nothing else can start.
assert.ok(g.actions(ready({running: 2, reason: "choice-on", choice: "on"}), "stop").every((x) => !x.enabled));
a = g.actions(ready(states.home), "off");
assert.deepEqual(a.map((x) => x.detail), ["Waits for the current change", "", ""]);
// No valid status: the toggle cannot know its way, but default and stop stay.
a = g.actions(g.failure("x"), "");
assert.deepEqual(a.map((x) => x.enabled), [false, true, true]);
assert.ok(g.actions(g.loading(), "").every((x) => !x.enabled));

// ---- keyboard focus walks enabled targets and wraps
const targets = [{id: "toggle", enabled: true}, {id: "default", enabled: false},
    {id: "stop", enabled: true}, {id: "close", enabled: true}];
assert.equal(g.moveFocus(targets, "", 1), "toggle");
assert.equal(g.moveFocus(targets, "", -1), "close");
assert.equal(g.moveFocus(targets, "toggle", 1), "stop");
assert.equal(g.moveFocus(targets, "close", 1), "toggle");
assert.equal(g.moveFocus(targets, "toggle", -1), "close");
assert.equal(g.moveFocus(targets, "default", 1), "toggle");
assert.equal(g.moveFocus([{id: "a", enabled: false}], "a", 1), "");

// ---- layout plans, one pixel either side of every threshold
assert.equal(g.barPlan(g.WIDE_BAR).form, "wide");
assert.equal(g.barPlan(g.WIDE_BAR - 1).form, "short");
assert.equal(g.barPlan(g.SHORT_BAR).form, "short");
assert.equal(g.barPlan(g.SHORT_BAR - 1).form, "tiny");
for (const w of [0, 200, 559, 560, 1399, 1400, 1920, 3840]) {
    const p = g.barPlan(w);
    assert.ok(p.mark && p.opener, "both targets stay at " + w);
}
let p = g.panelPlan(1920, 1200);
assert.deepEqual([p.cardWidth, p.showHint, p.showFacts, p.showDetail, p.reasonLines, p.showReason, p.buttonsInRow],
    [340, true, true, true, 4, true, true]);
assert.equal(g.panelPlan(312, 1200).cardWidth, 300);
assert.equal(g.panelPlan(312, 1200).buttonsInRow, true);
assert.equal(g.panelPlan(311, 1200).buttonsInRow, false);
assert.equal(g.panelPlan(6, 1200).cardWidth, 0);
const at = (h) => g.panelPlan(1920, h);
assert.deepEqual([at(340).showHint, at(339).showHint], [true, false]);
assert.deepEqual([at(300).showFacts, at(299).showFacts, at(300).showDetail, at(299).showDetail], [true, false, true, false]);
assert.deepEqual([at(260).reasonLines, at(259).reasonLines], [4, 1]);
assert.deepEqual([at(220).showReason, at(219).showReason], [true, false]);
assert.deepEqual([at(220).titleIsHeadline, at(219).titleIsHeadline], [false, true]);
assert.deepEqual([at(180).inlineSwitch, at(179).inlineSwitch], [false, true]);
// Readouts yield in order: the hint first, the reason last.
for (let h = 0; h <= 400; h++) {
    const q = at(h);
    if (q.showHint) assert.ok(q.showFacts, h);
    if (q.showFacts) assert.ok(q.reasonLines > 1, h);
    if (q.reasonLines > 1) assert.ok(q.showReason, h);
    // The headline is always somewhere: in its own block or as the title.
    assert.ok(q.showReason !== q.titleIsHeadline, h);
    if (q.inlineSwitch) assert.ok(q.titleIsHeadline, h);
}
assert.equal(at(20).maxHeight, 0);

console.log("builder-gate view: 6 states, " + bad.length + " bad inputs, words, actions, focus, plans passed");
