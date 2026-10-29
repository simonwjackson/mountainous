// The Platinum bar's layout policy (bar-plan.js), direction A "Quiet
// glyphs". Run: node bar-plan.test.js bar-plan.js bar-fixtures.json [PlatinumTopBar.qml]
//
// The fixtures are the widths the real bar measured in ChicagoFLF for the
// approved mock's states (bar-fixtures.json "quiet"): calm, everything
// wrong, long values, failed dictation, and Super+O held.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const model = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/bar-plan.js", "utf8").replace(/^\.pragma library\s*$/m, ""), model);
const fixtures = JSON.parse(fs.readFileSync(process.argv[3] || __dirname + "/bar-fixtures.json", "utf8"));
const qmlPath = process.argv[4] || __dirname + "/PlatinumTopBar.qml";
const Q = fixtures.quiet;
const EDGE = 6, GAP16 = 16;
const even = v => Math.ceil(v / 2 - 1e-6) * 2;
const YIELD = ["space", "appName", "diskLabel", "uncentre", "titleMin", "builderLabel", "ociNumber", "ntfCount", "fleetCount", "batteryPct"];
const OVERFLOW = ["oci", "disk", "fleet", "builder", "layout", "bri", "bt", "wifi", "ntf", "vol"];
const KEY = {oci: "ociNumber", disk: "diskLabel", fleet: "fleetCount", builder: "builderLabel", ntf: "ntfCount"};
let checks = 0;
const ok = (v, m) => { assert.ok(v, m); checks++; };
// Plans come from another realm (vm), so compare their JSON.
const plain = v => v === undefined ? v : JSON.parse(JSON.stringify(v));
const eq = (a, b, m) => { assert.deepEqual(plain(a), plain(b), m); checks++; };

// What the bar draws for a plan, computed here independently of the
// planner: every item at an even width (PlatinumBarControl).
function widths(p, m) {
    const w = {};
    const shownReadout = (c) => p.show[KEY[c.id]] === false ? Math.min(c.readoutWidth, c.compactReadoutWidth || 0) : c.readoutWidth;
    for (const c of m.controls) {
        const r = shownReadout(c);
        w[c.id] = even(2 * p.pad + c.iconWidth + (r > 0 ? 6 + r : 0));
    }
    w.more = p.overflowIconWidth === undefined ? even(2 * p.pad + m.overflowWidth) : 2 * p.pad + p.overflowIconWidth;
    const br = p.show.batteryPct === false ? 0 : (m.batteryReadoutWidth || 0);
    w.battery = even(2 * p.pad + m.batteryWidth + (br > 0 ? 6 + br : 0));
    const an = p.show.appName === false ? 0 : m.appNameWidth;
    w.app = even(2 * p.pad + m.appIconWidth + (an > 0 ? 6 + an : 0));
    return w;
}
const markRight = (p, m) => p.edge + (p.show.mark === false ? 0 : even(2 * p.pad + m.markWidth));

// Nothing drawn overlaps: the left group ends 16 px before the clock (or
// the chord) and before the right group; the right group stays on screen.
function assertPlaced(width, m, p, label) {
    const at = model.place(width, m, p, widths(p, m));
    const where = label + " at " + width;
    ok(at.rightStart >= -1e-6, "the right group starts on screen " + where);
    const left = Math.max(p.leftMax, markRight(p, m));
    if (p.steps.indexOf("compact") < 0) {
        ok(left + GAP16 <= at.rightStart + 1e-6, "the left group ends 16 px before the right group " + where);
        const centre = at.chord || at.clock;
        // The centre item's x is rounded up to an even pixel, so its
        // right side may lose up to 2 px of the 16.
        if (p.centred && centre) {
            ok(left + GAP16 <= centre.x + 1e-6, "16 px between the left group and the centre " + where);
            ok(centre.x + centre.w + GAP16 - 2 <= at.rightStart + 1e-6, "16 px between the centre and the right group " + where);
        }
    } else {
        ok(markRight(p, m) <= at.rightStart + 1e-6, "the mark and the right group do not meet " + where);
    }
    // The chord stands where the plan reserved it (bug 1: it was always
    // drawn centred, over the controls, from 387 to 918 px).
    if (p.show.chord) {
        const c = at.chord;
        ok(c && c.w === p.chordWidth, "the chord has its planned width " + where);
        for (const id of Object.keys(at)) {
            if (id === "chord" || id === "rightStart" || id === "clock") continue;
            const r = at[id];
            ok(c.x + c.w <= r.x + 1e-6 || r.x + r.w <= c.x + 1e-6, "the chord does not cover " + id + " " + where);
        }
        ok(c.x >= left - 1e-6, "the chord does not cover the left group " + where);
    }
    return at;
}

// Every capability is on the bar or in », once.
function assertReachable(width, m, p, label) {
    const where = label + " at " + width;
    const ids = m.controls.map(c => c.id);
    const all = p.controls.concat(p.overflow.filter(id => ids.includes(id)));
    eq(all.slice().sort(), ids.slice().sort(), "every control reachable " + where);
    eq(new Set(all).size, ids.length, "no control twice " + where);
    for (const id of ["battery", "clock", "app"]) {
        if (id === "battery" && !(m.batteryWidth > 0)) continue;
        ok(p.show[id] !== false || p.overflow.includes(id), id + " reachable " + where);
    }
    ok(p.show.mark !== false || p.overflow[0] === "apple", "Apple menu reachable " + where);
    if (m.dictationActionsWidth > 0) ok(p.show.dictationActions || p.overflow.includes("dictation"), "dictation reachable " + where);
    ok(Number.isInteger(p.pad) && p.pad >= 0, "whole-pixel padding " + where);
}

// The steps a fixture can take: a step that would save nothing is skipped.
function expectedSteps(m) {
    const items = m.controls.map(c => ({key: KEY[c.id], r: c.readoutWidth, c: Math.min(c.readoutWidth, c.compactReadoutWidth || 0)}));
    if (m.batteryWidth > 0) items.push({key: "batteryPct", r: m.batteryReadoutWidth || 0, c: 0});
    items.push({key: "appName", r: m.appNameWidth, c: 0});
    return YIELD.filter(k => k === "space" || k === "uncentre" || (k === "titleMin" ? m.titleWidth > 0 : items.some(i => i.key === k && i.c < i.r)));
}
const severity = p => [p.steps.filter(s => s !== "overflow" && s !== "underflow" && s !== "compact").length, p.overflow.length, 99 - p.pad, p.steps.includes("compact") ? 1 : 0];
const shape = p => JSON.stringify({steps: p.steps, overflow: p.overflow, pad: p.pad, chord: p.show.chordNames});

// ---------------------------------------------------------------- sweeps
const cases = {
    calm: Q.calm, wrong: Q.wrong, long: Q.long, dictation: Q.dictation,
    chordCalm: {...Q.calm, chordWidth: Q.chord.named, chordCompactWidth: Q.chord.caps},
    chordWrong: {...Q.wrong, chordWidth: Q.chord.named, chordCompactWidth: Q.chord.caps}
};
const thresholds = {};
for (const [label, m] of Object.entries(cases)) {
    const steps = expectedSteps(m);
    const present = OVERFLOW.filter(id => m.controls.some(c => c.id === id));
    let previous = null;
    thresholds[label] = [];
    for (let width = 2400; width >= 0; width--) {
        const p = model.plan(width, m);
        assertReachable(width, m, p, label);
        assertPlaced(width, m, p, label);
        const applied = p.steps.filter(s => s !== "overflow" && s !== "underflow" && s !== "compact");
        eq(applied, steps.slice(0, applied.length), "yield order " + label + " at " + width);
        eq(p.overflow.filter(id => present.includes(id)), present.slice(0, p.overflow.filter(id => present.includes(id)).length), "overflow order " + label + " at " + width);
        ok(!p.steps.includes("underflow"), "the plan always fits " + label + " at " + width);
        // Readouts yield before any control moves into ».
        if (p.overflow.some(id => present.includes(id))) eq(applied, steps, "every readout yielded before a control overflowed: " + label + " at " + width);
        if (p.overflow.includes("dictation")) eq(p.controls.length, 0, "dictation's group moves after every control " + label);
        eq(p.show.dictationActions, (m.dictationActionsWidth || 0) > 0 && !p.overflow.includes("dictation"), "Retry and Dismiss move together " + label + " at " + width);
        if (previous) {
            const a = severity(previous), b = severity(p);
            // Super+O's names are the one readout that can trade back:
            // once they drop to key caps, the spacing they cost returns.
            const tradedNames = previous.show.chordNames && !p.show.chordNames;
            ok(tradedNames || (b[0] >= a[0] && b[1] >= a[1]), "monotonic as the bar narrows: " + label + " at " + width);
            ok(b[1] >= a[1], "overflow never shrinks as the bar narrows: " + label + " at " + width);
            if (shape(previous) !== shape(p)) thresholds[label].push(width + 1);
        }
        previous = p;
    }
}

// ---------------------------------------------------------------- thresholds
// Every threshold, one px either side: t is the narrowest width that keeps
// the wider layout; t - 1 is the first width of the next rung, and t + 1
// keeps the wider layout too.
for (const [label, list] of Object.entries(thresholds)) {
    ok(list.length >= 10, label + ": the sweep crosses the rungs (" + list.length + ")");
    for (const t of list) {
        const at = model.plan(t, cases[label]), below = model.plan(t - 1, cases[label]), above = model.plan(t + 1, cases[label]);
        ok(shape(at) !== shape(below), label + ": " + t + " and " + (t - 1) + " differ");
        const sa = severity(at), sb = severity(below);
        ok(sb[0] > sa[0] || sb[1] > sa[1] || sb[2] > sa[2] || sb[3] > sa[3] || (at.show.chordNames && !below.show.chordNames),
            label + ": " + (t - 1) + " gives up more than " + t);
        if (!list.includes(t + 1)) eq(shape(above), shape(at), label + ": " + (t + 1) + " keeps the layout of " + t);
    }
}
// The pinned rungs of the calm bar, as measured (bar-fixtures.json
// quiet.calmThresholds): the first control moves into » at about 428 px.
for (const [step, t] of Object.entries(Q.calmThresholds)) {
    const at = model.plan(t, Q.calm), below = model.plan(t - 1, Q.calm);
    const has = (p) => step.startsWith("overflow:") ? p.overflow.includes(step.slice(9)) : step === "compact" ? p.steps.includes("compact")
        : step.startsWith("pad:") ? p.pad <= Number(step.slice(4)) : p.steps.includes(step);
    ok(!has(at) && has(below), "calm: " + step + " starts at " + (t - 1) + " px, not at " + t + " px");
    ok(!has(model.plan(t + 1, Q.calm)), "calm: " + step + " not at " + (t + 1) + " px");
}
ok(Q.calmThresholds["overflow:oci"] >= 424 && Q.calmThresholds["overflow:oci"] <= 432, "the first control moves into » at about 428 px");
eq(model.plan(1920, Q.calm).steps, [], "calm at 1920 gives up nothing");

// ---------------------------------------------------------------- yield order
// Words go before the clock leaves the centre; a number in a warning or
// danger tone outlasts the window title.
{
    const m = Q.wrong;
    const order = expectedSteps(m);
    ok(order.indexOf("diskLabel") < order.indexOf("uncentre"), "the disk's words yield before the clock leaves the centre");
    for (const k of ["builderLabel", "ociNumber", "ntfCount", "fleetCount", "batteryPct"])
        if (order.includes(k)) ok(order.indexOf("titleMin") < order.indexOf(k), k + " outlasts the window title");
    // The disk count keeps its box after " issue" yields, until Disks moves into ».
    let seenCount = false;
    for (let w = 2400; w > 0; w--) {
        const p = model.plan(w, m);
        if (p.show.diskLabel === false && p.controls.includes("disk")) { seenCount = true; break; }
    }
    ok(seenCount, "a width shows the disk count without its words");
    // The Wi-Fi "!" never yields: it stays while Wi-Fi is on the bar.
    for (let w = 2400; w > 0; w -= 7) {
        const p = model.plan(w, m);
        if (p.controls.includes("wifi")) ok(model.place(w, m, p, widths(p, m)).wifi.w === even(2 * p.pad + 16 + 6 + m.controls.find(c => c.id === "wifi").readoutWidth), "the Wi-Fi ! stays at " + w);
    }
}
// The Application menu's name: only when the title does not name the app.
eq(model.plan(2400, Q.calm).show.appName, true);
ok(!expectedSteps(Q.calm).includes("appName"), "no appName step when the title names the app (Forgerie)");
ok(expectedSteps(Q.long).includes("appName"), "the name (Ghostty) is a readout when the title does not name it");
eq(expectedSteps(Q.long)[1], "appName", "the name is the first readout to yield");
// Without a page layout (the state file is not read yet) the bar plans
// no Layout control; with one, Layout moves into » after the status
// readouts and before Brightness.
{
    const bare = {...Q.calm, controls: Q.calm.controls.filter(c => c.id !== "layout")};
    for (let w = 2400; w > 0; w -= 3) {
        const p = model.plan(w, bare);
        ok(!p.controls.includes("layout") && !p.overflow.includes("layout"), "no Layout without a page layout at " + w);
    }
    const t = Q.calmThresholds;
    ok(t["overflow:builder"] > t["overflow:layout"] && t["overflow:layout"] > t["overflow:bri"], "Layout overflows between Builder and Brightness");
}
// Hosts without the builder gate or Beszel take no step for them.
{
    const bare = {...Q.wrong, controls: Q.wrong.controls.filter(c => c.id !== "builder" && c.id !== "fleet")};
    for (const w of [2400, 1200, 700, 500, 400, 300, 200]) {
        const p = model.plan(w, bare);
        ok(!p.steps.includes("builderLabel") && !p.steps.includes("fleetCount"), "no builder or fleet step at " + w);
    }
}

// ---------------------------------------------------------------- Super+O
{
    const m = cases.chordCalm;
    const named = Q.chord.named, caps = Q.chord.caps;
    // Names while the whole hint takes at most half the bar.
    const half = Math.ceil(2 * named);
    eq(model.plan(half, m).show.chordNames, true, "names at " + half);
    eq(model.plan(half + 1, m).show.chordNames, true, "names at " + (half + 1));
    // Below that, names only while they make nothing but spacing yield.
    for (let w = half - 1; w > 0; w--) {
        const p = model.plan(w, m);
        if (p.show.chordNames) {
            eq(p.steps.filter(s => s !== "space"), [], "names below half only while calm, at " + w);
            eq(p.chordWidth, named);
        } else if (p.show.chord) eq(p.chordWidth, caps, "key caps alone at " + w);
    }
    // The chord moves with the clock: centred, or at the head of the right group.
    let right = 0;
    for (let w = 2400; w > 0; w--) {
        const p = model.plan(w, m);
        if (!p.show.chord) continue;
        eq(p.chordPlace, p.centred ? "centre" : "right", "the chord stands in the clock's place at " + w);
        if (p.chordPlace === "right") right++;
    }
    ok(right > 100, "the sweep reaches the uncentred chord");
    // Bug 1: drawn centred while the plan reserved it in the right group,
    // the chord covered the controls. Today's plan (the mock's run) found
    // 531 such widths; the same rule here still finds them, and place()
    // finds none.
    let covered = 0;
    for (let w = 191; w <= 2400; w++) {
        const p = model.plan(w, m);
        if (!p.show.chord || p.chordPlace !== "right") continue;
        const at = model.place(w, m, p, widths(p, m));
        const centredX = even(w / 2 - p.chordWidth / 2);
        const hits = Object.keys(at).some(id => !["chord", "rightStart", "clock"].includes(id)
            && !(centredX + p.chordWidth <= at[id].x || at[id].x + at[id].w <= centredX));
        if (hits) covered++;
    }
    ok(covered > 0, "the old centred chord would cover the controls (" + covered + " widths)");
}
// The QML draws the chord where the plan reserved it.
if (fs.existsSync(qmlPath)) {
    const qml = fs.readFileSync(qmlPath, "utf8");
    ok(/x: bar\.plan\.chordPlace === "right" \? rightGroup\.x \+ chordSlot\.x/.test(qml), "PlatinumTopBar places the chord from the plan");
    ok(/id: chordSlot[\s\S]{0,200}width: bar\.plan\.chordWidth/.test(qml), "the right group reserves the chord's slot");
    ok(/compact: !bar\.plan\.show\.chordNames/.test(qml), "the names follow the plan");
    ok(/\["N", "Notifications"\]/.test(qml), "Super+O lists N for Notifications");
    ok(/\["Y", "Layout"\]/.test(qml), "Super+O lists Y for Layout");
    ok(/id: layoutControl[\s\S]{0,200}visible: bar\.layoutPresent && bar\.onBar\("layout"\)/.test(qml), "Layout hides without a page layout and follows the plan");
}

// ---------------------------------------------------------------- compact
{
    const m = Q.dictation;
    eq(model.plan(1920, m).show.dictationActions, true);
    const p191 = model.plan(191, m);
    ok(!p191.steps.includes("compact"), "the captured metrics fit 191 px before compact");
    for (let w = 0; w <= 400; w++) {
        const p = model.plan(w, m);
        if (p.steps.includes("compact")) {
            eq(p.controls, [], "compact only after every control overflowed at " + w);
            ok(p.overflow.includes("dictation"), "and after dictation's actions at " + w);
            eq(p.show.title, false);
        }
        if (p.pad < 5) eq(p.controls.length, 0, "padding goes only after every control at " + w);
    }
    // The compact order: battery, clock, Application, then the Apple menu.
    let order = [];
    for (let w = 400; w >= 0; w--) for (const id of model.plan(w, m).overflow) if (["battery", "clock", "app", "apple"].includes(id) && !order.includes(id)) order.push(id);
    eq(order, ["battery", "clock", "app", "apple"], "compact order");
}

// ---------------------------------------------------------------- the tag and Balloon Help
{
    const num = 30, full = 8 + 16 + 8 + 64 + 8 + num + 8, slim = 8 + 16 + 6 + num + 8;
    eq(model.tagPlan(full + 12, 0, 32, num).well, 64, "the well shows when the full tag fits");
    eq(model.tagPlan(full + 11, 0, 32, num).well, 0, "one px short, the well goes");
    eq(model.tagPlan(full + 13, 0, 32, num).well, 64);
    eq(model.tagPlan(slim + 12, 0, 32, num).show, true, "the slim tag at its width");
    eq(model.tagPlan(slim + 11, 0, 32, num).show, false, "one px short, no tag (the value is in the menu)");
    eq(model.tagPlan(slim + 13, 0, 32, num).width, slim);
    for (let w = 0; w <= 2400; w += 3) for (const ax of [-50, 0, w / 3, w - 40, w + 50]) {
        const t = model.tagPlan(w, ax, 32, num);
        if (t.show) ok(t.x >= 6 && t.x + t.width <= w - 6 + 1e-6, "the tag stays on screen at " + w);
        const b = model.balloonPlan(w, ax, 32, 260);
        ok(b.width <= 300 && b.width <= Math.max(0, w - 12), "the balloon fits at " + w);
        if (w >= 40) ok(b.x >= 6 && b.x + b.width <= w - 6 + 1e-6, "the balloon stays on screen at " + w);
        ok(b.tail >= 0 && b.tail <= b.width, "the tail is on the balloon at " + w);
    }
    // The balloon is as wide as its text wants, at most 300.
    eq(model.balloonPlan(1920, 1500, 32, 120).width, 120);
    eq(model.balloonPlan(1920, 1500, 32, 900).width, 300);
    eq(model.balloonPlan(191, 100, 32, 900).width, 179);
    // Its tail points at the title.
    const b = model.balloonPlan(1920, 1500, 32, 200);
    eq(b.x + b.tail, 1516);
}

// ---------------------------------------------------------------- input checks
assert.throws(() => model.plan(-1, Q.calm), /width/i);
assert.throws(() => model.plan(NaN, Q.calm), /width/i);
assert.throws(() => model.plan(100, {...Q.calm, batteryWidth: -1}), /batteryWidth/i);
assert.throws(() => model.plan(100, {...Q.calm, batteryReadoutWidth: NaN}), /batteryReadoutWidth/i);
assert.throws(() => model.plan(100, {...Q.calm, chordCompactWidth: -2}), /chordCompactWidth/i);
assert.throws(() => model.plan(100, {...Q.calm, controls: [{id: "other", iconWidth: 16, readoutWidth: 0}]}), /control/i);
assert.throws(() => model.plan(100, {...Q.calm, controls: [Q.calm.controls[0], Q.calm.controls[0]]}), /control/i);
for (const compactReadoutWidth of [-1, NaN]) assert.throws(() => model.plan(100, {...Q.calm, controls: [{id: "disk", iconWidth: 16, readoutWidth: 24, compactReadoutWidth}]}), /compact/i);
// A compact readout wider than the full one is clamped, and the input is not changed.
{
    const input = {...Q.wrong, controls: Q.wrong.controls.map(c => c.id === "ntf" ? {...c, compactReadoutWidth: c.readoutWidth + 50} : c)};
    const before = JSON.stringify(input);
    for (const w of [2400, 900, 500, 300]) model.plan(w, input);
    eq(JSON.stringify(input), before, "the planner does not change its input");
}
console.log("bar-plan: " + checks + " checks; quiet glyphs, every threshold one px either side ("
    + Object.values(thresholds).reduce((s, l) => s + l.length, 0) + "), yield and overflow order, groups, Super+O placement, the tag and Balloon Help");
