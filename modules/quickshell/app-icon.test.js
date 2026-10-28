// app-icon.js: Chromium and web-app classes -> the art package's names.
//   node app-icon.test.js <shell dir> <web-apps.json> <web-app-pwas.json>
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const shell = path.resolve(process.argv[2] || __dirname);
const read = (file) => fs.readFileSync(path.join(shell, file), 'utf8');
const A = {};
vm.runInNewContext(read('app-icon.js').replace(/^\.pragma library\s*$/m, ''), A);
const webApps = JSON.parse(fs.readFileSync(process.argv[3] || path.join(shell, '../web-apps.json'), 'utf8'));
const pwas = JSON.parse(fs.readFileSync(process.argv[4] || path.join(shell, '../web-app-pwas.json'), 'utf8'));

// The browser, by either class, whatever its entry says.
for (const id of ['chromium-browser', 'chromium', 'Chromium-browser'])
    assert.equal(A.themeName(id, ''), 'chromium', id);
assert.equal(A.themeName('chromium-browser', '/nix/store/x-chromium/share/icons/hicolor/256x256/apps/chromium.png'), 'chromium');
// A declared --app web app: its entry's lettermark (in every theme and
// hicolor); without the entry, its class (the art package's alias).
assert.equal(A.themeName('chrome-www.reddit.com__-Default', 'webapp-reddit'), 'webapp-reddit');
assert.equal(A.themeName('chrome-www.reddit.com__-Default', ''), 'chrome-www.reddit.com__-Default');
// An installed PWA: Chromium's entry names its own PNG by path; the class wins.
const jellyfin = 'chrome-lneafpomhdmfgkblnkjeglpppndalpik-Default';
assert.equal(A.themeName(jellyfin, '/home/simon/.local/share/icons/hicolor/512x512/apps/' + jellyfin + '.png'), jellyfin);
assert.equal(A.themeName(jellyfin, 'file:///tmp/x.png'), jellyfin);
// Anything else keeps its entry's icon, else its id.
assert.equal(A.themeName('com.mitchellh.ghostty', 'com.mitchellh.ghostty'), 'com.mitchellh.ghostty');
assert.equal(A.themeName('signal', 'signal-desktop'), 'signal-desktop');
assert.equal(A.themeName('dev.zed.Zed', ''), 'dev.zed.Zed');
assert.equal(A.themeName('', ''), '');
assert.equal(A.special('dev.zed.Zed', 'zed'), '');
assert.equal(A.special('chrome', ''), '');
assert.equal(A.special('chrome-foo-Profile_1', ''), '', 'only the Default profile');
// Unknown sites and PWAs fall back to the browser, other apps to the diamond.
assert.equal(A.fallback('chrome-example.org__-Default'), 'chromium');
assert.equal(A.fallback('webapp-reddit'), 'chromium');
assert.equal(A.fallback(jellyfin), 'chromium');
assert.equal(A.fallback('dev.zed.Zed'), 'application-x-executable');

// Every class the art package draws a lettermark under is a web-app class.
for (const app of Object.values(webApps))
    assert.equal(A.special('chrome-' + app.host + '__-Default', ''), 'chrome-' + app.host + '__-Default', app.host);
const ids = Object.values(pwas).map((app) => app.appId);
assert.deepEqual(ids.slice().sort(), [
    'ahmfndipfijlijminhiobipfjpafbndb', 'ephhkmeofmgblgjpkjnfjjlbojfjlcah', 'gehcogodmjijngibdplkjhkdjpkccahb',
    'ghklfalheoohfhobcjmoijclhibhcehj', 'kgbpjefoeahnljaodhdhocnlefgggebf', 'lneafpomhdmfgkblnkjeglpppndalpik',
    'ompifgpmddkgmclendfeacglnodjjndh', 'pbdginngdcogphkbiafcmdmgkbfpmoah']);
for (const app of Object.values(pwas)) {
    assert.match(app.appId, /^[a-p]{32}$/, app.name);
    assert.equal(A.special('chrome-' + app.appId + '-Default', ''), 'chrome-' + app.appId + '-Default', app.name);
}

// The shared place: every app-icon lookup in both themes and both Find
// windows goes through app-icon.js; Win98's set no longer has a Chromium
// rule of its own.
for (const file of ['PlatinumAppIcon.qml', 'PlatinumDesktop.qml', 'PlatinumTopBar.qml', 'PlatinumFindMenu.qml',
    'Win98Icon.qml', 'Win98Taskbar.qml', 'Win98CoolSwitch.qml', 'Win98FindWindow.qml'])
    assert.match(read(file), /import "app-icon\.js" as AppIcon/, file);
assert.match(read('themes/win98/start-model.js'), /^\.import "\.\.\/\.\.\/app-icon\.js" as AppIcon$/m);
assert.doesNotMatch(read('themes/win98/start-model.js'), /\/chrom\//, 'no Chromium rule of its own');
for (const file of ['PlatinumAppIcon.qml', 'PlatinumTopBar.qml', 'PlatinumFindMenu.qml', 'Win98Taskbar.qml', 'Win98CoolSwitch.qml'])
    assert.doesNotMatch(read(file), /iconPath\([^)]*"application-x-executable"\)/, file + ': use AppIcon.fallback');
console.log('APP_ICON_TESTS_PASSED');
