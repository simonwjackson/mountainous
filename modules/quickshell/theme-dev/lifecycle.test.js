// Actual Quickshell, a private Wayland compositor, real files and subprocesses.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawn, spawnSync} = require('node:child_process');
const source = path.resolve(process.argv[2] || path.join(__dirname, '..'));
const desktopTheme = process.argv[3];
const qs = process.env.QUICKSHELL;
const labwc = process.env.LABWC;
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'desktop-theme-lifecycle-'));
const config = path.join(temp, 'xdg/quickshell/mountainous');
const state = path.join(temp, 'state/mountainous');
const bin = path.join(temp, 'bin');
const runtime = path.join(temp, 'run');
for (const dir of [config,state,bin,runtime]) fs.mkdirSync(dir, {recursive:true,mode:0o700});
const env = {...process.env, HOME:temp, XDG_RUNTIME_DIR:runtime, XDG_STATE_HOME:path.dirname(state),
    XDG_CONFIG_HOME:path.join(temp,"xdg"), WAYLAND_DISPLAY:'wayland-0', QT_QPA_PLATFORM:'wayland',
    WLR_BACKENDS:'headless', WLR_RENDERER:'pixman', WLR_LIBINPUT_NO_DEVICES:'1',
    PATH:bin + ':' + process.env.PATH, QT_QUICK_BACKEND:'software'};
delete env.HYPRLAND_INSTANCE_SIGNATURE;
let logs = '', compositor, shell;
function start(command,args) {
    const child = spawn(command,args,{env,detached:true,stdio:['ignore','pipe','pipe']});
    child.stdout.on('data', d=>{logs+=d;});child.stderr.on('data',d=>{logs+=d;});return child;
}
const wait = ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(predicate,label) {
    for (let i=0;i<300;i++) {if(predicate())return;await wait(50);}
    throw Error('Timed out: '+label+'\n'+logs);
}
function snapshot() {
    const r=spawnSync(qs,['-p',config,'ipc','call','test','snapshot'],{env,encoding:'utf8',timeout:2000});
    try{return JSON.parse(r.stdout);}catch{return {};}
}
function write(name) {
    fs.writeFileSync(path.join(state,'theme-name.new'),name+'\n');
    fs.renameSync(path.join(state,'theme-name.new'),path.join(state,'theme-name'));
}
async function stop(child) {
    if(!child || child.exitCode!==null)return;
    try{process.kill(-child.pid,'SIGTERM');}catch{return;}
    await Promise.race([new Promise(r=>child.once('exit',r)),wait(1000)]);
    if(child.exitCode===null && child.signalCode===null)process.kill(-child.pid,'SIGKILL');
}
(async()=>{
    try {
        fs.cpSync(source, config, {recursive:true});
        // Nix store inputs are read-only. The isolated checkout adds only
        // fixture registry entries and its test entry point.
        function writable(dir) {
            fs.chmodSync(dir, fs.statSync(dir).mode | 0o200);
            for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
                const file = path.join(dir, entry.name);
                if (entry.isDirectory()) writable(file);
                else fs.chmodSync(file, fs.statSync(file).mode | 0o200);
            }
        }
        writable(config);
        fs.copyFileSync(process.argv[4], path.join(config, "notification-schema.js"));
        fs.cpSync(path.join(source,'theme-dev/fixtures'),path.join(config,'fixtures'),{recursive:true});
        writable(path.join(config,'fixtures'));
        // Preserve the production registry entry, view and thumbnails. Only
        // the test checkout knows the alternate and broken fixture IDs.
        var themes = JSON.parse(fs.readFileSync(path.join(config, 'themes.json'), 'utf8'));
        themes.push({id:'alternate',desktop:'fixtures/Desktop.qml',appearances:[],options:{extraDark:false},pyxampFace:'platinum'},
            {id:'broken',desktop:'fixtures/Broken.qml',appearances:[],options:{extraDark:false},pyxampFace:'platinum'});
        fs.writeFileSync(path.join(config,'themes.json'),JSON.stringify(themes));
        fs.writeFileSync(path.join(config, 'fixtures/Context.qml'),
            fs.readFileSync(path.join(source, 'theme-dev/fixtures/Context.qml'), 'utf8').replace('"../../panels"', '"../panels"'));
        fs.symlinkSync(desktopTheme,path.join(bin,'desktop-theme'));
        fs.writeFileSync(path.join(bin,'notify-send'),'#!/bin/sh\nprintf "%s\\n" "$@" >> "'+temp+'/notification"\n',{mode:0o755});
        fs.writeFileSync(path.join(config,'shell.qml'),`
import Quickshell
import Quickshell.Io
import QtQuick
import "fixtures"
ShellRoot {
    id: root
    property int failures: 0
    property var original: null
    Context { id: fixtureContext }
    ThemeDesktop {
        id: loader
        screen: Quickshell.screens[0]
        context: fixtureContext
        onFailed: function(name, error) { root.failures++; console.log("theme load rejected", name, error); }
        onDesktopChanged: if (!root.original) root.original = desktop
    }
    IpcHandler {
        target: "themePicker"
        function open(): void { ThemePicker.open(Quickshell.screens[0]); }
    }
    IpcHandler {
        target: "test"
        function validateRegistry(encoded: string): string {
            try { ThemeCatalog.parseRegistry(Qt.atob(encoded)); return "accepted"; }
            catch (error) { return "rejected: " + error + " / " + error.stack; }
        }
        function snapshot(): string { return JSON.stringify({
            theme: Theme.name, current: loader.currentName, ready: !!loader.desktop,
            active: loader.desktop ? loader.desktop.active : false,
            same: loader.desktop === root.original, failures: root.failures,
            slots: loader.loadedCount, menu: MenuState.current,
            picker: ThemePicker.visible, choices: ThemePicker.choices.length
        }); }
    }
}`);
        fs.mkdirSync(path.join(env.XDG_CONFIG_HOME, 'quickshell'), {recursive:true});
        write('platinum');
        compositor=start(labwc,[]);
        await until(()=>fs.existsSync(path.join(runtime,'wayland-0')),'Wayland socket');
        shell=start(qs,['-p',config]);
        await until(()=>snapshot().active,'initial Desktop');
        for (const entry of themes) {
            for (const face of [undefined, "unknown", "", 1, "platinum", "winamp"]) {
                const value = {...entry, pyxampFace:face};
                const result = spawnSync(qs, ['-p',config,'ipc','call','test','validateRegistry',Buffer.from(JSON.stringify([value])).toString('base64')],
                    {env,encoding:'utf8',timeout:2000});
                assert.equal(result.status, 0, result.stderr);
                if (["platinum","winamp"].includes(face))
                    assert.equal(result.stdout.trim(), "accepted", JSON.stringify(value) + " / " + result.stdout);
                else
                    assert.match(result.stdout.trim(), /^rejected: .*pyxampFace/, JSON.stringify(value) + " / " + result.stdout);
            }
        }
        console.log('THEME_CATALOG_TESTS_PASSED: missing/invalid faces rejected; both supported faces accepted');
        assert.equal(snapshot().same,true);
        const picker = spawnSync(desktopTheme, ['picker'], {env, encoding:'utf8', timeout:3000});
        assert.equal(picker.status, 0, picker.stderr + picker.stdout);
        await until(()=>snapshot().picker, 'CLI picker');
        // Every installed appearance of every theme (Platinum's two, Win98's two).
        assert.equal(snapshot().choices, themes.reduce((n, t) => n + t.appearances.length, 0));
        assert.ok(snapshot().choices >= 4);
        await wait(150);
        write('broken');
        await until(()=>snapshot().failures===1 && snapshot().theme==='platinum','rollback');
        assert.equal(snapshot().same,true,'failed switch must retain the same Desktop object');
        assert.equal(fs.readFileSync(path.join(state,'theme-name'),'utf8').trim(),'platinum');
        await until(()=>fs.existsSync(path.join(temp,'notification')),'notification');
        assert.match(fs.readFileSync(path.join(temp,'notification'),'utf8'),/broken.*ThisThemeIsDeliberatelyBroken/s);
        for(let i=0;i<10;i++) {
            for(const name of ['alternate','platinum']) {
                write(name);await until(()=>snapshot().current===name && snapshot().active,'switch '+name);
                assert.equal(snapshot().failures,1);
                assert.equal(snapshot().slots,1);
            }
        }
        write('unknown');await until(()=>snapshot().theme==='platinum','unknown theme fallback');
        fs.unlinkSync(path.join(state,'theme-name'));await wait(100);
        assert.equal(snapshot().theme,'platinum');
        if (/WARN scene|TypeError|ReferenceError|Failed to load configuration|QML.*(Error|Warning)/i.test(logs))throw Error(logs);
        console.log('THEME_LIFECYCLE_TESTS_PASSED: rollback, notification, 20 swaps, missing/unknown state');
    } finally {
        await stop(shell);await stop(compositor);
        fs.writeFileSync(path.join(temp,'test.log'),logs);
        if(process.env.KEEP_THEME_TEST)console.log('Evidence: '+temp);else fs.rmSync(temp,{recursive:true,force:true});
    }
})().catch(error=>{console.error(error);process.exitCode=1;});
