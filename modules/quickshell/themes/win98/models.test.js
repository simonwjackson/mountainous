// tray-model.js and start-model.js: the tray's icons, badges and tooltips,
// and the Start menu's lists.
// Run: node models.test.js tray-model.js start-model.js
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
// start-model.js .imports ../../app-icon.js as AppIcon, as QML does.
const load = (file, ctx = {}) => {
    vm.runInNewContext(fs.readFileSync(file, 'utf8').replace(/^\.pragma library\s*$/m, '')
        .replace(/^\.import "\.\.\/\.\.\/app-icon\.js" as AppIcon\s*$/m, ''), ctx);
    return ctx;
};
const T = load(process.argv[2] || __dirname + '/tray-model.js');
const startModel = process.argv[3] || __dirname + '/start-model.js';
const S = load(startModel, { AppIcon: load(path.join(path.dirname(startModel), '../../app-icon.js')) });
const plain = (v) => JSON.parse(JSON.stringify(v));

// ---- icons
assert.equal(T.volumeIcon(true, 42), 'volume-muted');
assert.equal(T.volumeIcon(false, 0), 'volume-0');
assert.equal(T.volumeIcon(false, 50), 'volume-1');
assert.equal(T.volumeIcon(false, 51), 'volume-2');
assert.equal(T.wifiLevel(false, 0.9), 0);
assert.equal(T.wifiLevel(true, 0.75), 4);
assert.equal(T.wifiLevel(true, 0.74), 3);
assert.equal(T.wifiLevel(true, 0.1), 1);
assert.equal(T.wifiIcon(true, 3), 'wifi-off');
assert.equal(T.diskIcon('loading', 'ok'), 'disk-muted');
assert.equal(T.diskIcon('stale', 'ok'), 'disk-warn');
assert.equal(T.diskIcon('ready', 'bad'), 'disk-bad');
assert.equal(T.bellIcon('ready', 0), 'bell-muted');
assert.equal(T.bellIcon('ready', 3), 'bell');
assert.equal(T.bellIcon('offline', 3), 'bell-muted');
assert.equal(T.builderIcon({ off: true, grey: true }), 'builder-off-grey');
assert.equal(T.builderIcon({ off: true }), 'builder-off');
assert.equal(T.builderIcon({ wait: true, off: true }), 'builder-wait');
assert.equal(T.micIcon('failed'), 'mic-failed');
assert.equal(T.batteryIcon('bolt'), 'battery-bolt');

// ---- badges: count, 99+, offline, running builds
const d = {
    disk: { state: 'ready', issues: 3, label: 'Disks 3 issues', statusText: 'Checked 16:47, again every 5 minutes' },
    ntf: { view: 'ready', count: 128, urgent: 1, badgeKind: 'none', badgeText: '' },
    builder: { ready: true, pending: '', running: 2, tooltip: ['Running 2 builds for the fleet', 'At home.', 'Click to turn builds off. Right-click for more.'], barText: 'Building 2' },
    bt: { present: true, on: true, count: 1 },
    wifi: { present: true, hw: true, enabled: true, name: 'kamoi-5g', signal: 0.81 },
    vol: { muted: false, percent: 42, name: 'Built-in Speakers' },
    bri: { level: 60 },
    oci: { state: 'ready', stateText: 'Outbound data, Zone 1', rows: [{ name: 'DEFAULT', value: '38.0%' }] },
    bat: { percent: 87, onBattery: true, indicator: '' },
    dict: { text: 'Recording' },
    clock: { date: 'Thursday, October 22, 2026' }
};
assert.equal(T.badge('disk', d), '3');
assert.equal(T.badge('ntf', d), '99+');
assert.equal(T.badge('builder', d), '2');
assert.equal(T.badge('ntf', Object.assign({}, d, { ntf: { view: 'offline', count: 0 } })), '!');
assert.equal(T.badge('disk', Object.assign({}, d, { disk: { state: 'loading', issues: 3 } })), '');
assert.equal(T.badge('bt', d), '');

// ---- tooltips: the mock's words; the builder's without its click line
assert.equal(T.tooltip('vol', d), 'Volume 42%\nBuilt-in Speakers');
assert.equal(T.tooltip('bat', d), '87% remaining');
assert.equal(T.tooltip('bt', d), 'Bluetooth 1 connected');
assert.equal(T.tooltip('wifi', d), 'Wi-Fi kamoi-5g, 81%');
assert.equal(T.tooltip('ntf', d), '99+ notifications\n1 urgent');
assert.equal(T.tooltip('disk', d), 'Server storage: 3 issues\nChecked 16:47, again every 5 minutes');
assert.equal(T.tooltip('oci', d), 'OCI egress this month\nDEFAULT 38.0%');
assert.equal(T.tooltip('builder', d), 'Running 2 builds for the fleet\nAt home.');
assert.equal(T.tooltip('start', d), 'Click here to begin.');
assert.equal(T.tooltip('clock', d), 'Thursday, October 22, 2026');
assert.equal(T.tooltip('disk', Object.assign({}, d, { disk: { state: 'loading', issues: 0, label: 'Disks ...', statusText: 'Checking the servers\u2026' } })),
    'Server storage: checking...\nChecking the servers...');

// ---- the clock: 12-hour with AM/PM
assert.deepEqual(plain(T.clock(new Date(2026, 9, 22, 16, 51))), { time: '4:51', ampm: 'PM' });
assert.deepEqual(plain(T.clock(new Date(2026, 9, 22, 0, 5))), { time: '12:05', ampm: 'AM' });
assert.equal(T.dictationText('Working', 'Zao', 3, '3 takes'), 'Working \u00b7 Zao \u00b7 3 takes');

// ---- Start: programs by category, one folder becomes a flat list
const apps = [
    { id: 'chromium-browser', name: 'Chromium', categories: ['Network', 'WebBrowser'] },
    { id: 'signal', name: 'Signal', categories: ['Network', 'Chat'] },
    { id: 'dev.zed.Zed', name: 'Zed', categories: ['Development'] },
    { id: 'misc', name: 'Rock & Roll', categories: [] }
];
const p = plain(S.programs(apps));
assert.deepEqual(p.map(f => f.text), ['Development', 'Internet', 'Other']);
assert.deepEqual(p[1].submenu.map(a => a.text), ['Chromium', 'Signal']);
// Chromium and its web apps draw the icon theme's art (Chicago95's browser,
// the lettermarks), never the set's own Chromium logo.
assert.equal(p[1].submenu[0].icon, 'theme:chromium');
assert.equal(S.appIcon('chromium-browser', ''), 'theme:chromium');
assert.equal(S.appIcon('chromium', ''), 'theme:chromium');
assert.equal(S.appIcon('chrome-www.reddit.com__-Default', ''), 'theme:chrome-www.reddit.com__-Default');
assert.equal(S.appIcon('chrome-lneafpomhdmfgkblnkjeglpppndalpik-Default', 'Jellyfin'), 'theme:chrome-lneafpomhdmfgkblnkjeglpppndalpik-Default');
assert.equal(S.appIcon('', 'Chromium'), '', 'a name alone is not a browser');
assert.equal(S.appIcon('com.mitchellh.ghostty', 'Ghostty'), 'term');
assert.equal(S.appIcon('md.obsidian.Obsidian', 'Obsidian'), '');
assert.equal(S.appIcon('com.obsproject.Studio', 'OBS Studio'), 'obs');
assert.equal(p[2].submenu[0].text, 'Rock && Roll', 'data never carries an access key');
const flat = plain(S.programs([{ id: 'a', name: 'Beta', categories: [] }, { id: 'b', name: 'Alpha', categories: [] }]));
assert.deepEqual(flat.map(a => a.text), ['Alpha', 'Beta']);
assert.deepEqual(plain(S.programs([])), []);
// Windows: every window, pages apart by separators (never numbered); long
// titles cut with three dots; a minimized window says so.
const w = plain(S.windows([{ title: 'x'.repeat(60), page: 2, icon: 'term' }]));
assert.equal(w[0].text, 'x'.repeat(41) + '...');
assert.equal(w[0].shortcut, undefined, 'no page number');
const wp = plain(S.windows([{ title: 'a', page: 1 }, { title: 'b', page: 1, hint: 'Minimized' }, { title: 'c', page: 4 }, { title: 'd', page: 7 }]));
assert.deepEqual(wp.map(i => i.separator ? '-' : i.text + (i.shortcut ? ' ' + i.shortcut : '')), ['a', 'b Minimized', '-', 'c', '-', 'd']);
assert.deepEqual(wp.filter(i => !i.separator).map(i => i.window), [0, 1, 2, 3]);
assert.ok(!/\bpage\s*\d/i.test(JSON.stringify(wp)));
assert.equal(plain(S.windows([]))[0].enabled, false);
// Commands: no theme rows, no window mode; scale rows cascade
const rows = [
    { kind: 'cmd', label: 'New terminal', detail: 'Super+N', act: 'term' },
    { kind: 'cmd', label: 'Go to address', detail: 'Ctrl+L', act: 'mode:nav' },
    { kind: 'cmd', label: 'Go to window', detail: 'mode', act: 'mode:window' },
    { kind: 'cmd', label: 'Interface scale up', detail: 'Super+=', act: 'scaleup' },
    { kind: 'cmd', label: 'Toggle bars', detail: 'Super+I', act: 'chrome' },
    { kind: 'cmd', label: 'Dark appearance', detail: 'Super+D', act: 'theme:dark' },
    { kind: 'cmd', label: 'Desktop theme\u2026', detail: 'Appearance', act: 'theme:picker' }
];
const c = plain(S.commands(rows));
assert.deepEqual(c.map(r => r.separator ? '-' : r.text), ['New terminal', 'Go to address...', '-', 'Interface scale', 'Toggle bars']);
assert.equal(c[3].submenu[0].text, 'Scale up');
// The top level: Favorites and Documents after Programs; Lock, Log Off
// and Shut Down at the bottom; Display... opens the picker, System... the
// System Properties.
const fav = plain(S.favorites([{ id: 'ytmusic', name: 'YouTube Music', icon: 'webapp-ytmusic' }, { id: 'gh', name: 'GitHub', icon: 'webapp-gh' }, null]));
assert.deepEqual(fav.map(i => i.text), ['GitHub', 'YouTube Music'], 'by name');
assert.deepEqual([fav[0].action, fav[0].webapp, fav[0].themeIcon], ['webapp', 1, 'webapp-gh']);
assert.deepEqual(plain(S.favorites([])), [{ text: '(Empty)', enabled: false }]);
const recent = Array.from({ length: 20 }, (_, i) => ({ id: i ? 'app' + i : 'dev.zed.Zed', name: i ? 'App & ' + i : 'Zed', icon: 'icon' + i, kind: i === 1 ? 'webapp' : 'app' }));
const docs = plain(S.documents(recent));
assert.equal(docs.length, 15, 'at most 15');
assert.deepEqual([docs[0].text, docs[0].icon, docs[0].themeIcon, docs[0].recent], ['Zed', 'zed', '', 0], 'a known app takes its Win98 icon');
assert.deepEqual([docs[1].text, docs[1].icon, docs[1].themeIcon, docs[1].shortcut], ['App && 1', '', 'icon1', 'web app'], 'data never carries an access key');
assert.deepEqual(plain(S.documents([])), [{ text: '(Empty)', enabled: false }]);
assert.deepEqual(plain(S.documents(null)), [{ text: '(Empty)', enabled: false }]);
const top = plain(S.top(p, w, c, 'simon', [], { favorites: fav, documents: docs, host: 'myoko' }));
assert.deepEqual(top.map(i => i.separator ? '-' : i.text),
    ['&Programs', 'Fa&vorites', '&Documents', '&Windows', '&Commands', '&Settings', '-', '&Find', '&Run...', '-', 'Loc&k Myoko', '&Log Off simon...', 'Sh&ut Down...']);
assert.deepEqual(top[1].submenu, fav);
assert.deepEqual([top[10].action, top[11].action, top[12].action], ['lock', 'logoff', 'shutdown']);
// Start > Find: the Find window in each scope, and Open (Ctrl+L); Run... is Find in All.
const find = top.find(i => i.text === '&Find');
assert.deepEqual(find.submenu.filter(i => !i.separator).map(i => [i.action, i.scope]),
    [['find', 'all'], ['find', 'app'], ['find', 'win'], ['find', 'cmd'], ['find', 'address']]);
assert.equal(top.find(i => i.text === '&Run...').action, 'run');
assert.equal(top[5].submenu[0].action, 'picker');
assert.deepEqual([top[5].submenu[1].text, top[5].submenu[1].action], ['S&ystem...', 'system']);
assert.deepEqual(plain(S.top(p, w, c, 'simon'))[1].submenu, [{ text: '(Empty)', enabled: false }], 'no lists: (Empty)');
assert.equal(plain(S.top(p, w, c, 'simon'))[10].text, 'Loc&k', 'no host name yet');
// Access keys stay unique on the top level.
const keys = top.filter(i => !i.separator).map(i => (/&(.)/.exec(i.text) || [])[1].toLowerCase());
assert.equal(new Set(keys).size, keys.length, keys.join(''));
// A bar too narrow for its tray: Start gains a Taskbar cascade, after Settings.
const narrow = plain(S.top(p, w, c, 'simon', [{ text: 'Sound', action: 'open', control: 'vol' }]));
assert.equal(narrow[6].text, 'T&askbar');
assert.equal(narrow[6].submenu[0].control, 'vol');
assert.equal(plain(S.top(p, w, c, 'simon', [])).length, plain(S.top(p, w, c, 'simon')).length);
// Super+O: every tray letter, N for Notifications included.
assert.deepEqual(Object.keys(T.CHORD).map(k => T.CHORD[k]).join(''), 'BWSLCDFRN');
assert.equal(T.CHORD.ntf, 'N');
console.log('WIN98_MODEL_TESTS_PASSED');
