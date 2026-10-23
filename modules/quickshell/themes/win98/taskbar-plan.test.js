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

// Width falls from 1440 u to 120 u: steps only ever grow, in the declared
// order, and every window and tray icon stays reachable at every width.
const order = ['clockShort', 'dictText', 'titles', 'startIcon', 'windows»', 'tray»'];
for (const windows of [[], ideal, many]) {
    let last = [];
    for (let W = 1440; W >= 120; W--) {
        const inp = input(windows);
        const q = P.plan(W, inp);
        const r = all(q, inp);
        eq(r.windows, windows.map((_, i) => i), 'every window reachable at ' + W);
        eq(r.tray.slice().sort(), trayIds.slice().sort(), 'every tray icon reachable at ' + W);
        for (const s of last) assert.ok(q.steps.includes(s), `step ${s} came back at ${W}`);
        const idx = q.steps.map(s => order.indexOf(s));
        eq(idx, idx.slice().sort((a, b) => a - b), 'steps in order at ' + W);
        // The focused window is the last to leave the bar.
        const focused = windows.findIndex(w => w.focused);
        if (focused >= 0 && q.taskOut.includes(focused)) assert.equal(q.taskOut.length, windows.length);
        last = q.steps;
    }
}

// One unit either side of each yield boundary.
function boundary(windows, step) {
    for (let W = 1440; W >= 120; W--) if (P.plan(W, input(windows)).steps.includes(step)) return W;
    return -1;
}
for (const step of ['clockShort', 'titles', 'startIcon', 'windows»', 'tray»']) {
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
console.log('WIN98_TASKBAR_PLAN_TESTS_PASSED');
