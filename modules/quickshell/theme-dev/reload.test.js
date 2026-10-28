// The reload a deploy causes: Hjem links a new generation file by file,
// and the running Quickshell reloads on the first changed file. On Myoko
// (generation 56) that reload read the new shell.qml before the new
// ThemeSounds.qml existed and logged "ReferenceError: ThemeSounds is not
// defined". This replays it with production's own soundEffectsActive line:
//   1. a pre-sound tree (no ThemeSounds.qml) and a shell without the line;
//   2. the new shell.qml alone arrives: Quickshell reloads the half tree;
//   3. ThemeSounds.qml arrives; the shell restarts (quickshell-after-hjem).
// Any QML warning fails, at every step. Actual Quickshell and labwc,
// headless, no audio, no GPU.
//   node reload.test.js <shell dir> [desktop-theme] [notification-schema.js]
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawn, spawnSync} = require('node:child_process');
const source = path.resolve(process.argv[2] || path.join(__dirname, '..'));
const qs = process.env.QUICKSHELL, labwc = process.env.LABWC;
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'shell-reload-'));
const config = path.join(temp, 'shell'), state = path.join(temp, 'state/mountainous');
const runtime = path.join(temp, 'run'), bin = path.join(temp, 'bin');
for (const dir of [state, runtime, bin]) fs.mkdirSync(dir, {recursive: true, mode: 0o700});
const env = {...process.env, HOME: temp, XDG_RUNTIME_DIR: runtime, XDG_STATE_HOME: path.dirname(state),
    XDG_CONFIG_HOME: path.join(temp, 'xdg'), XDG_CACHE_HOME: path.join(temp, 'cache'),
    WAYLAND_DISPLAY: 'wayland-0', QT_QPA_PLATFORM: 'wayland', QT_QUICK_BACKEND: 'software',
    WLR_BACKENDS: 'headless', WLR_RENDERER: 'pixman', WLR_LIBINPUT_NO_DEVICES: '1',
    AQ_DRM_DEVICES: path.join(temp, 'missing-drm'), SEATD_SOCK: path.join(temp, 'missing-seat'),
    DBUS_SESSION_BUS_ADDRESS: 'unix:path=' + path.join(temp, 'missing-bus'),
    DBUS_SYSTEM_BUS_ADDRESS: 'unix:path=' + path.join(temp, 'missing-system-bus'),
    PATH: bin + ':' + process.env.PATH};
delete env.HYPRLAND_INSTANCE_SIGNATURE; delete env.DISPLAY;
// The warnings this replay must never print (desktop-theme-shell's rule,
// plus a failed reload, which keeps the old generation and shows a popup).
const BAD = /WARN scene|TypeError|ReferenceError|is not defined|is not a type|Failed to load configuration|QML.*(Error|Warning)/i;
let logs = '';
const children = [];
function start(command, args) {
    const child = spawn(command, args, {env, detached: true, stdio: ['ignore', 'pipe', 'pipe']});
    child.stdout.on('data', d => { logs += d; }); child.stderr.on('data', d => { logs += d; });
    children.push(child); return child;
}
async function stop(child) {
    if (!child || child.exitCode !== null || child.signalCode !== null) return;
    try { process.kill(-child.pid, 'SIGTERM'); } catch { return; }
    await Promise.race([new Promise(r => child.once('exit', r)), wait(1000)]);
    if (child.exitCode === null && child.signalCode === null) { try { process.kill(-child.pid, 'SIGKILL'); } catch {} }
}
const wait = ms => new Promise(r => setTimeout(r, ms));
async function until(predicate, label) {
    for (let i = 0; i < 200; i++) { if (predicate()) return; await wait(50); }
    throw Error('Timed out: ' + label + '\n' + logs);
}
function snapshot() {
    const r = spawnSync(qs, ['-p', config, 'ipc', 'call', 'test', 'state'], {env, encoding: 'utf8', timeout: 2000});
    try { return JSON.parse(r.stdout); } catch { return {}; }
}
// Hjem replaces a link: a new file renamed over the old path.
function replace(name, text) {
    const file = path.join(config, name);
    fs.writeFileSync(file + '.new', text);
    fs.renameSync(file + '.new', file);
}
function shell(generation, soundLine) {
    return `
import Quickshell
import Quickshell.Io
import QtQuick
ShellRoot {
    id: root
${soundLine ? '    ' + soundLine : ''}
    IpcHandler {
        target: "test"
        function state(): string {
            return JSON.stringify({generation: "${generation}", theme: Theme.name,
                owner: ${soundLine ? 'typeof ThemeSounds !== "undefined"' : 'false'},
                sounds: ${soundLine ? 'root.soundEffectsActive' : 'false'}});
        }
    }
}`;
}
(async () => {
    try {
        // Production's line, exactly: the fix is tested where it lives.
        const production = fs.readFileSync(path.join(source, 'shell.qml'), 'utf8');
        const line = (/^\s*(readonly property bool soundEffectsActive:.*)$/m.exec(production) || [])[1];
        assert.ok(line, 'shell.qml must keep its soundEffectsActive line');
        fs.cpSync(source, config, {recursive: true});
        spawnSync('chmod', ['-R', 'u+w', config]);
        if (process.argv[4]) fs.copyFileSync(process.argv[4], path.join(config, 'notification-schema.js'));
        if (process.argv[3]) fs.symlinkSync(process.argv[3], path.join(bin, 'desktop-theme'));
        fs.writeFileSync(path.join(state, 'theme-name'), 'win98\n');
        fs.writeFileSync(path.join(state, 'theme-sounds'), 'off\n');
        // 1. The previous generation: no sound owner yet.
        const owner = fs.readFileSync(path.join(config, 'ThemeSounds.qml'), 'utf8');
        fs.unlinkSync(path.join(config, 'ThemeSounds.qml'));
        replace('shell.qml', shell('old', ''));
        start(labwc, ['-C', temp]);
        await until(() => fs.existsSync(path.join(runtime, 'wayland-0')), 'Wayland socket');
        let qsProcess = start(qs, ['-p', config]);
        await until(() => snapshot().generation === 'old', 'previous generation');
        // 2. The new shell.qml lands first; ThemeSounds.qml is not linked yet.
        // Quickshell notices a replaced file on the next change of its
        // directory; Hjem's next links are that change. An unchanged file
        // relinked stands in for them (its own content check ignores it).
        const before = (logs.match(/Configuration Loaded/g) || []).length;
        replace('shell.qml', shell('new', line));
        const unchanged = fs.readFileSync(path.join(config, 'SoundEvents.qml'), 'utf8');
        for (let i = 0; i < 20 && snapshot().generation !== 'new'; i++) {
            replace('SoundEvents.qml', unchanged);
            await wait(250);
        }
        await until(() => snapshot().generation === 'new', 'reload of the half-linked tree');
        assert.ok((logs.match(/Configuration Loaded/g) || []).length > before, 'Quickshell must have reloaded');
        assert.match(logs, /Reloading configuration/);
        assert.equal(snapshot().owner, false, 'the replay must reload without ThemeSounds.qml');
        assert.equal(snapshot().sounds, false);
        assert.ok(!BAD.test(logs), 'half-linked reload:\n' + logs);
        // 3. The rest of the generation lands, then the Hjem hook restarts.
        replace('ThemeSounds.qml', owner);
        await wait(300);
        await stop(qsProcess);
        qsProcess = start(qs, ['-p', config]);
        await until(() => snapshot().owner === true, 'restart on the complete tree');
        assert.equal(snapshot().theme, 'win98');
        assert.equal(snapshot().sounds, false, 'sounds off opens no bank');
        await wait(300);
        assert.ok(!BAD.test(logs), 'complete tree:\n' + logs);
        console.log('SHELL_RELOAD_TESTS_PASSED: half-linked reload without ThemeSounds, then restart; no QML warnings');
    } finally {
        for (const child of children.reverse()) await stop(child);
        fs.writeFileSync(path.join(temp, 'test.log'), logs);
        if (process.env.KEEP_THEME_TEST) console.log('Evidence: ' + temp);
        else fs.rmSync(temp, {recursive: true, force: true});
    }
})().catch(error => { console.error(error); process.exitCode = 1; });
