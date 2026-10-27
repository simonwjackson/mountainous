// The Win98 taskbar plan: yield order, nothing removed, both sides of every
// boundary. Run: node taskbar-plan.test.js taskbar-plan.js
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const P = {};
const eq = (a, b, m) => assert.deepEqual(JSON.parse(JSON.stringify(a)), JSON.parse(JSON.stringify(b)), m);
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + '/taskbar-plan.js', 'utf8').replace(/^\.pragma library\s*$/m, ''), P);

// W95FA Grid advances are whole pixels; 6 u a letter is close to its average.
const measure = (t, bold) => String(t).length * 6 + (bold ? String(t).length : 0);
const ideal = [
    { page: 1, focused: true }, { page: 1 }, { page: 2 }, { page: 2 }, { page: 3 }];
const many = [1, 1, 1, 2, 2, 2, 2, 3, 3, 4, 4, 4].map((page, i) => ({ page, focused: i === 0 }));
const trayIds = ['bt', 'wifi', 'vol', 'bri', 'oci', 'disk', 'builder', 'ntf', 'bat'];
const input = (windows, extra) => Object.assign({
    windows, showingPage: 1, measure,
    tray: trayIds.map(id => ({ id, badge: id === 'ntf' ? '3' : '' })),
    clock: { time: '4:51', ampm: 'PM' },
    dict: { visible: false }
}, extra || {});
const all = (p, inp) => {
    const shown = p.groups.reduce((s, g) => s.concat(g.windows), []);
    return { windows: shown.concat(p.taskOut).sort((a, b) => a - b), tray: p.tray.concat(p.trayOut) };
};

// Wide: nothing yields.
let p = P.plan(1440, input(ideal));
eq(p.steps, []);
assert.equal(p.clockText, '4:51 PM');
assert.equal(p.groups.length, 3);
assert.equal(p.bw, 160);

// Width falls from 1440 u to 1 u: steps only ever grow, in the declared
// order; the plan fits at every width from MIN_WIDTH up; its parts stay
// inside the bar without overlapping; and every window, tray icon, the
// clock and the battery stay reachable (on the bar, in a chevron menu, or
// through Start in the last structure).
const order = ['clockShort', 'dictText', 'titles', 'startIcon', 'windows»', 'tray»', 'clockOut', 'batteryOut', 'compact', 'start'];
const inside = (b, W) => !b || (b.x >= 0 && b.w >= 0 && b.x + b.w <= W + 1e-9);
for (const windows of [[], [{ page: 1, focused: true }], ideal, many]) {
    for (const dictOn of [false, true]) {
        let last = [];
        for (let W = 1440; W >= 1; W--) {
            const inp = input(windows, dictOn ? { dict: { visible: true, failed: true, canRetry: true, text: 'Dictation failed · Groq' },
                tray: [{ id: 'dict' }].concat(trayIds.map(id => ({ id, badge: id === 'ntf' ? '3' : '' }))) } : {});
            const q = P.plan(W, inp);
            const all = trayIds.concat(dictOn ? ['dict'] : []);
            if (W >= P.MIN_WIDTH) assert.ok(q.fits, `fits at ${W} u (${q.steps})`);
            for (const s of last) assert.ok(q.steps.includes(s), `step ${s} came back at ${W}`);
            const idx = q.steps.map(s => order.indexOf(s));
            assert.ok(!idx.includes(-1), 'known steps at ' + W);
            eq(idx, idx.slice().sort((a, b) => a - b), 'steps in order at ' + W);
            last = q.steps;
            // Reachable: on the bar, in a chevron, or through Start.
            const onBar = q.groups.reduce((s, g) => s.concat(g.windows), []);
            eq(onBar.concat(q.taskOut).sort((a, b) => a - b), windows.map((_, i) => i), 'every window at ' + W);
            eq(q.tray.concat(q.trayOut).slice().sort(), all.slice().sort(), 'every tray icon at ' + W);
            if (q.taskOut.length && q.structure === 'full') assert.ok(q.tasksChevron, 'windows chevron at ' + W);
            if ((q.trayOut.length || q.clockOut) && q.structure !== 'start') assert.ok(q.chevron, 'tray chevron at ' + W);
            if (q.structure !== 'full') eq(q.taskOut.length, windows.length, 'compact holds every window at ' + W);
            if (q.structure === 'start') { assert.ok(q.clockOut); assert.ok(q.trayOut.includes('bat')); }
            // Bounds: inside the bar, in order, and the buttons fit their band.
            const b = q.boxes;
            if (W >= P.MIN_WIDTH) {
                for (const k of ['start', 'tasks', 'dict', 'tray']) assert.ok(inside(b[k], W), `${k} inside at ${W}: ${JSON.stringify(b[k])}`);
                assert.ok(b.start.x + b.start.w <= b.tasks.x + 1e-9, 'start before tasks at ' + W);
                if (b.dict) assert.ok(b.tasks.x + b.tasks.w <= b.dict.x + 1e-9, 'tasks before dictation at ' + W);
                if (b.tray) assert.ok((b.dict ? b.dict.x + b.dict.w : b.tasks.x + b.tasks.w) <= b.tray.x + 1e-9, 'before the tray at ' + W);
                assert.ok(b.used <= b.tasks.w + 1e-9, `window buttons fit their band at ${W}: ${b.used} > ${b.tasks.w}`);
            } else {
                assert.equal(q.structure, 'start');
                assert.ok(b.start.w >= 1 && b.start.x + b.start.w <= W, 'Start still on the bar at ' + W);
            }
        }
    }
}
// MIN_WIDTH: Start alone, 2 u each side.
assert.equal(P.MIN_WIDTH, 28);
assert.ok(P.plan(P.MIN_WIDTH, input(many)).fits);
assert.ok(!P.plan(P.MIN_WIDTH - 1, input(many)).fits);

// One unit either side of each yield boundary.
function boundary(windows, step) {
    for (let W = 1440; W >= 1; W--) if (P.plan(W, input(windows)).steps.includes(step)) return W;
    return -1;
}
for (const step of ['clockShort', 'titles', 'startIcon', 'windows»', 'tray»', 'clockOut', 'batteryOut', 'compact', 'start']) {
    const b = boundary(ideal, step);
    assert.ok(b > 0, step);
    assert.ok(!P.plan(b + 1, input(ideal)).steps.includes(step), step + ' above its boundary');
    assert.ok(P.plan(b, input(ideal)).steps.includes(step), step + ' at its boundary');
}
// The clock yields before titles, titles before the Start label.
assert.ok(boundary(ideal, 'clockShort') > boundary(ideal, 'titles'));
assert.ok(boundary(ideal, 'titles') > boundary(ideal, 'startIcon'));
assert.ok(boundary(ideal, 'startIcon') >= boundary(ideal, 'windows»'));
assert.ok(boundary(ideal, 'windows»') > boundary(ideal, 'tray»'));
assert.ok(boundary(ideal, 'tray»') > boundary(ideal, 'clockOut'));
assert.ok(boundary(ideal, 'clockOut') > boundary(ideal, 'batteryOut'));
assert.ok(boundary(ideal, 'batteryOut') > boundary(ideal, 'compact'));
assert.ok(boundary(ideal, 'compact') > boundary(ideal, 'start'));

// Windows go into the chevron other pages first, the last page first.
const w = P.plan(boundary(ideal, 'windows»'), input(ideal));
eq(w.taskOut, [4]);
// The tray chevron takes OCI first (bar-plan.js order).
const t = P.plan(boundary(ideal, 'tray»'), input(ideal));
eq(t.trayOut, ['oci']);
// A missing icon never counts as overflowed.
const noOci = input(ideal, { tray: trayIds.filter(id => id !== 'oci').map(id => ({ id, badge: '' })) });
const t2 = P.plan(boundary(ideal, 'tray»') - 20, noOci);
assert.ok(!t2.trayOut.includes('oci'));

// Dictation: the text yields, Retry and Dismiss stay; a failure without
// retry keeps Dismiss.
const failed = input(ideal, { dict: { visible: true, failed: true, canRetry: true, text: 'Dictation failed · Groq' }, tray: [{ id: 'dict' }].concat(trayIds.map(id => ({ id }))) });
const d = P.plan(boundary(ideal, 'titles'), failed);
assert.ok(d.steps.includes('dictText'));
assert.equal(d.dictShow, true);
assert.equal(d.dictTextShow, false);
const rec = input(ideal, { dict: { visible: true, failed: false, text: 'Recording' }, tray: [{ id: 'dict' }].concat(trayIds.map(id => ({ id }))) });
const r = P.plan(boundary(ideal, 'titles'), rec);
assert.equal(r.dictShow, false, 'the recording text yields; the tray mic stays');
assert.ok(r.tray.includes('dict'));

// Badges widen their icon by 4 u a digit after the first.
assert.equal(P.trayWidth(''), 20);
assert.equal(P.trayWidth('99+'), 28);

// 0 and 1 windows; 22 windows on 6 pages.
assert.equal(P.plan(1440, input([])).groups.length, 0);
assert.equal(P.plan(1440, input([{ page: 1, focused: true }])).bw, 160);
const huge = Array.from({ length: 22 }, (_, i) => ({ page: 1 + Math.floor(i / 4), focused: i === 0 }));
const h = P.plan(1440, input(huge));
assert.ok(h.icons, 'titles give way to icons with 22 windows');
assert.equal(h.taskOut.length, 0);
eq(P.overflowWindows(huge, [9, 2, 20]), [2, 9, 20]);

// The Fleet tray icon and the two extras (the Glance button, a minimized
// Fleet window): every width from 1440 u down keeps the plan fitting, the
// extras on the bar in their own box at the right end of the task area,
// or (compact, start) in the windows' menu; the Fleet icon overflows
// after Disks, as bar-plan.js orders it.
const fleetTray = ['bt', 'wifi', 'vol', 'bri', 'oci', 'disk', 'fleet', 'builder', 'ntf', 'bat'];
const extrasIn = (windows, extras) => input(windows, {
    tray: fleetTray.map(id => ({ id, badge: id === 'ntf' ? '3' : '' })),
    extras: extras.map(id => ({ id, label: id === 'glance' ? 'Glance' : 'Fleet: 1 problem: unzen', bold: id === 'glance' }))
});
for (const extras of [['glance'], ['fleet'], ['fleet', 'glance']]) {
    for (const windows of [[], ideal, many]) {
        let lastSteps = [];
        for (let W = 1440; W >= 1; W--) {
            const q = P.plan(W, extrasIn(windows, extras));
            if (W >= P.MIN_WIDTH) assert.ok(q.fits, `fits with ${extras} at ${W} u (${q.steps})`);
            for (const s of lastSteps) assert.ok(q.steps.includes(s), `step ${s} came back with extras at ${W}`);
            lastSteps = q.steps;
            eq(q.extras.concat(q.extrasOut).sort(), extras.slice().sort(), `every extra reachable at ${W}`);
            eq(q.tray.concat(q.trayOut).sort(), fleetTray.slice().sort(), `every tray icon with Fleet at ${W}`);
            if (q.structure === 'full') {
                eq(q.extras, extras, 'extras stay on the full bar at ' + W);
                const x = q.boxes.extras;
                assert.ok(x && x.x >= q.boxes.tasks.x + q.boxes.tasks.w - 1e-9, 'extras after the windows at ' + W);
                const end = q.boxes.dict ? q.boxes.dict.x : q.boxes.tray.x - 3;
                assert.ok(x.x + x.w <= end + 1e-9, `extras before the tray at ${W}: ${JSON.stringify(x)} ${end}`);
                assert.ok(q.boxes.used <= q.boxes.tasks.w + 1e-9, 'window buttons fit beside the extras at ' + W);
                for (const id of extras) assert.ok(q.extraW[id] >= 26 && q.extraW[id] <= 160, 'extra width at ' + W);
            } else {
                eq(q.extras, [], 'compact moves the extras into its menu at ' + W);
                if (q.structure === 'compact') assert.ok(q.chevron, 'the compact chevron holds them at ' + W);
            }
        }
    }
}
const glanceWide = P.plan(1440, extrasIn(ideal, ['glance']));
assert.equal(glanceWide.extraW.glance, 3 + 16 + 3 + measure('Glance', true) + 5, 'the Glance button is as wide as its label');
assert.equal(P.plan(1440, extrasIn(ideal, ['fleet'])).extraW.fleet <= 160, true, 'a long Fleet title is cut at 160 u');
const iconsOnly = P.plan(boundary(ideal, 'titles') - 40, extrasIn(ideal, ['glance']));
assert.ok(iconsOnly.steps.includes('titles'));
assert.equal(iconsOnly.extraW.glance, 26, 'icons only once titles go');
const withFleet = extrasIn(ideal, []);
let fleetOut = -1, diskOut = -1, builderOut = -1;
for (let W = 1440; W >= 1; W--) {
    const q = P.plan(W, withFleet);
    if (diskOut < 0 && q.trayOut.includes('disk')) diskOut = W;
    if (fleetOut < 0 && q.trayOut.includes('fleet')) fleetOut = W;
    if (builderOut < 0 && q.trayOut.includes('builder')) builderOut = W;
}
assert.ok(diskOut > fleetOut && fleetOut > builderOut, `Fleet overflows after Disks, before Remote builds (${diskOut} ${fleetOut} ${builderOut})`);
console.log('WIN98_TASKBAR_PLAN_TESTS_PASSED');
