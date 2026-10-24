// Real Quickshell, FileView persistence and a broken optional QML feature.
// The sandbox has no user manager: systemd-run's executable boundary records
// argv here. The transient-unit survival proof runs separately with systemd.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawn, spawnSync} = require('node:child_process');
const source = process.argv[2] || __dirname;
const qs = process.env.QUICKSHELL || 'qs';
const labwc = process.env.LABWC || 'labwc';
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'desktop-safety-'));
const shellPath = path.join(work, 'shell');
const state = path.join(work, 'state/mountainous/recent-apps.json');
for (const dir of ['r', 'shell', 'bin']) fs.mkdirSync(path.join(work, dir), {mode:0o700});
const args = ['app name','','a b','$HOME','${USER}','$(touch unsafe)',"a'b",'a\\b','a\nb','--flag'];
let log = '', compositor, shell;
const env = {...process.env, XDG_RUNTIME_DIR:path.join(work,'r'), XDG_STATE_HOME:path.join(work,'state'),
    XDG_CONFIG_HOME:path.join(work,'config'), WAYLAND_DISPLAY:'wayland-0', QT_QPA_PLATFORM:'wayland',
    QT_QUICK_BACKEND:'software', WLR_BACKENDS:'headless', WLR_RENDERER:'pixman', WLR_LIBINPUT_NO_DEVICES:'1',
    WATCHDOG_USEC:'20000000', SAFETY_PINGS:path.join(work,'pings'), PATH:path.join(work,'bin') + ':' + process.env.PATH};
delete env.HYPRLAND_INSTANCE_SIGNATURE;
delete env.DISPLAY;
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
function start(command,args) {
    const child = spawn(command,args,{env,detached:true,stdio:['ignore','pipe','pipe']});
    for (const stream of [child.stdout,child.stderr]) stream.on('data', chunk => { log += chunk; });
    child.on('error',error => { log += error.stack; });
    return child;
}
async function stop(child) {
    if (!child || child.exitCode !== null || child.signalCode !== null) return;
    try { process.kill(-child.pid,'SIGTERM'); } catch (_) { return; }
    await Promise.race([new Promise(resolve => child.once('exit',resolve)),wait(1000)]);
    if (child.exitCode === null && child.signalCode === null) {
        try { process.kill(-child.pid,'SIGKILL'); } catch (_) {}
    }
}
function ipc(method,...args) {
    const result = spawnSync(qs,['-p',shellPath,'ipc','call','safety',method,...args],{env,encoding:'utf8',timeout:3000});
    log += 'IPC ' + method + ' status=' + result.status + ': ' + result.stderr + result.stdout + '\n';
    return result.status === 0 ? result.stdout.trim() : '';
}
async function until(check,message) {
    for (let i = 0; i < 150; ++i) { const value = check(); if (value) return value; await wait(40); }
    throw new Error(message + '\n' + log);
}
function command(name,body) {
    fs.writeFileSync(path.join(work,'bin',name),'#!' + process.execPath + '\n' + body,{mode:0o755});
}
async function run() {
    try {
        for (const name of ['Launcher.qml','launcher-model.js','Heartbeat.qml','OptionalWebTheme.qml']) fs.copyFileSync(path.join(source,name),path.join(shellPath,name));
        fs.writeFileSync(path.join(shellPath,'WebTheme.qml'),'import Missing.Optional.Service\nNotAType {}\n');
        command('systemd-run',`require('node:fs').writeFileSync(${JSON.stringify(path.join(work,'argv'))},JSON.stringify(process.argv.slice(2)));`);
        fs.writeFileSync(path.join(work,'bin/systemd-notify'),'#!' + (process.env.SHELL || '/bin/sh') + `
printf '%s\n' "$*" >> "$SAFETY_PINGS"
`,{mode:0o755});
        fs.writeFileSync(path.join(shellPath,'shell.qml'),`
import Quickshell
import Quickshell.Io
ShellRoot {
    Heartbeat { id: heartbeat }
    OptionalWebTheme {}
    IpcHandler {
        target: "safety"
        function recent(): string { return JSON.stringify(Launcher.recent); }
        function fire(): void { Launcher.launch(${JSON.stringify(args)}, {id:"fixture", name:"Fixture", icon:"fixture", kind:"app"}); }
        function repair(): void { Launcher.launch(["repaired"], {id:"fixture", name:"Fixture", icon:"fixture", kind:"app"}); }
        function append(): void { Launcher.launch(["new"], {id:"fixture", name:"Fixture", icon:"fixture", kind:"app"}); }
        function entry(): void { Launcher.launchEntry({id:"entry", name:"Entry", icon:"entry", command:["app", "literal $HOME"], runInTerminal:true, workingDirectory:"/a b"}); }
    }
}
`);
        compositor = start(labwc,[]);
        await until(() => fs.existsSync(path.join(work,'r/wayland-0')),'headless compositor failed');
        const boot = async () => {
            shell = start(qs,['-p',shellPath]);
            await until(() => ipc('recent') !== '', 'shell failed to start');
        };
        await boot();
        assert.equal(ipc('recent'),'[]','missing history must be empty');
        await until(() => fs.existsSync(path.join(work,'pings')), 'heartbeat did not start');
        const initialPings = fs.readFileSync(path.join(work,'pings'),'utf8').trim().split('\n').length;
        await until(() => fs.readFileSync(path.join(work,'pings'),'utf8').trim().split('\n').length >= initialPings + 4, 'broken feature stopped heartbeat');
        assert(log.includes('optional service failed to load'),'Loader error was not reported');
        assert(!log.includes('ReferenceError'),'optional failure escaped Loader');
        ipc('fire');
        log += 'History after fire: ' + ipc('recent') + '\n';
        await until(() => fs.existsSync(path.join(work,'argv')),'launcher did not invoke systemd-run');
        const recorded = JSON.parse(fs.readFileSync(path.join(work,'argv'),'utf8'));
        assert.deepEqual(recorded.slice(-args.length),args);
        assert(recorded.includes('--expand-environment=no'));
        await until(() => fs.existsSync(state),'history did not persist');
        console.log('PASS: argv delivered unchanged and missing history persisted');
        assert.deepEqual(JSON.parse(fs.readFileSync(state,'utf8'))[0].argv,args);
        await stop(shell);
        await boot();
        assert.equal(JSON.parse(ipc('recent'))[0].id,'fixture','history did not survive restart');
        console.log('PASS: recent history survived shell restart');
        ipc('entry');
        await until(() => JSON.parse(ipc('recent') || '[]')[0]?.id === 'entry','DesktopEntry did not launch');
        assert.deepEqual(JSON.parse(ipc('recent'))[0].argv,['ghostty','-e','env','--chdir=/a b','app','literal $HOME']);
        await stop(shell);
        fs.writeFileSync(state,'{corrupt');
        await boot();
        assert.equal(ipc('recent'),'[]','corrupt history must be empty');
        ipc('repair');
        await until(() => { try { return JSON.parse(fs.readFileSync(state,'utf8'))[0].argv[0] === 'repaired'; } catch (_) { return false; } },'corrupt history was not repaired');
        console.log('PASS: corrupt history repaired on disk');
        await stop(shell);
        const full = Array.from({length:15},(_,i) => ({id:String(i), name:'App '+i, icon:'app', kind:'app', argv:['app',String(i)], lastLaunched:i+1}));
        fs.writeFileSync(state,JSON.stringify(full));
        await boot();
        assert.equal(JSON.parse(ipc('recent')).length,10);
        assert.equal(JSON.parse(ipc('recent'))[0].id,'14');
        ipc('append');
        await until(() => { try { return JSON.parse(fs.readFileSync(state,'utf8'))[0].id === 'fixture'; } catch (_) { return false; } },'full history did not update');
        assert.equal(JSON.parse(fs.readFileSync(state,'utf8')).length,10);
        assert(!fs.readdirSync(path.dirname(state)).some(name => name !== 'recent-apps.json'),'atomic write left temporary files');
        console.log('Real QML argv, missing/corrupt/full history, restart persistence and broken-WebTheme heartbeat passed');
    } finally {
        await stop(shell);
        await stop(compositor);
        if (fs.existsSync(path.join(work,'pings'))) log += '\nHeartbeat evidence:\n' + fs.readFileSync(path.join(work,'pings'),'utf8');
        if (process.env.SAFETY_LOG) fs.writeFileSync(process.env.SAFETY_LOG,log);
        fs.rmSync(work,{recursive:true,force:true});
    }
}
run().catch(error => { console.error(error.stack); process.exitCode = 1; });
