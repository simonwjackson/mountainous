// Fixtures for the Win98 Desktop harness and its checks: the approved
// mock's data.js and states.js (/tmp/win98-mock), unchanged except that the
// two files are joined here, object spread is written Object.assign (QML's
// engine has no object spread), and dataFor/stateIds are exported.
.pragma library
// Data for the Win98 taskbar mock. Every field mirrors a QML property in
// modules/quickshell (read-only; DESIGN ff213250, BUILD 15725e04).
// Window, app and page data are fixtures: Myoko's desktop entries were not
// read (this machine is zao). App names are inferred from modules/.

const W_IDEAL = [
  { app: 'Ghostty', icon: 'term', title: 'simon@myoko: ~/code/github/simonwjackson/mountainous', page: 1, focused: true },
  { app: 'Chromium', icon: 'chromium', title: 'Windows 98 - Wikipedia - Chromium', page: 1 },
  { app: 'Signal', icon: 'signal', title: 'Signal', page: 2 },
  { app: 'Zed', icon: 'zed', title: 'bar-plan.js - mountainous', page: 2 },
  { app: 'OBS Studio', icon: 'obs', title: 'OBS 31.1.2 - Profile: myoko - Scenes: Desk', page: 3 } ];
const W_MANY = [
  { app: 'Ghostty', icon: 'term', title: 'simon@myoko: ~/code/github/simonwjackson/mountainous', page: 1, focused: true },
  { app: 'Chromium', icon: 'chromium', title: 'Windows 98 - Wikipedia - Chromium', page: 1 },
  { app: 'Ghostty', icon: 'term', title: 'htop', page: 1 },
  { app: 'Signal', icon: 'signal', title: 'Signal', page: 2 }, { app: 'Zed', icon: 'zed', title: 'TopBar.qml - mountainous', page: 2 },
  { app: 'Zed', icon: 'zed', title: 'bar-plan.js - mountainous', page: 2 }, { app: 'Chromium', icon: 'chromium', title: 'YouTube Music', page: 2 },
  { app: 'OBS Studio', icon: 'obs', title: 'OBS 31.1.2 - Profile: myoko - Scenes: Desk', page: 3 }, { app: 'Transmission', icon: 'tx', title: 'Transmission', page: 3 },
  { app: 'Ghostty', icon: 'term', title: 'ssh zao', page: 4 }, { app: 'Ghostty', icon: 'term', title: 'ssh unzen', page: 4 }, { app: 'Chromium', icon: 'chromium', title: 'Grafana - Storage', page: 4 } ];
const W_HUGE = W_MANY.concat([
  { app: 'Firefox', icon: 'firefox', title: 'Mozilla Firefox', page: 5 }, { app: 'Sunshine', icon: 'sun', title: 'Sunshine', page: 5 },
  { app: 'Ghostty', icon: 'term', title: 'nix build .#nixosConfigurations.zao', page: 5 }, { app: 'Chromium', icon: 'chromium', title: 'Gmail', page: 5 },
  { app: 'Chromium', icon: 'chromium', title: 'Google Calendar', page: 6 }, { app: 'Signal', icon: 'signal', title: 'Signal - Aiko', page: 6 },
  { app: 'Zed', icon: 'zed', title: 'shell.qml - mountainous', page: 6 }, { app: 'Ghostty', icon: 'term', title: 'journalctl -fu quickshell', page: 6 },
  { app: 'Syncthing', icon: 'sync', title: 'Syncthing', page: 6 }, { app: 'Ghostty', icon: 'term', title: 'btop', page: 6 } ]);

function baseData() {
  return {
    // shell.qml dockWindow.lane = Lanes.windowsOn(): every window on this screen, all pages, by page.
    // showing = Lanes.isShown (workspace.active); focused = toplevel.activated; urgent: no code (see STATES.md).
    showingPage: 1,
    windows: W_IDEAL.map(w => (Object.assign({}, w))),
    clock: { date: 'Thursday, October 22, 2026', time: '4:51', ampm: 'PM', day: 22, month: 'October 2026', firstDow: 4, days: 31 },
    chord: false,                                         // root.topbarAccessVisible (SUPER+O)
    ociEnabled: true, diskEnabled: true,
    dict: { state: 'idle', backend: '', queue: 0, failureKind: '', canRetry: false },
    // BuilderGate.qml: sample {kind, value}, pending, actionError {command, detail}; enabled = ready || error.
    builder: { sample: { kind: 'ready', value: { accepting: true, reason: 'home', location: 'home', power: 'ac', choice: null, running: 0 } }, pending: '', actionError: null, keyboard: false },
    bt: { adapter: true, enabled: true, astate: 'on', discovering: false, devices: [
      { name: 'Galaxy Buds2 Pro', address: 'B4:9D:02:6E:11:3A', connected: true, paired: true, battery: 70 },
      { name: 'MX Master 3S', address: 'D2:41:7C:90:0B:E5', paired: true, battery: 55 },
      { name: '', address: '5C:F3:70:A1:22:9B' } ] },
    wifi: { device: true, hw: true, enabled: true, scanning: false, failure: '', password: null, networks: [
      { name: 'kamoi-5g', signal: 0.81, connected: true, known: true, security: 'secured' },
      { name: 'kamoi-iot', signal: 0.64, known: true, security: 'secured' },
      { name: 'Myoko Guest', signal: 0.52, security: 'open' },
      { name: 'eduroam', signal: 0.31, security: 'enterprise' } ] },
    sound: { ready: true, outputs: [
      { name: 'Built-in Speakers', vol: 0.42, muted: false, def: true },
      { name: 'Galaxy Buds2 Pro', vol: 0.60, muted: false },
      { name: 'U2723QE (HDMI 1)', vol: 0.35, muted: true } ],
      inputs: [
      { name: 'Built-in Microphone', vol: 0.80, muted: false, def: true },
      { name: 'Galaxy Buds2 Pro', vol: 0.55, muted: false } ] },
    bri: { level: 60, rows: [ { label: 'Laptop screen', detail: 'eDP-1', follows: true } ] },
    oci: { state: 'ready', rows: [
      { name: 'DEFAULT', percent: '38.0', used: '3891.2', projected: '5585' },
      { name: 'family', percent: '4.1', used: '419.8', projected: '603' } ] },
    disk: { state: 'ready', checkedAt: '16:47', checking: false, rows: [
      { host: 'simon@unzen', level: 'ok', message: 'all checks passed' } ] },
    ntf: { conn: 'connected', retryIn: 0, status: { server: 'connected', outbox: 0, last_error: null }, items: [
      { app_name: 'nixos-rebuild', summary: 'Build finished: myoko', body: 'nixos-rebuild switch completed in 3 min 12 s.', urgency: 1, origin: 'remote', host: 'zao', updated: 4, actions: [{ key: 'default', label: '' }], sender_alive: true },
      { app_name: 'Calendar', summary: 'Dentist at 9:30', body: 'Tomorrow, Dr. Ito, Shinmachi 2-14.', urgency: 1, origin: 'local', host: '', updated: 38, actions: [{ key: 'snooze', label: 'Snooze' }, { key: 'default', label: 'Open' }], sender_alive: true },
      { app_name: 'Signal', summary: 'Aiko', body: 'Are you still coming on Saturday? We can move it to Sunday if that is easier.', urgency: 1, origin: 'local', host: '', updated: 55, actions: [{ key: 'reply', label: 'Reply' }, { key: 'read', label: 'Mark as read' }], sender_alive: true } ] },
    // TopBar.battery: UPower displayDevice; battery.js rule(percent, charging, full, onBattery).
    bat: { present: true, onBattery: true, pct: 87, charging: false, full: false },
    flatPrograms: false,
  };
}

// Programs: DesktopEntries.applications (OmniBar.appRows), grouped by the
// entry's freedesktop main category. The grouping is new; the list is not.
const PROGRAMS = {
  Accessories: [['GVim', 'doc'], ['Vim', 'doc']],
  Development: [['Zed', 'zed']],
  Internet: [['Chromium', 'chromium'], ['Firefox', 'firefox'], ['Signal', 'signal'], ['Sunshine', 'sun'], ['Syncthing', 'sync'], ['Transmission', 'tx']],
  Multimedia: [['OBS Studio', 'obs']],
  System: [['Ghostty', 'term'], ['Htop', 'term'], ['NixOS Manual', 'doc']],
};
// A long flat list: OmniBar.appRows as the code builds it (sorted by name, no categories).
const MANY_APPS = ['Audacity', 'Baobab', 'Blender', 'Bottles', 'Calculator', 'Celluloid', 'Characters', 'Cheese', 'Chromium', 'Clocks', 'Contacts', 'D-Spy', 'Darktable',
  'dconf Editor', 'Disks', 'Document Scanner', 'Element', 'Evince', 'Eye of GNOME', 'Files', 'Firefox', 'Fonts', 'Geary', 'Ghostty', 'GIMP', 'Gnumeric', 'GVim',
  'Heroic', 'Htop', 'Inkscape', 'Kdenlive', 'KeePassXC', 'Krita', 'LibreOffice Calc', 'LibreOffice Impress', 'LibreOffice Writer', 'Logs', 'Lutris', 'Maps',
  'Meld', 'Moonlight', 'mpv', 'Nautilus', 'NixOS Manual', 'OBS Studio', 'Obsidian', 'Pavucontrol', 'Picard', 'Prism Launcher', 'qBittorrent', 'RetroArch',
  'Seahorse', 'Shotwell', 'Signal', 'Spotify', 'Steam', 'Sunshine', 'Syncthing', 'Thunderbird', 'Transmission', 'VLC', 'Weather', 'Zed'];
// OmniBar.commandRows, as written in OmniBar.qml (the two theme rows move into the picker).
const COMMANDS = [
  ['New terminal', 'Super+N'], ['Go to address...', 'Ctrl+L'], ['Close window', 'Super+C'], ['Monocle', 'Super+M'], ['Zen', 'Super+Shift+M'],
  ['Mirror workspace', 'Super+Shift+G'], ['Even / golden split', 'Super+G'], ['Screenshot', 'Super+S'] ];

const BT_NAMES = ['Galaxy Buds2 Pro', 'MX Master 3S', 'HHKB Hybrid', 'Pixel 9', 'Jabra Speak 510', 'Sony WH-1000XM5', 'Xbox Wireless Controller', 'Kindle Paperwhite', 'Apple Magic Trackpad', 'Bose SoundLink Flex', 'JBL Flip 6', 'Garmin Forerunner 265', 'Nintendo Switch Pro Controller', 'LE-Bedroom TV'];
const SSIDS = ['kamoi-5g', 'kamoi-iot', 'Myoko Guest', 'eduroam', 'NETGEAR42', 'Buffalo-G-8D3A', 'aterm-5c2b1e-g', 'FreeSpot', 'SoftBank Air', 'au_Wi-Fi2', 'DIRECT-7A-HP OfficeJet', 'Rakuten-4B21', '7SPOT', 'Starbucks_Wi2', 'JR-EAST_FREE_Wi-Fi', 'pr500k-0f11a2-1', 'elecom2g-77b1', 'TP-Link_5E2C', 'ASUS_88_5G', 'xfinitywifi'];
const FINDINGS = [
  ['bad', 'zfs-scrub@tank.service failed'], ['warn', 'smartd.service failed'], ['bad', '/srv/lakes/towada is missing or not mounted'],
  ['warn', '/mnt/backup mount identity unavailable'], ['bad', 'restic-b2: last success 51 h ago'], ['warn', 'snapraid-sync history unreadable'],
  ['warn', 'towada shared cache filesystem 84% used'], ['bad', 'towada cache mover: rsync exit 23'], ['warn', 'towada last batch: copy; protected 1204, released 0 files; backlog 88 files / 4.1 GiB bytes'],
  ['warn', 'bcachefs hdd.3: 2 I/O errors since creation'], ['bad', 'expected towada member hdd.5 missing'], ['bad', 'towada member count 5 differs from expected 6'],
  ['warn', 'towada automatic source release held; cache can fill'], ['bad', 'bcachefs ssd.1 is ro'], ['warn', 'failed-unit query unavailable']];
const MSGS = [
  ['nixos-rebuild', 'Build finished: myoko', 'nixos-rebuild switch completed in 3 min 12 s.', 'zao'], ['Calendar', 'Dentist at 9:30', 'Tomorrow, Dr. Ito, Shinmachi 2-14.', ''],
  ['Signal', 'Aiko', 'Are you still coming on Saturday?', ''], ['claude', 'Agent finished: cairn', 'All 14 checks passed. 3 files changed.', 'yari'],
  ['Chromium', 'Download complete', 'quickshell-0.3.1.tar.gz', ''], ['restic', 'Backup finished', 'b2:myoko 2.1 GiB added, 0 errors.', 'unzen'],
  ['Thunderbird', 'Kenji Mori', 'Re: trip dates for November', ''], ['notify-send', 'Timer', 'Tea is ready.', '']];
function moreNotes(d, n) {
  d.ntf.items = [];
  for (let i = 0; i < n; i++) { const m = MSGS[i % MSGS.length];
    d.ntf.items.push({ app_name: m[0], summary: m[1], body: m[2], urgency: 1, origin: m[3] ? 'remote' : 'local', host: m[3], updated: 3 + i * 7, actions: i % 3 === 0 ? [{ key: 'default', label: 'Open' }] : [], sender_alive: true }); }
}
const bv = (o) => ({ kind: 'ready', value: Object.assign({ accepting: true, reason: 'home', location: 'home', power: 'ac', choice: null, running: 0 }, o) });
// State catalogue for the Win98 taskbar mock. Loaded by index.html and the
// sheets. Each state: data changes (set) and view parameters (p). See STATES.md.
const STATES = [];
function st(g, id, label, set, p) { STATES.push({ g, id, label, set: set || (() => {}), p: p || {} }); }
const setVol = (d, v, muted) => { const o = d.sound.outputs[0]; o.vol = v; o.muted = !!muted; };
const wifiLevel = (d, n) => { d.wifi.networks[0].signal = [0, 0.15, 0.4, 0.6, 0.85][n]; };
const LONG = 'nixos-rebuild-switch--flake-github:simonwjackson/mountainous#myoko--show-trace--option-eval-cache-false--print-build-logs--keep-going';

// 1. The taskbar alone
st(1, 'tb-normal', 'Normal: 5 windows on 3 pages, page 1 showing');
st(1, 'tb-empty', 'No windows at all', d => { d.windows = []; });
st(1, 'tb-one', 'One window', d => { d.windows = [{ app: 'Ghostty', icon: 'term', title: 'simon@myoko: ~', page: 1, focused: true }]; });
st(1, 'tb-many', '12 windows on 4 pages: buttons shrink', d => { d.windows = W_MANY.map(w => (Object.assign({}, w))); });
st(1, 'tb-huge', '22 windows on 6 pages: titles give way to icons', d => { d.windows = W_HUGE.map(w => (Object.assign({}, w))); });
st(1, 'tb-longtitle', 'Very long title with no break points (focused)', d => { d.windows[0].title = LONG; });
st(1, 'tb-nofocus', 'Focus on another screen: no button pressed', d => { d.windows.forEach(w => w.focused = false); });
st(1, 'tb-page2', 'Page 2 showing, its window focused', d => { d.showingPage = 2; d.windows.forEach(w => w.focused = false); d.windows[2].focused = true; });
st(1, 'tb-attention-on', 'A window wants attention: flash, lit frame (no code rule)', d => { d.windows[3].urgent = true; }, { flash: 'on' });
st(1, 'tb-attention-off', 'A window wants attention: flash, dark frame', d => { d.windows[3].urgent = true; }, { flash: 'off' });
st(1, 'tb-drag', 'A window dragged onto page 2 (dropOnto)', null, { drag: 1 });
st(1, 'tb-chord', 'SUPER+O: each tray icon shows its key', d => { d.chord = true; });
st(1, 'dict-recording', 'Dictation: Recording', d => { d.dict = { state: 'recording', backend: '', queue: 1 }; });
st(1, 'dict-working', 'Dictation: Working · Groq', d => { d.dict = { state: 'working', backend: 'groq', queue: 1 }; });
st(1, 'dict-queued', 'Dictation: Working · Zao · 3 takes', d => { d.dict = { state: 'working', backend: 'zao', queue: 3 }; });
st(1, 'dict-failed', 'Dictation failed · Groq: Retry and Dismiss', d => { d.dict = { state: 'failed', backend: 'groq', queue: 1, failureKind: 'backend', canRetry: true }; });
st(1, 'dict-micfail', 'Microphone failed: Dismiss only', d => { d.dict = { state: 'failed', backend: '', queue: 0, failureKind: 'recorder', canRetry: false }; });

// 2. Every control: rest, hover, open or pressed, keyboard focus
const CONTROLS = [['start', 'Start button'], ['win1', 'Window button'], ['dict', 'Dictation'], ['bt', 'Bluetooth'], ['wifi', 'Wi-Fi'], ['vol', 'Sound'], ['bri', 'Brightness'],
  ['oci', 'OCI egress'], ['disk', 'Server storage'], ['builder', 'Remote builds'], ['ntf', 'Notifications'], ['bat', 'Battery'], ['clock', 'Clock'], ['tasks', 'Windows » (600 px)'], ['more', 'Tray » (400 px)']];
const MENU_OF = { start: 'start', dict: 'dict', bt: 'bt', wifi: 'wifi', vol: 'vol', bri: 'bri', oci: 'oci', disk: 'disk', builder: 'builder', ntf: 'ntf', clock: 'clock', tasks: 'tasks', more: 'more' };
for (const [c, name] of CONTROLS) for (const k of ['rest', 'hover', 'open', 'focus']) {
  const p = { w: c === 'tasks' ? 600 : c === 'more' ? 400 : undefined };
  if (k === 'hover') { p.hov = c; if (c === 'win1') p.tip = 'win1'; }
  if (k === 'focus') p.focus = c;
  if (k === 'open') { if (MENU_OF[c]) p.open = MENU_OF[c]; else p.press = c; }
  st(2, `ix-${c}-${k}`, `${name}: ${k}`, c === 'dict' ? (d => { d.dict = { state: 'failed', backend: 'groq', queue: 1, failureKind: 'backend', canRetry: true }; }) : null, p);
}

// 3. Data states, each with its tooltip
const T = (id, label, set, p) => st(3, id, label, set, Object.assign({ tip: id.split('-')[0] }, p || {}));
T('bt-noadapter', 'Bluetooth: no adapter (icon hidden in code)', d => { d.bt.adapter = false; d.bt.devices = []; }, { tip: null });
T('bt-off', 'Bluetooth: off', d => { d.bt.enabled = false; d.bt.devices.forEach(x => x.connected = false); });
T('bt-on-0', 'Bluetooth: on, nothing connected', d => { d.bt.devices.forEach(x => x.connected = false); });
T('bt-on-1', 'Bluetooth: 1 connected');
T('bt-on-2', 'Bluetooth: 2 connected', d => { d.bt.devices[1].connected = true; });
T('wifi-hwoff', 'Wi-Fi: radio switch off', d => { d.wifi.hw = false; d.wifi.enabled = false; d.wifi.networks = []; });
T('wifi-off', 'Wi-Fi: turned off', d => { d.wifi.enabled = false; d.wifi.networks = []; });
T('wifi-nolink', 'Wi-Fi: on, no link', d => { d.wifi.networks.forEach(n => n.connected = false); });
for (const n of [1, 2, 3, 4]) T(`wifi-${n}`, `Wi-Fi: ${n} bar${n > 1 ? 's' : ''}`, d => wifiLevel(d, n));
T('vol-muted', 'Volume: muted', d => setVol(d, 0.42, true));
for (const v of [0, 9, 42, 100]) T(`vol-${v}`, `Volume: ${v}`, d => setVol(d, v / 100));
T('bri-low', 'Brightness: low (minimum 5)', d => { d.bri.level = 5; });
T('bri-full', 'Brightness: full', d => { d.bri.level = 100; });
T('oci-ok', 'OCI: ok');
T('oci-warn', 'OCI: one profile ≥ 50% (warning)', d => { d.oci.rows[0].percent = '62.4'; });
T('oci-danger', 'OCI: one profile ≥ 80% (danger)', d => { d.oci.rows[0].percent = '86.9'; });
T('oci-loading', 'OCI: loading', d => { d.oci.state = 'loading'; d.oci.rows = []; });
T('oci-unavailable', 'OCI: credentials unavailable', d => { d.oci.state = 'unavailable'; d.oci.rows = []; });
T('oci-error', 'OCI: request failed', d => { d.oci.state = 'error'; d.oci.rows.forEach(r => { r.percent = '--'; r.used = '--'; r.projected = '--'; }); });
T('disk-ok', 'Storage: ok');
T('disk-warn', 'Storage: 1 issue (warning)', d => { d.disk.rows = [{ host: 'simon@unzen', level: 'warn', message: 'towada shared cache filesystem 84% used' }]; });
T('disk-bad', 'Storage: 3 issues (danger)', d => { d.disk.rows = FINDINGS.slice(0, 3).map(f => ({ host: 'simon@unzen', level: f[0], message: f[1] })); });
T('disk-loading', 'Storage: first check running', d => { d.disk.state = 'loading'; d.disk.rows = []; });
T('disk-stale', 'Storage: stale result', d => { d.disk.state = 'stale'; d.disk.checkedAt = '2026-10-22 15:20'; });
T('disk-error', 'Storage: check failed', d => { d.disk.state = 'error'; d.disk.rows = []; });
T('ntf-0', 'Notifications: 0', d => { d.ntf.items = []; });
T('ntf-3', 'Notifications: 3');
T('ntf-128', 'Notifications: 128 (99+)', d => moreNotes(d, 128));
T('ntf-urgent', 'Notifications: an urgent item', d => { d.ntf.items[0].urgency = 2; });
T('ntf-offline', 'Notifications: notifyd unreachable', d => { d.ntf.conn = 'offline'; d.ntf.retryIn = 8; });
T('ntf-localonly', 'Notifications: sync server unreachable', d => { d.ntf.status = { server: 'unreachable', outbox: 2, last_error: 'connect ECONNREFUSED 100.64.0.7:8443' }; });
T('ntf-syncerror', 'Notifications: sync server refused one', d => { d.ntf.status = { server: 'connected', outbox: 0, last_error: '413 payload too large' }; });
T('ntf-connecting', 'Notifications: connecting to notifyd', d => { d.ntf.conn = 'connecting'; });
T('bat-charging', 'Battery: on AC, charging', d => { d.bat.onBattery = false; d.bat.charging = true; d.bat.pct = 64; });
T('bat-full', 'Battery: on AC, full', d => { d.bat.onBattery = false; d.bat.full = true; d.bat.pct = 100; });
T('bat-battery', 'Battery: on battery, 87%');
T('bat-low', 'Battery: low, 18% (≤ 20 warning)', d => { d.bat.pct = 18; });
T('bat-critical', 'Battery: critical, 6% (≤ 10 danger)', d => { d.bat.pct = 6; });
const B = (id, label, set) => T(id, label, set, { tip: 'builder' });
B('builder-home', 'Builds on (home, mains, by default)');
B('builder-building', 'Building 2 (accepting, 2 running)', d => { d.builder.sample = bv({ running: 2 }); });
B('builder-away', 'Builds off: away', d => { d.builder.sample = bv({ accepting: false, reason: 'away', location: 'away' }); });
B('builder-battery', 'Builds off: battery', d => { d.builder.sample = bv({ accepting: false, reason: 'battery', power: 'battery' }); });
B('builder-offline', 'Builds off: offline', d => { d.builder.sample = bv({ accepting: false, reason: 'no-network', location: 'unknown' }); });
B('builder-choice-on', 'On by you (latched)', d => { d.builder.sample = bv({ reason: 'choice-on', location: 'away', choice: 'on' }); });
B('builder-choice-off', 'Off by you (latched)', d => { d.builder.sample = bv({ accepting: false, reason: 'choice-off', choice: 'off' }); });
B('builder-finishing', 'Finishing 2 (refusing, 2 still running)', d => { d.builder.sample = bv({ accepting: false, reason: 'battery', power: 'battery', running: 2 }); });
B('builder-pending', 'Turning off... (a command runs)', d => { d.builder.pending = 'off'; });
B('builder-failed', 'Off failed (action error, 30 s)', d => { d.builder.actionError = { command: 'off', detail: 'exit 1' }; });
B('builder-error', 'Status unknown (CLI failed)', d => { d.builder.sample = { kind: 'error', detail: 'status was not JSON' }; });
B('builder-loading', 'Loading: hidden in code (enabled needs ready or error)', d => { d.builder.sample = { kind: 'loading' }; });

// 4. Every tray window open
const M = (g, id, label, open, set, p) => st(g, id, label, set, Object.assign({ open }, p || {}));
M('4a', 'm-bt', 'Bluetooth: normal', 'bt');
M('4a', 'm-bt-scanning', 'Bluetooth: scanning, no devices yet', 'bt', d => { d.bt.devices = []; d.bt.discovering = true; });
M('4a', 'm-bt-empty', 'Bluetooth: no devices', 'bt', d => { d.bt.devices = []; });
M('4a', 'm-bt-off', 'Bluetooth: off', 'bt', d => { d.bt.enabled = false; d.bt.devices = []; });
M('4a', 'm-bt-crowded', 'Bluetooth: 14 devices, scrolls', 'bt', d => { d.bt.discovering = true; d.bt.devices = BT_NAMES.map((n, i) => ({ name: n, address: `C0:${(16 + i).toString(16).toUpperCase()}:4E:9A:${(32 + i * 3).toString(16).toUpperCase()}:7F`, connected: i < 2, paired: i < 6, battery: i < 2 ? 70 - i * 20 : undefined, pairing: i === 7, pairFailed: i === 8 })); });
M('4a', 'm-bt-blocked', 'Bluetooth: blocked by radio switch', 'bt', d => { d.bt.astate = 'blocked'; d.bt.enabled = false; d.bt.devices = []; });
M('4a', 'm-bt-noadapter', 'Bluetooth: no adapter (only by SUPER+O B)', 'bt', d => { d.bt.adapter = false; d.bt.devices = []; });
M('4a', 'm-wifi', 'Wi-Fi: normal', 'wifi');
M('4a', 'm-wifi-empty', 'Wi-Fi: no networks', 'wifi', d => { d.wifi.networks = []; });
M('4a', 'm-wifi-crowded', 'Wi-Fi: 20 networks, scrolls', 'wifi', d => { d.wifi.scanning = true; d.wifi.networks = SSIDS.map((n, i) => ({ name: n, signal: Math.max(0.05, 0.9 - i * 0.04), connected: i === 0, known: i < 3, security: i === 2 || i === 7 ? 'open' : i === 3 ? 'enterprise' : 'secured', state: i === 5 ? 'connecting' : '' })); });
M('4a', 'm-wifi-off', 'Wi-Fi: off', 'wifi', d => { d.wifi.enabled = false; d.wifi.networks = []; });
M('4a', 'm-wifi-blocked', 'Wi-Fi: radio switch', 'wifi', d => { d.wifi.hw = false; d.wifi.enabled = false; d.wifi.networks = []; });
M('4a', 'm-wifi-failed', 'Wi-Fi: connection failed', 'wifi', d => { d.wifi.networks[0].connected = false; d.wifi.failure = 'Authentication timed out.'; });
M('4a', 'm-wifi-password', 'Wi-Fi: password prompt', 'wifi', d => { d.wifi.networks[0].connected = false; d.wifi.password = 'NETGEAR42'; d.wifi.networks.splice(1, 0, { name: 'NETGEAR42', signal: 0.44, security: 'secured' }); }, { cursor: 1 });
M('4b', 'm-sound', 'Sound: outputs', 'vol');
M('4b', 'm-sound-inputs', 'Sound: inputs', 'vol', null, { section: 'inputs' });
M('4b', 'm-sound-empty', 'Sound: no inputs', 'vol', d => { d.sound.inputs = []; }, { section: 'inputs' });
M('4b', 'm-sound-crowded', 'Sound: 14 outputs, long name, scrolls', 'vol', d => { d.sound.outputs = [
  { name: 'Alder Lake PCH-P High Definition Audio Controller Speaker + Headphones', vol: 0.42, def: true }, { name: 'Galaxy Buds2 Pro', vol: 0.6 },
  { name: 'U2723QE (HDMI 1)', vol: 0.35, muted: true }, { name: 'U2723QE (HDMI 2)', vol: 0.35 }, { name: 'Dummy Output', vol: 0 },
  { name: 'Jabra Speak 510 Mono', vol: 0.5 }, { name: 'USB Audio CODEC Analog Stereo', vol: 0.7 }, { name: 'Easy Effects Sink', vol: 1 }, { name: 'EM160TP-A (DisplayPort 2)', vol: 0.3 },
  { name: 'Galaxy Buds2 Pro (HFP)', vol: 0.5 }, { name: 'Pixel 9 (A2DP)', vol: 0.66 }, { name: 'Loopback Analog Stereo', vol: 1 }, { name: 'Null Output', vol: 0 }, { name: 'Sony WH-1000XM5', vol: 0.45 }]; });
M('4b', 'm-sound-muted', 'Sound: default output muted', 'vol', d => setVol(d, 0.42, true));
M('4b', 'm-sound-100', 'Sound: volume 100', 'vol', d => setVol(d, 1));
M('4b', 'm-sound-nopw', 'Sound: PipeWire not running (only by SUPER+O S)', 'vol', d => { d.sound.ready = false; d.sound.outputs = []; d.sound.inputs = []; });
M('4b', 'm-bri', 'Brightness: one screen', 'bri');
M('4b', 'm-bri-two', 'Brightness: external screen keeps its own', 'bri', d => { d.bri.rows.push({ label: 'EM160TP-A', detail: 'DP-2', follows: false }); });
M('4b', 'm-bri-remote', 'Brightness: monitor not showing this computer', 'bri', d => { d.bri.rows.push({ label: 'U2723QE', detail: 'not showing this computer', follows: true }); });
M('4b', 'm-bri-unavailable', 'Brightness: unavailable (only by SUPER+O L)', 'bri', d => { d.bri.level = -1; d.bri.rows = []; });
M('4c', 'm-oci', 'OCI: ready', 'oci');
M('4c', 'm-oci-warn', 'OCI: high usage', 'oci', d => { d.oci.rows[0].percent = '86.9'; d.oci.rows[0].used = '8898.6'; d.oci.rows[0].projected = '12772'; });
M('4c', 'm-oci-loading', 'OCI: loading', 'oci', d => { d.oci.state = 'loading'; d.oci.rows = []; });
M('4c', 'm-oci-unavailable', 'OCI: credentials unavailable', 'oci', d => { d.oci.state = 'unavailable'; d.oci.rows = []; });
M('4c', 'm-oci-error', 'OCI: request failed per profile', 'oci', d => { d.oci.state = 'error'; d.oci.rows.forEach(r => { r.percent = '--'; r.used = '--'; r.projected = '--'; }); });
M('4c', 'm-oci-crowded', 'OCI: 8 profiles, scrolls', 'oci', d => { d.oci.rows = ['DEFAULT', 'family', 'lab', 'osaka', 'tokyo-2', 'backup', 'ci', 'archive'].map((n, i) => ({ name: n, percent: (40 - i * 4.7).toFixed(1), used: (4096 - i * 480).toFixed(1), projected: String(5800 - i * 600) })); });
M('4c', 'm-disk', 'Storage: all ok', 'disk');
M('4c', 'm-disk-issues', 'Storage: warn and bad findings', 'disk', d => { d.disk.rows = FINDINGS.slice(0, 4).map(f => ({ host: 'simon@unzen', level: f[0], message: f[1] })); });
M('4c', 'm-disk-loading', 'Storage: first check running', 'disk', d => { d.disk.state = 'loading'; d.disk.rows = []; d.disk.checking = true; });
M('4c', 'm-disk-error', 'Storage: check did not run', 'disk', d => { d.disk.state = 'error'; d.disk.rows = []; });
M('4c', 'm-disk-error-old', 'Storage: last check failed, old rows', 'disk', d => { d.disk.state = 'error'; d.disk.rows = FINDINGS.slice(0, 2).map(f => ({ host: 'simon@unzen', level: f[0], message: f[1] })); });
M('4c', 'm-disk-stale', 'Storage: stale result', 'disk', d => { d.disk.state = 'stale'; d.disk.checkedAt = '2026-10-22 15:20'; });
M('4c', 'm-disk-crowded', 'Storage: 30 findings on 2 hosts, scrolls', 'disk', d => { d.disk.rows = FINDINGS.concat(FINDINGS).map((f, i) => ({ host: i < 15 ? 'simon@unzen' : 'simon@zao', level: f[0], message: f[1] })); });
M('4d', 'm-ntf', 'Notifications: 3 items', 'ntf');
M('4d', 'm-ntf-kinds', 'Notifications: urgent, local only, app closed, image', 'ntf', d => {
  d.ntf.items[0].urgency = 2; d.ntf.items[0].summary = 'Battery critically low'; d.ntf.items[0].app_name = 'upower'; d.ntf.items[0].body = 'Myoko will suspend at 3%.'; d.ntf.items[0].origin = 'local'; d.ntf.items[0].host = '';
  d.ntf.items[1].local_only = true; d.ntf.items[1].host = 'myoko'; d.ntf.items[2].sender_alive = false; d.ntf.items[2].image = true; });
M('4d', 'm-ntf-empty', 'Notifications: empty', 'ntf', d => { d.ntf.items = []; });
M('4d', 'm-ntf-crowded', 'Notifications: 128 items, scrolls', 'ntf', d => moreNotes(d, 128));
M('4d', 'm-ntf-offline', 'Notifications: notifyd offline', 'ntf', d => { d.ntf.conn = 'offline'; d.ntf.retryIn = 8; });
M('4d', 'm-ntf-connecting', 'Notifications: connecting', 'ntf', d => { d.ntf.conn = 'connecting'; });
M('4d', 'm-ntf-localonly', 'Notifications: local only, 2 queued', 'ntf', d => { d.ntf.status = { server: 'unreachable', outbox: 2, last_error: 'connect ECONNREFUSED 100.64.0.7:8443' }; });
M('4d', 'm-ntf-syncerror', 'Notifications: sync error', 'ntf', d => { d.ntf.status = { server: 'connected', outbox: 0, last_error: '413 payload too large' }; });
const MB = (id, label, set, p) => M('4e', id, label, 'builder', set, p);
MB('m-builder', 'Remote builds: accepting at home');
MB('m-builder-building', 'Remote builds: 2 running', d => { d.builder.sample = bv({ running: 2 }); });
MB('m-builder-battery', 'Remote builds: refusing on battery', d => { d.builder.sample = bv({ accepting: false, reason: 'battery', power: 'battery' }); });
MB('m-builder-finishing', 'Remote builds: refusing, 2 still running', d => { d.builder.sample = bv({ accepting: false, reason: 'battery', power: 'battery', running: 2 }); });
MB('m-builder-choice-off', 'Remote builds: off by you (Use default enabled)', d => { d.builder.sample = bv({ accepting: false, reason: 'choice-off', choice: 'off' }); });
MB('m-builder-choice-on', 'Remote builds: on by you, away', d => { d.builder.sample = bv({ reason: 'choice-on', location: 'away', choice: 'on' }); });
MB('m-builder-pending', 'Remote builds: Turning off... (every action waits)', d => { d.builder.pending = 'off'; });
MB('m-builder-failed', 'Remote builds: Off failed', d => { d.builder.actionError = { command: 'off', detail: 'no answer within 20 s' }; });
MB('m-builder-error', 'Remote builds: status unknown', d => { d.builder.sample = { kind: 'error', detail: 'status was not JSON' }; });
MB('m-builder-keyboard', 'Remote builds: opened by SUPER+O R (focus at once)', d => { d.builder.keyboard = true; });
MB('m-builder-offline', 'Remote builds: no network', d => { d.builder.sample = bv({ accepting: false, reason: 'no-network', location: 'unknown' }); });
M('4e', 'm-dict-failed', 'Dictation window: failed, Retry focused', 'dict', d => { d.dict = { state: 'failed', backend: 'groq', queue: 1, failureKind: 'backend', canRetry: true }; });
M('4e', 'm-dict-micfail', 'Dictation window: microphone failed', 'dict', d => { d.dict = { state: 'failed', backend: '', queue: 0, failureKind: 'recorder', canRetry: false }; });
M('4e', 'm-dict-queued', 'Dictation window: working, 3 takes', 'dict', d => { d.dict = { state: 'working', backend: 'zao', queue: 3 }; });
M('4e', 'm-clock', 'Date/Time window', 'clock');

// 5. Start menu
st(5, 's-top', 'Start menu', null, { open: 'start' });
st(5, 's-programs', 'Programs (by category)', null, { open: 'start:programs' });
st(5, 's-programs-internet', 'Programs › Internet', null, { open: 'start:programs:Internet' });
st(5, 's-windows', 'Windows (every window, its page)', null, { open: 'start:windows' });
st(5, 's-commands', 'Commands', null, { open: 'start:commands' });
st(5, 's-commands-scale', 'Commands › Interface scale', null, { open: 'start:commands:scale' });
st(5, 's-settings', 'Settings', null, { open: 'start:settings' });
st(5, 's-key-open', 'Keyboard: opened, nothing selected', null, { open: 'start', kc: -1 });
st(5, 's-key-down', 'Keyboard: Down ×4 selects Settings', null, { open: 'start', kc: 3 });
st(5, 's-key-right', 'Keyboard: P, then Right: Programs › first item', null, { open: 'start:programs', kc: 0 });
st(5, 's-key-deep', 'Keyboard: in Internet, S selects Signal (S again: Sunshine)', null, { open: 'start:programs:Internet', kc: 2 });
st(5, 's-long', 'Programs as the code lists them (63 apps, no categories): columns', d => { d.flatPrograms = true; }, { open: 'start:programs' });
st(5, 's-long-windows', 'Windows with 22 windows', d => { d.windows = W_HUGE.map(w => (Object.assign({}, w))); }, { open: 'start:windows' });
st(5, 's-logoff', 'Log Off: confirm (new)', null, { win: 'logoff' });

// 6. Picker
st(6, 'pk-win98-light', 'Windows 98, Windows Standard', null, { win: 'picker', pt: 'win98', ps: 'light' });
st(6, 'pk-win98-grey', 'Windows 98, Dark grey', null, { win: 'picker', pt: 'win98', ps: 'grey' });
st(6, 'pk-plat-light', 'Mac OS 8 Platinum, Light (preview)', null, { win: 'picker', pt: 'platinum', ps: 'light' });
st(6, 'pk-plat-dark', 'Mac OS 8 Platinum, Dark (preview)', null, { win: 'picker', pt: 'platinum', ps: 'dark' });
st(6, 'pk-theme-list', 'Theme list open', null, { win: 'picker', pt: 'platinum', pdrop: 'theme' });
st(6, 'pk-scheme-list', 'Scheme list open', null, { win: 'picker', pt: 'win98', ps: 'grey', pdrop: 'scheme' });
st(6, 'pk-apply', 'Changed: Apply focused', null, { win: 'picker', pt: 'platinum', ps: 'light', pf: 1 });

// 7. Width
st(7, 'w-600', '600 px', null, { w: 600 });
st(7, 'w-600-tasks', '600 px, windows » open', null, { w: 600, open: 'tasks' });
st(7, 'w-440', '440 px', null, { w: 440 });
st(7, 'w-440-tasks', '440 px, windows » open', null, { w: 440, open: 'tasks' });
st(7, 'w-400-more', '400 px: the first width with a tray », open', null, { w: 400, open: 'more' });
st(7, 'w-400-more-sub', '400 px, OCI opened from the tray »', null, { w: 400, open: 'oci', anchor: 'more' });
st(7, 'w-320', '320 px', null, { w: 320 });
st(7, 'w-320-many', '320 px, 12 windows', d => { d.windows = W_MANY.map(w => (Object.assign({}, w))); }, { w: 320, open: 'tasks' });

function stateById(id) { return STATES.find(s => s.id === id) || null; }

// The data a state shows: the base data with the state's changes applied.
function dataFor(id) {
  const st = stateById(id);
  const d = baseData();
  if (st) st.set(d);
  return d;
}
function stateIds() { return STATES.map(s => s.id); }
