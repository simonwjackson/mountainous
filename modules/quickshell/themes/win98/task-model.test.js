// task-model.js and session-model.js: the Win98 taskbar's own window list
// (minimized windows keep their button), the window and taskbar menus, the
// Cool Switch box, the Shut Down choices, System Properties' facts and the
// volume pop-up.
// Run: node task-model.test.js task-model.js session-model.js ../../page-names.js
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const load = (file) => {
    const ctx = {};
    vm.runInNewContext(fs.readFileSync(file, 'utf8').replace(/^\.pragma library\s*$/m, ''), ctx);
    return ctx;
};
const M = load(process.argv[2] || __dirname + '/task-model.js');
const S = load(process.argv[3] || __dirname + '/session-model.js');
const N = load(process.argv[4] || __dirname + '/../../page-names.js');
const plain = (v) => JSON.parse(JSON.stringify(v));
const deq = (a, b, m) => assert.deepEqual(plain(a), plain(b), m);

const row = (address, appId, page, screen, extra) => Object.assign({
    address, appId, title: appId + ' ' + address, page, workspace: page > 0 ? String(page) : '', screen,
}, extra || {});
const hid = (address, appId, screen) => row(address, appId, -98, screen, { workspace: 'special:hidden-' + appId });

// ---- the lane: shown windows by page, minimized ones in their home page's band
const rows = [
    row('a1', 'term', 1, 'eDP-1'),
    hid('a2', 'zed', 'eDP-1'),          // minimized from page 2
    row('a3', 'chromium', 2, 'eDP-1'),
    row('a4', 'signal', 1, 'eDP-1'),
    row('b1', 'firefox', 1, 'SUNSHINE'),
    hid('b2', 'mpv', 'eDP-1'),          // minimized on the tablet; its special workspace sits on eDP-1
    hid('c1', 'obs', 'eDP-1'),          // hidden before the file existed: no entry
    hid('d1', 'tx', 'DP-9'),            // its screen is gone
    row('e1', 'between', -1, 'eDP-1'),  // between pages
];
const state = { version: 1, windows: {
    a2: { app: 'zed', page: 2, screen: 'eDP-1', title: '' },
    b2: { app: 'mpv', page: 4, screen: 'SUNSHINE', title: '' },
    d1: { app: 'tx', page: 3, screen: 'DP-9', title: '' },
} };
const opts = { screens: ['eDP-1', 'SUNSHINE'], fallbackPage: 1 };
const lane = M.lane(rows, state, 'eDP-1', opts);
deq(lane.map((e) => [e.row.address, e.home, e.minimized]), [
    ['a1', 1, false], ['a4', 1, false], ['c1', 1, true],
    ['a2', 2, true], ['a3', 2, false],
    ['d1', 3, true],
], 'by home page; Hyprland order inside a page; a gone screen falls to the primary');
deq(M.lane(rows, state, 'SUNSHINE', opts).map((e) => [e.row.address, e.home, e.minimized]),
    [['b1', 1, false], ['b2', 4, true]], 'a window minimized on the tablet stays on the tablet\'s taskbar');
deq(M.lane(rows, state, '', opts), [], 'an unknown screen collects nothing');
assert.equal(M.lane(rows, null, 'eDP-1', { fallbackPage: 5 }).find((e) => e.row.address === 'a2').home, 5,
    'no state yet: the page this screen shows');
assert.equal(M.lane([], state, 'eDP-1', opts).length, 0);
// Without the hide (Platinum's lanes.js view), the same screen lists only a1, a4, a3.
deq(M.lane(rows.filter((r) => !M.isHidden(r)), {}, 'eDP-1', opts).map((e) => e.row.address), ['a1', 'a4', 'a3']);
// 0x addresses match the file's keys.
assert.equal(M.lane([hid('0xa2', 'zed', 'eDP-1')], state, 'eDP-1', opts)[0].home, 2);
// Many: 60 windows, every third minimized, stay in page order.
const many = Array.from({ length: 60 }, (_, i) => i % 3 ? row('m' + i, 'app', 1 + (i % 7), 'eDP-1') : hid('m' + i, 'app', 'eDP-1'));
const manyState = { version: 1, windows: {} };
many.forEach((r, i) => { if (!(i % 3)) manyState.windows['m' + i] = { app: 'app', page: 1 + (i % 7), screen: 'eDP-1', title: '' }; });
const ml = M.lane(many, manyState, 'eDP-1', opts);
assert.equal(ml.length, 60);
for (let i = 1; i < ml.length; i++) assert.ok(ml[i - 1].home <= ml[i].home);
assert.equal(ml.filter((e) => e.minimized).length, 20);

// ---- page names (page-names.js): never numbers
deq(N.listNames(['Signal', 'Zed', 'Signal', 'Ghostty']), 'Signal, Zed and Ghostty', 'repeats dropped, order kept');
deq(N.beside(['Signal', 'Zed']), 'Beside Signal and Zed');

// ---- Move to ▸ over the lane: every page on this screen, named by its
// apps without the window being moved; its own page checked and grey
const NAMES = { term: 'Ghostty', zed: 'Zed', chromium: 'Chromium', signal: 'Signal', obs: 'OBS Studio', tx: 'Transmission' };
const appName = (id) => NAMES[id] || id;
const pw = M.pageWindows(lane, appName);
deq(pw.map((w) => [w.page, w.name, w.address]), [[1, 'Ghostty', 'a1'], [1, 'Signal', 'a4'], [1, 'OBS Studio', 'c1'],
    [2, 'Zed', 'a2'], [2, 'Chromium', 'a3'], [3, 'Transmission', 'd1']], 'minimized windows count on their home page');
let mp = N.movePages(pw, 'a3', 2, 1, [1, 2, 3, 7]);
deq(mp, { pages: [
    { page: 1, current: false, label: 'Beside Ghostty, Signal and OBS Studio' },
    { page: 2, current: true, label: 'Beside Zed' },
    { page: 3, current: false, label: 'Beside Transmission' }], newPage: 8 });
mp = N.movePages(pw, 'd1', 3, 5, []);
deq(mp.pages.map((p) => p.label), ['Beside Ghostty, Signal and OBS Studio', 'Beside Zed and Chromium', 'On its own', 'Empty page']);
deq(N.listNames(N.namesOn(pw, 2, '')), 'Zed and Chromium', "a divider's tooltip: the band's apps");

// ---- the window menu
const plainText = (t) => t.replace(/&(&?)/g, (m, lit) => lit ? '&' : '');
const move = N.movePages(pw, 'a3', 2, 1, [1, 2, 3, 7]);
let wm = plain(M.windowMenu({ minimized: false, maximized: false, move }));
deq(wm.map((i) => i.separator ? '-' : plainText(i.text)), ['Restore', 'Move to', 'Minimize', 'Maximize', '-', 'Close']);
deq(wm.map((i) => i.enabled !== false), [false, true, true, true, true, true], 'a normal window: Restore is grey');
deq(wm[1].submenu.map((i) => i.separator ? '-' : plainText(i.text)),
    ['Beside Ghostty, Signal and OBS Studio', 'Beside Zed', 'Beside Transmission', '-', 'New page']);
deq([wm[1].submenu[1].checked, wm[1].submenu[1].enabled], [true, false], 'its own page is checked and grey');
deq([wm[1].submenu[4].act, wm[1].submenu[4].page], ['move', 8]);
deq([wm[5].bold, wm[5].shortcut, wm[5].act], [true, 'Alt+F4', 'close'], 'Close is the default item');
deq(plain(M.windowMenu({ move: { pages: [{ page: 1, current: false, label: 'Beside A&B' }], newPage: 2 } }))[1].submenu[0].text,
    'Beside A&&B', 'an app name is data: its & is literal');
wm = plain(M.windowMenu({ minimized: true, maximized: false, move }));
deq(wm.map((i) => i.enabled !== false), [true, true, false, true, true, true], 'minimized: Restore on, Minimize grey');
wm = plain(M.windowMenu({ minimized: false, maximized: true, move }));
deq(wm.map((i) => i.enabled !== false), [true, true, true, false, true, true], 'maximized: Restore on, Maximize grey');
wm = plain(M.windowMenu({}));
deq(wm[1].submenu.map((i) => plainText(i.text)), ['New page'], 'no pages known: New page alone');
// No page number in any menu text, at any size of lane.
for (const l of [lane, ml, []]) {
    const m = N.movePages(M.pageWindows(l, appName), 'm3', 1, 1, [1, 2, 9, 40]);
    const text = JSON.stringify(plain(M.windowMenu({ move: m })).map((i) => [i.text, (i.submenu || []).map((x) => x.text)]));
    assert.ok(!/\bpage\s*\d/i.test(text) && !/\d/.test(text.replace(/Alt\+F4/g, '')), text);
}
// Access keys are unique per level.
const keysOf = (items) => items.filter((i) => !i.separator && /&[^&]/.test(i.text)).map((i) => /&([^&])/.exec(i.text)[1].toLowerCase());
assert.equal(new Set(keysOf(wm)).size, 5);

// ---- the taskbar menu
let tm = plain(M.taskbarMenu({ shown: 3, others: 2, hidden: 0 }));
deq(tm.map((i) => i.separator ? '-' : plainText(i.text) + (i.enabled === false ? ' (off)' : '')),
    ['Minimize All Windows', 'Minimize Other Windows', 'Restore All Windows (off)', '-', 'Find...']);
deq([tm[4].shortcut, tm[4].act], ['Super+P', 'find']);
tm = plain(M.taskbarMenu({ shown: 0, others: 0, hidden: 4 }));
deq(tm.map((i) => i.enabled !== false), [false, false, true, true, true], 'everything minimized: Restore All only');
assert.equal(new Set(keysOf(tm)).size, 4);

// ---- the Cool Switch box: 7 a row, fewer when narrow; rows scroll to the current one
let cp = plain(M.coolPlan(11, 3, 1280, 800));
deq([cp.cols, cp.rows, cp.shown, cp.first, cp.width, cp.height], [7, 2, 2, 0, 7 * 43 + 16, 16 + 86 + 6 + 20]);
cp = plain(M.coolPlan(3, 0, 1280, 800));
deq([cp.cols, cp.rows, cp.width], [3, 1, 3 * 43 + 16], 'as wide as its windows');
// 360 x 640 logical px at 1.5 is 240 x 427 u, 399 u above the taskbar.
cp = plain(M.coolPlan(22, 21, 240, 399));
assert.equal(cp.cols, 5);
assert.ok(cp.width <= 236 && cp.height <= 395, JSON.stringify(cp));
assert.ok(cp.first <= Math.floor(21 / cp.cols) && Math.floor(21 / cp.cols) < cp.first + cp.shown, 'the current window is in view');
// Short: 1280 x 360 px is 853 x 240 u, 212 u above the taskbar; 22
// windows in 4 rows, fewer shown.
cp = plain(M.coolPlan(22, 0, 853, 212));
assert.ok(cp.shown < cp.rows && cp.height <= 208, JSON.stringify(cp));
assert.equal(M.moreText(cp.above, cp.below), cp.below + ' more row' + (cp.below > 1 ? 's' : '') + ' below');
assert.equal(M.moreText(1, 2), '1 more row above, 2 more rows below');
assert.equal(M.moreText(0, 0), '');
// Every size from tiny up: the box fits and the current cell is shown.
for (const [w, h] of [[40, 60], [100, 100], [240, 399], [853, 212], [1280, 772]]) {
    for (const n of [1, 2, 7, 8, 22, 60]) {
        for (const cur of [0, n - 1, Math.floor(n / 2)]) {
            const p = M.coolPlan(n, cur, w, h);
            assert.ok(p.width <= w - 4, `${w}x${h} n=${n}: width ${p.width}`);
            if (h >= 200) assert.ok(p.height <= h - 4, `${w}x${h} n=${n}: height ${p.height}`);
            const r = Math.floor(cur / p.cols);
            assert.ok(r >= p.first && r < p.first + p.shown, `${w}x${h} n=${n} cur=${cur}`);
            assert.equal(p.above + p.shown + p.below, p.rows);
        }
    }
}
assert.equal(M.coolPlan(0, 0, 1280, 800).width, 0);

// ---- Shut Down Myoko
const choices = plain(S.shutdownChoices('simon'));
deq(choices.map((c) => [c.id, plainText(c.text), c.what, c.closes]), [
    ['standby', 'Stand by', 'sleep', false], ['shutdown', 'Shut down', 'shutdown', true],
    ['restart', 'Restart', 'restart', true], ['logoff', 'Log off simon', 'logout', true]]);
assert.equal(new Set(choices.map((c) => (/&(.)/.exec(c.text) || [])[1].toLowerCase())).size, 4);
assert.equal(S.initialChoice(''), 'standby');
assert.equal(S.initialChoice('restart\n'), 'restart', 'the last OK\'d choice');
assert.equal(S.initialChoice('lock'), 'standby', 'an unknown choice: Stand by');
deq(plain(S.shutPlan(1280)), { width: 316, icon: true });
deq(plain(S.shutPlan(240)), { width: 236, icon: false }, '360 px: the icon goes');
assert.equal(S.WARNING, 'Open windows close without saving.');

// ---- System Properties
deq(plain(S.sysPlan(1280)), { width: 420, stack: false, picture: true });
deq(plain(S.sysPlan(240)), { width: 236, stack: true, picture: true });
deq(plain(S.sysPlan(200)), { width: 196, stack: true, picture: false });
assert.equal(S.uptimeText(152760), '1 day, 18:26');
assert.equal(S.uptimeText(3 * 86400 + 65), '3 days, 0:01');
assert.equal(S.uptimeText(-1), 'Unknown');
let facts = plain(S.sysFacts({ host: 'myoko', product: 'Galaxy Book3 Pro 360', version: { nixosVersion: '26.05.20260313.c06b4ae' },
    generation: '160', uptime: 152760, user: 'simon' }));
deq(facts, [
    { heading: 'System:', lines: ['NixOS 26.05.20260313.c06b4ae', 'Generation 160', 'Revision: Not recorded'] },
    { heading: 'Registered to:', lines: ['simon'] },
    { heading: 'Computer:', lines: ['Myoko', 'Galaxy Book3 Pro 360'] },
    { heading: 'Running for:', lines: ['1 day, 18:26'] }]);
facts = plain(S.sysFacts({ version: { configurationRevision: 'abc123' } }));
deq(facts[0].lines, ['NixOS Unknown', 'Revision: abc123']);
deq(facts[2].lines, ['Unknown']);

// ---- the volume pop-up: above its icon, inside the screen
let pp = plain(S.popupPlan(1280, 1200, 16));
deq([pp.x, pp.width, pp.label], [1142, 132, true]);
assert.equal(pp.blocks, Math.floor((132 - 12 - 4 + 1) / 4));
pp = plain(S.popupPlan(1280, 1270, 10));
assert.equal(pp.x + pp.width, 1278, 'kept 2 u inside the right edge');
pp = plain(S.popupPlan(100, 50, 10));
deq([pp.width, pp.label, pp.x], [96, false, 2], 'narrow: the word goes');
deq(plain(S.popupText('vol', 42, false)), { label: 'Volume', value: '42%' });
deq(plain(S.popupText('vol', 42, true)), { label: 'Volume', value: 'Muted' });
deq(plain(S.popupText('bri', 60.4, false)), { label: 'Brightness', value: '60%' });
console.log('WIN98_TASK_SESSION_TESTS_PASSED');
