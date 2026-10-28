// Production pickers, command, watched preference and QtMultimedia import.
// Runs only in a Nix sandbox with a software headless compositor; no audio.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const assert = require('node:assert/strict');
const {spawn, spawnSync} = require('node:child_process');
const source = process.argv[2], command = process.argv[3], evidence = process.env.EVIDENCE_DIR;
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sound-picker-'));
const runtime = path.join(dir, 'run'), config = path.join(dir, 'shell'), state = path.join(dir, 'state/mountainous');
for (const p of [runtime, state, path.join(dir, 'bin')]) fs.mkdirSync(p, {recursive: true, mode: 0o700});
fs.cpSync(source, config, {recursive: true});
fs.chmodSync(config, 0o755);
fs.copyFileSync(process.argv[4], path.join(config, "notification-schema.js"));
fs.unlinkSync(path.join(config, 'shell.qml'));
fs.writeFileSync(path.join(config, 'shell.qml'), `
import Quickshell
import Quickshell.Io
import QtQuick
ShellRoot {
    id: root
    readonly property bool audioActive: ThemeSounds.active
    function load() {
        const entry = ThemeCatalog.find(Theme.name);
        picker.setSource(Qt.resolvedUrl(entry.picker), {screen: Quickshell.screens[0], model: ThemePicker});
    }
    Loader { id: picker }
    property var trace: []
    Connections { target: SoundEvents; function onRequested(event) { root.trace = root.trace.concat([event]); } }
    PlatinumCascadeMenu { id: macMenu; visible: false; items: [{kind: "item", text: "Choose", action: {kind: "test"}}, {kind: "item", text: "Disabled", disabled: true, action: {kind: "test"}}] }
    Win98Menu { id: pcMenu; visible: false; model: [{text: "Choose"}, {text: "Disabled", enabled: false}] }
    function find(item) {
        if (!item) return null;
        if (item.objectName === "pickerSounds") return item;
        for (const child of item.children) { const found = find(child); if (found) return found; }
        return null;
    }
    Component.onCompleted: root.load()
    Connections { target: Theme; function onNameChanged() { root.load(); } }
    IpcHandler {
        target: "test"
        function state(): string { return JSON.stringify({theme: Theme.name, mode: Theme.mode, sounds: Theme.soundsEnabled, audio: root.audioActive, applying: ThemePicker.applying}); }
        function toggle(): void {
            const option = root.find(picker.item.contentItem);
            if (typeof option.toggle === "function") option.toggle(); else option.toggled();
        }
        function focus(): void { root.find(picker.item.contentItem).forceActiveFocus(); }
        function hooks(): string {
            root.trace = [];
            MenuState.open("start", Quickshell.screens[0], 0);
            MenuState.open("start", Quickshell.screens[0], 0);
            macMenu.choose(0, 1); pcMenu.trigger(1);
            macMenu.choose(0, 0); pcMenu.trigger(0);
            MenuState.close();
            return JSON.stringify(root.trace);
        }
    }
}
`);
fs.symlinkSync(command, path.join(dir, 'bin/desktop-theme'));
fs.writeFileSync(path.join(state, 'theme-sounds'), 'off\n');
fs.writeFileSync(path.join(state, 'theme-name'), 'platinum\n');
const env = {...process.env, HOME: dir, XDG_RUNTIME_DIR: runtime, XDG_CONFIG_HOME: path.join(dir, 'config'),
    XDG_STATE_HOME: path.join(dir, 'state'), WAYLAND_DISPLAY: 'wayland-0', QT_QPA_PLATFORM: 'wayland',
    QT_QUICK_BACKEND: 'software', WLR_BACKENDS: 'headless', WLR_RENDERER: 'pixman', WLR_LIBINPUT_NO_DEVICES: '1',
    AQ_DRM_DEVICES: path.join(dir, 'missing-drm'), SEATD_SOCK: path.join(dir, 'missing-seat'),
    DBUS_SESSION_BUS_ADDRESS: 'unix:path=' + path.join(dir, 'missing-bus'),
    DBUS_SYSTEM_BUS_ADDRESS: 'unix:path=' + path.join(dir, 'missing-system-bus'),
    PATH: path.join(dir, 'bin') + ':' + process.env.PATH};
delete env.DISPLAY; delete env.HYPRLAND_INSTANCE_SIGNATURE;
let logs = '', children = [];
function start(cmd, args) {
    const child = spawn(cmd, args, {env, detached: true, stdio: ['ignore', 'pipe', 'pipe']});
    child.stdout.on('data', x => logs += x); child.stderr.on('data', x => logs += x);
    children.push(child); return child;
}
function run(cmd, args) { const r = spawnSync(cmd, args, {env, encoding: 'utf8', timeout: 5000}); assert.equal(r.status, 0, r.stdout + r.stderr); return r.stdout.trim(); }
function ipc(method) { return run(process.env.QUICKSHELL, ['-p', config, 'ipc', 'call', 'test', method]); }
const wait = ms => new Promise(r => setTimeout(r, ms));
async function until(fn, label) { for (let n = 0; n < 150; n++) { try { if (fn()) return; } catch {} await wait(50); } throw Error(label + '\n' + logs); }
function write(name, value) { fs.writeFileSync(path.join(state, name + '.new'), value + '\n'); fs.renameSync(path.join(state, name + '.new'), path.join(state, name)); }
(async () => {
    try {
        assert.ok(!fs.existsSync('/dev/dri'), 'Nix test sandbox must expose no GPU');
        start(process.env.LABWC, ['-C', dir]);
        await until(() => fs.existsSync(path.join(runtime, 'wayland-0')), 'compositor');
        start(process.env.QUICKSHELL, ['-p', config]);
        await until(() => JSON.parse(ipc('state')).theme === 'platinum', 'production picker');
        assert.equal(JSON.parse(ipc('state')).audio, false, 'off startup opens no sink');
        assert.deepEqual(JSON.parse(ipc('hooks')), ['menuOpen','menuChoose','menuChoose'], 'actual menus: open once, choose once, disabled silent');
        ipc('toggle');
        await until(() => JSON.parse(ipc('state')).sounds && !JSON.parse(ipc('state')).applying, 'on persists');
        assert.equal(fs.readFileSync(path.join(state, 'theme-sounds'), 'utf8'), 'on\n');
        ipc('toggle');
        await until(() => !JSON.parse(ipc('state')).sounds && !JSON.parse(ipc('state')).applying, 'off persists');
        for (const [theme, mode, extra] of [['platinum','light','off'], ['platinum','dark','off'], ['platinum','dark','on'], ['win98','light','off'], ['win98','dark','off']]) {
            write('theme', mode); write('theme-extra', extra); write('theme-name', theme);
            await until(() => { const s = JSON.parse(ipc('state')); return s.theme === theme && s.mode === mode; }, 'appearance');
            ipc('focus'); await wait(200);
            run('grim', [path.join(evidence, `${theme}-${mode}-${extra}.png`)]);
        }
        ipc('toggle');
        await until(() => JSON.parse(ipc('state')).sounds && !JSON.parse(ipc('state')).applying, 'Win98 checkbox on');
        ipc('toggle');
        await until(() => !JSON.parse(ipc('state')).sounds && !JSON.parse(ipc('state')).applying, 'Win98 checkbox off');
        run('wlr-randr', ['--output', 'HEADLESS-1', '--custom-mode', '360x640']);
        for (const theme of ['win98', 'platinum']) {
            write('theme-name', theme);
            await until(() => JSON.parse(ipc('state')).theme === theme, 'narrow picker'); ipc('focus'); await wait(200);
            run('grim', [path.join(evidence, `${theme}-narrow.png`)]);
        }
        assert.ok(!/(TypeError|ReferenceError|is not installed|is not defined|Cannot assign|QQmlVMEMetaObject)/.test(logs), logs);
        console.log('SOUND_PICKER_PASSED: production CLI/watchers, both themes, five appearances, narrow');
    } finally {
        for (const child of children.reverse()) {
            if (child.exitCode === null && child.signalCode === null) { try { process.kill(-child.pid, 'SIGTERM'); } catch {} }
            await Promise.race([new Promise(r => child.once('exit', r)), wait(500)]);
            if (child.exitCode === null && child.signalCode === null) { try { process.kill(-child.pid, 'SIGKILL'); } catch {} }
        }
        fs.writeFileSync(path.join(evidence, 'picker.log'), logs);
        const live = children.filter(x => x.exitCode === null && x.signalCode === null);
        fs.writeFileSync(path.join(evidence, 'cleanup.txt'), 'processes left: ' + live.length + '\n/dev/dri absent\nAQ_DRM_DEVICES=' + env.AQ_DRM_DEVICES + '\nSEATD_SOCK=' + env.SEATD_SOCK + '\n');
        fs.rmSync(dir, {recursive: true, force: true});
    }
})().catch(error => { console.error(error); process.exitCode = 1; });
