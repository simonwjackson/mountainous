// Exercise QtMultimedia PCM decoding/playback only against a private null sink.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawn} = require('node:child_process');
const source = process.argv[2];
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sound-bank-'));
const socket = path.join(dir, 'native');
const env = {...process.env, HOME: dir, XDG_RUNTIME_DIR: dir, PULSE_SERVER: 'unix:' + socket,
    QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software', QT_LOGGING_RULES: 'qml.debug=true;qml.info=true'};
let children = [], logs = '', samples = 0, lastNonzero = 0, onsets = [], requests = [];
const wait = ms => new Promise(r => setTimeout(r, ms));
function start(command, args) {
    const child = spawn(command, args, {env, detached: true, stdio: ['ignore', 'pipe', 'pipe']});
    children.push(child); child.stderr.on('data', data => logs += data);
    return child;
}
async function until(fn, label) { for (let i=0;i<400;i++) { if(fn()) return; await wait(10); } throw Error(label + '\n' + logs); }
(async () => {
    try {
        assert.ok(!fs.existsSync("/dev/snd"), "no real audio device in the Nix sandbox");
        for (const file of ['ThemeSoundBank.qml', 'ThemeSoundSink.qml']) fs.copyFileSync(path.join(source,file),path.join(dir,file));
        fs.writeFileSync(path.join(dir,'pulse.conf'), `load-module module-native-protocol-unix socket=${socket} auth-anonymous=1\nload-module module-null-sink sink_name=ui rate=48000 channels=1\nset-default-sink ui\n`);
        start('pulseaudio', ['--daemonize=no','--exit-idle-time=-1','-nF',path.join(dir,'pulse.conf')]);
        await until(() => fs.existsSync(socket), 'private PulseAudio');
        const monitor = start('parec', ['--device=ui.monitor','--raw','--format=s16le','--rate=48000','--channels=1','--latency-msec=1','--process-time-msec=1']);
        monitor.stdout.on('data', data => {
            let audible = false;
            for(let i=0;i+1<data.length;i+=2) {
                if (Math.abs(data.readInt16LE(i)) > 50) { samples++; audible = true; }
            }
            if (audible) {
                const now = Date.now();
                if (now - lastNonzero > 200) onsets.push(now);
                lastNonzero = now;
            }
        });
        const registry = JSON.parse(fs.readFileSync(path.join(source,'themes.json')));
        const sources = [...new Set(registry.flatMap(t => Object.values(t.sounds)))].map(s=>'file://'+path.join(source,s));
        fs.writeFileSync(path.join(dir,'shell.qml'), `
import Quickshell
import QtQuick
import "."
ShellRoot {
    id: root
    property int index: 0
    property var files: ${JSON.stringify(sources)}
    ThemeSoundBank { id: bank; sounds: { const map = {}; root.files.forEach(function(s,i) { map["s"+i]=s; }); return map; } }
    Timer {
        interval: 700; repeat: true; running: true
        onTriggered: {
            if (!bank.ready) return;
            if (root.index === root.files.length) { Qt.exit(37); return; }
            console.warn("REQUEST " + Date.now());
            if (!bank.play(root.files[root.index++])) Qt.exit(1);
        }
    }
    Timer { interval: 22000; running: true; onTriggered: Qt.exit(2) }
}
`);
        const qml = start(process.env.QUICKSHELL, ['-p',dir]);
        qml.stdout.on('data', data => logs += data);
        function request(data) {
            const match = String(data).match(/REQUEST (\d+)/);
            if(match) requests.push(Number(match[1]));
        }
        qml.stderr.on('data', request); qml.stdout.on('data', request);
        const code = await new Promise(resolve => qml.on('exit', resolve));
        assert.equal(code,37,logs);
        assert.ok(samples > 1000, 'null sink received decoded PCM: ' + samples + '\n' + logs);
        assert.equal(requests.length, sources.length, 'one request per asset');
        assert.equal(onsets.length, sources.length, 'one audible gesture per asset: ' + JSON.stringify({onsets,requests})+'\n'+logs);
        const latencies = onsets.map((onset,i) => onset-requests[i]);
        assert.ok(latencies.every(ms => ms >= -5 && ms < 30), 'null sink onset under 30 ms (1 ms clock precision): '+JSON.stringify(latencies));
        fs.writeFileSync(path.join(process.env.EVIDENCE_DIR,'null-sink.json'), JSON.stringify({samples,latenciesMs:latencies,maxMs:Math.max(...latencies)},null,2)+'\n');
        console.log('SOUND_BANK_PASSED null sink: '+sources.length+' assets; onset ms '+JSON.stringify(latencies));
    } finally {
        for(const child of children.reverse()) {
            try { process.kill(-child.pid,'SIGTERM'); } catch {}
            await Promise.race([new Promise(r=>child.once('exit',r)),wait(300)]);
            if(child.exitCode===null && child.signalCode===null) {try { process.kill(-child.pid,'SIGKILL'); } catch {}}
        }
        fs.writeFileSync(path.join(process.env.EVIDENCE_DIR,'null-sink.log'),logs);
        fs.rmSync(dir,{recursive:true,force:true});
    }
})().catch(error=>{console.error(error);process.exitCode=1;});
