// Real picker geometry at awkward sizes, including focus-driven scrolling.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawn, spawnSync} = require('node:child_process');
const source = path.resolve(process.argv[2] || path.join(__dirname, '..'));
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'picker-geometry-'));
const runtime = path.join(temp, 'run');
const config = path.join(temp, 'shell');
fs.mkdirSync(runtime, {mode: 0o700});
fs.cpSync(source, config, {recursive: true});
fs.chmodSync(config, 0o755);
// Only the entry point is replaced; every picker component is production QML.
fs.unlinkSync(path.join(config, 'shell.qml'));
fs.copyFileSync(path.join(source, 'theme-dev/picker-geometry.qml'), path.join(config, 'shell.qml'));
fs.copyFileSync(process.argv[3], path.join(config, 'notification-schema.js'));
const env = {...process.env, XDG_RUNTIME_DIR: runtime, XDG_STATE_HOME: path.join(temp, 'state'),
    XDG_CONFIG_HOME: path.join(temp, 'config'), WAYLAND_DISPLAY: 'wayland-0',
    QT_QPA_PLATFORM: 'wayland', QT_QUICK_BACKEND: 'software',
    WLR_BACKENDS: 'headless', WLR_RENDERER: 'pixman', WLR_LIBINPUT_NO_DEVICES: '1'};
delete env.HYPRLAND_INSTANCE_SIGNATURE;
delete env.DISPLAY;
const qs = process.env.QUICKSHELL;
let logs = '', compositor, shell;
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
function start(command, args) {
    const child = spawn(command, args, {env, detached: true, stdio: ['ignore', 'pipe', 'pipe']});
    child.on('error', error => { logs += error.stack; });
    child.stdout.on('data', data => { logs += data; });
    child.stderr.on('data', data => { logs += data; });
    return child;
}
function ipc(method, ...args) {
    const result = spawnSync(qs, ['-p', config, 'ipc', 'call', 'geometry', method, ...args.map(String)],
        {env, encoding: 'utf8', timeout: 2000});
    return result.status === 0 ? result.stdout.trim() : '';
}
function snapshot() { try { return JSON.parse(ipc('snapshot')); } catch { return {}; } }
async function until(predicate, label) {
    for (let i = 0; i < 150; i++) { if (predicate()) return; await wait(50); }
    throw Error('Timed out: ' + label + '\n' + logs);
}
const epsilon = 0.05;
function inside(item, bounds) {
    return item.x >= bounds.x - epsilon && item.y >= bounds.y - epsilon
        && item.x + item.width <= bounds.x + bounds.width + epsilon
        && item.y + item.height <= bounds.y + bounds.height + epsilon;
}
async function proveGeometry(width, height) {
    ipc('resize', width, height);
    await until(() => { const s = snapshot(); return s.width === width && s.height === height; }, 'resize');
    await wait(50);
    let s = snapshot();
    const window = {x: 0, y: 0, width, height};
    assert.ok(s.body.width > 0 && s.body.height > 0, `negative/empty viewport at ${width}x${height}: ${JSON.stringify(s.body)}`);
    assert.ok(inside(s.body, window), 'viewport must stay in the window');
    const controls = s.items.filter(item => /^pickerChoice-\d+$|^pickerOption$|^pickerSounds$|^pickerClose$/.test(item.name));
    assert.equal(controls.filter(item => /^pickerChoice-/.test(item.name)).length, s.choiceCount);
    assert.equal(controls.filter(item => item.name === 'pickerClose').length, 1, 'one reachable close control');
    assert.ok(controls.some(item => item.name === 'pickerOption'), 'extra dark must exist');
    assert.ok(controls.some(item => item.name === 'pickerSounds'), 'interface sounds must exist');
    for (const control of controls) {
        if ((!s.closeInBody || s.thumbnails) && /^pickerChoice-/.test(control.name)) {
            assert.ok(control.height <= s.body.height, 'a choice and its label must fit before pinning decoration');
        }
        if (!control.inBody) { assert.ok(inside(control, window), control.name + ' outside window'); continue; }
        assert.ok(control.contentY >= -epsilon && control.contentY + control.height <= s.body.contentHeight + epsilon,
            control.name + ' outside scrollable extent');
        assert.ok(control.x >= s.body.x - epsilon && control.x + control.width <= s.body.x + s.body.width + epsilon,
            control.name + ' clipped horizontally');
        ipc('focus', control.name);
        await wait(30);
        let current = snapshot();
        let item = current.items.find(item => item.name === control.name);
        if (control.height <= current.body.height + epsilon) {
            assert.ok(inside(item, current.body) && inside(item, window), control.name + ' not revealed by focus');
        } else {
            // At extremely narrow widths a wrapped row can exceed the viewport.
            // Prove both ends are reachable, rather than accepting a clipped label.
            ipc('scroll', control.contentY); await wait(20);
            current = snapshot(); item = current.items.find(item => item.name === control.name);
            assert.ok(item.y >= current.body.y - epsilon && item.y < current.body.y + current.body.height);
            ipc('scroll', control.contentY + control.height - current.body.height); await wait(20);
            current = snapshot(); item = current.items.find(item => item.name === control.name);
            assert.ok(item.y + item.height <= current.body.y + current.body.height + epsilon);
        }
    }
    s = snapshot();
    for (const label of s.items.filter(item => /^pickerChoiceLabel-|^pickerOptionLabel$|^pickerOptionMark$|^pickerSoundsLabel$|^pickerSoundsMark$|^pickerError$/.test(item.name))) {
        assert.ok(label.width > 0 && label.contentY >= -epsilon
            && label.contentY + label.height <= s.body.contentHeight + epsilon, 'unreachable label or option mark');
        assert.ok(label.x >= s.body.x - epsilon && label.x + label.width <= s.body.x + s.body.width + epsilon, 'clipped label');
    }
    console.log(`PICKER_GEOMETRY_PASSED ${width}x${height}`);
}
async function stop(child) {
    if (!child || child.exitCode !== null) return;
    try { process.kill(-child.pid, 'SIGTERM'); } catch { return; }
    await Promise.race([new Promise(resolve => child.once('exit', resolve)), wait(1000)]);
    if (child.exitCode === null && child.signalCode === null) process.kill(-child.pid, 'SIGKILL');
}
(async () => {
    try {
        compositor = start(process.env.LABWC, []);
        await until(() => fs.existsSync(path.join(runtime, 'wayland-0')), 'compositor');
        shell = start(qs, ['-p', config]);
        await until(() => snapshot().body, 'picker');
        for (const size of [[160,80], [1920,1200], [960,600], [240,800], [1200,180], [160,150], [80,800],
            [220,299], [220,300], [220,301], [219,400], [220,400], [221,400], [160,85], [160,86], [160,87], [160,164], [160,165], [160,166], [139,800], [140,800], [141,800], [160,40]]) {
            await proveGeometry(...size);
        }
        for (const count of [0,1,12]) { ipc('populate', count); await proveGeometry(160,80); }
        ipc('fail'); await proveGeometry(80,800);
        if (/WARN.*scene|TypeError|ReferenceError|Failed to load configuration/i.test(logs)) throw Error(logs);
    } finally {
        await stop(shell); await stop(compositor);
        if (process.env.KEEP_PICKER_TEST) {
            fs.writeFileSync(path.join(temp, 'test.log'), logs); console.log('Evidence: ' + temp);
        } else fs.rmSync(temp, {recursive: true, force: true});
    }
})().catch(error => { console.error(error); process.exitCode = 1; });
