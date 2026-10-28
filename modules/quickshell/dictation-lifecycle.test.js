// Real Dictation.qml, real Quickshell and a software-rendered Wayland server.
// Recorder/backend processes and the publisher are configurable; production QML is unchanged.
// A private session bus carries two real mpv MPRIS players: one playing, one
// paused, plus an MPRIS publisher with Pyxamp own/foreign metadata. A take
// holds own playback, never forwards through a mirror, and cannot resume a
// Pyxamp target that changed during capture.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {spawn, spawnSync} = require("node:child_process");

const source = process.argv[2] || path.join(__dirname, "Dictation.qml");
const theme = process.argv[3] || path.join(__dirname, "Theme.qml");
const qs = process.env.QUICKSHELL || "qs";
const labwc = process.env.LABWC || "labwc";
const dbusDaemon = process.env.DBUS_DAEMON || "dbus-daemon";
const dbusConfig = process.env.DBUS_SESSION_CONF || "/etc/dbus-1/session.conf";
const mpv = process.env.MPV || "mpv";
const python = process.env.PYTHON || "python3";
const mpvMpris = process.env.MPV_MPRIS || "";
const work = fs.mkdtempSync(path.join(os.tmpdir(), "dcl-"));
const runtime = path.join(work, "r");
const config = path.join(work, "shell");
const bin = path.join(work, "bin");
for (const dir of [runtime, config, bin]) fs.mkdirSync(dir, {mode: 0o700});
let logs = "", compositor, shell, bus;
const pyxampControl = path.join(work, "pyxamp-control");
const pyxampCalls = path.join(work, "pyxamp-calls");
const pyxampApplied = path.join(work, "pyxamp-applied");
const ownTrackId = "/org/pyxamp/track/o6162";
const pyxampName = "org.mpris.MediaPlayer2.pyxamp";
function calls() {
    return fs.existsSync(pyxampCalls) ? fs.readFileSync(pyxampCalls, "utf8").trim().split("\n").filter(Boolean) : [];
}
const players = [];
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const env = {
    ...process.env, XDG_RUNTIME_DIR: runtime, XDG_STATE_HOME: path.join(work, "state"),
    XDG_CONFIG_HOME: path.join(work, "config"), XDG_SESSION_ID: "dictation-test",
    WAYLAND_DISPLAY: "wayland-0", QT_QPA_PLATFORM: "wayland", QT_QUICK_BACKEND: "software",
    PATH: bin + path.delimiter + process.env.PATH, DICTATION_TEST_MODE_FILE: path.join(work, "mode"),
    WLR_BACKENDS: "headless", WLR_RENDERER: "pixman", WLR_LIBINPUT_NO_DEVICES: "1",
    DBUS_SESSION_BUS_ADDRESS: "unix:path=" + path.join(work, "bus"), HOME: work
};
delete env.HYPRLAND_INSTANCE_SIGNATURE;
delete env.DISPLAY;
function command(name, text) {
    fs.writeFileSync(path.join(bin, name), "#!" + process.execPath + "\n" + text, {mode: 0o755});
}
function start(executable, args) {
    const child = spawn(executable, args, {env, detached: true, stdio: ["ignore", "pipe", "pipe"]});
    child.on("error", error => { logs += error.stack + "\n"; });
    for (const stream of [child.stdout, child.stderr]) stream.on("data", chunk => { logs += chunk; });
    return child;
}
async function until(check, message) {
    const end = Date.now() + 10000;
    while (Date.now() < end) {
        const value = check();
        if (value) return value;
        await wait(30);
    }
    throw new Error(message + "\n" + logs);
}
function ipc(method) {
    const result = spawnSync(qs, ["-p", config, "ipc", "call", "lifecycle", method], {env, encoding: "utf8", timeout: 3000});
    return result.status === 0 ? result.stdout.trim() : "";
}
function snapshot() {
    try { return JSON.parse(ipc("snapshot")); } catch (_) { return null; }
}
async function stop(child) {
    if (!child || !child.pid || child.exitCode !== null) return;
    try { process.kill(-child.pid, "SIGTERM"); } catch (_) { return; }
    await Promise.race([new Promise(resolve => child.once("exit", resolve)), wait(1000)]);
    if (child.exitCode === null && child.signalCode === null) {
        try { process.kill(-child.pid, "SIGKILL"); } catch (_) { /* already stopped */ }
    }
}
async function main() {
    try {
        fs.copyFileSync(source, path.join(config, "Dictation.qml"));
        fs.copyFileSync(path.join(path.dirname(theme), "media-hold.js"), path.join(config, "media-hold.js"));
        fs.copyFileSync(theme, path.join(config, "Theme.qml"));
        for (const name of ["ThemeCatalog.qml", "themes.json"]) {
            fs.copyFileSync(path.join(path.dirname(theme), name), path.join(config, name));
        }
        fs.writeFileSync(env.DICTATION_TEST_MODE_FILE, "ok");
        // Same contract as DESIGN's recorder: SIGINT exits 1 with a whole
        // take; microphone failure exits 3 before capture can complete.
        command("pw-record", `
const fs = require("node:fs");
if (fs.readFileSync(process.env.DICTATION_TEST_MODE_FILE, "utf8").trim() === "fail") process.exit(3);
fs.writeFileSync(process.argv[process.argv.length - 1], "RIFF");
process.on("SIGINT", () => process.exit(1));
setInterval(() => {}, 100);
`);
        command("dictation-submit", 'console.log("backend groq"); setTimeout(() => process.exit(1), 30);\n');
        command("loginctl", 'console.log("no");\n');
        fs.writeFileSync(path.join(config, "shell.qml"), `
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
ShellRoot {
    Dictation { id: dictation }
    IpcHandler {
        target: "lifecycle"
        function press(): void { dictation.press(false); }
        function release(): void { dictation.release(); }
        function cancel(): void { dictation.cancel(); }
        function dismiss(): void { dictation.dismissFailure(); }
        function snapshot(): string {
            return JSON.stringify({state: dictation.state, kind: dictation.failureKind,
                canRetry: dictation.canRetry, text: dictation.statusText,
                capture: dictation.captureState, active: dictation.activeTake ? dictation.activeTake.path : "",
                failed: dictation.failedTake ? dictation.failedTake.path : "",
                held: dictation.heldPlayers.length,
                tracks: dictation.mediaPlayers().map(p => ({name: p.dbusName, trackId: p.trackId})),
                players: Mpris.players.values.map(p => p.dbusName + "=" + MprisPlaybackState.toString(p.playbackState)).sort()});
        }
    }
}
`);
        const compositorConfig = path.join(work, "config", "labwc");
        fs.mkdirSync(compositorConfig, {recursive: true});
        fs.writeFileSync(path.join(compositorConfig, "autostart"), "");
        bus = start(dbusDaemon, ["--config-file=" + dbusConfig, "--address=" + env.DBUS_SESSION_BUS_ADDRESS, "--nofork", "--nopidfile"]);
        await until(() => fs.existsSync(path.join(work, "bus")), "Session bus did not start");
        for (const pause of ["no", "yes"]) {
            players.push(start(mpv, ["--no-config", "--ao=null", "--vo=null", "--pause=" + pause,
                "--loop-file=inf", "--script=" + mpvMpris, "av://lavfi:sine=frequency=440"]));
        }
        // A real MPRIS service with configurable track/status; calls are recorded
        // even in mirror mode, so an accidental forward cannot pass unnoticed.
        const publisher = path.join(work, "mpris-publisher.py");
        fs.writeFileSync(publisher, String.raw`
import asyncio, json, sys
from dbus_fast import Variant, PropertyAccess
from dbus_fast.aio import MessageBus
from dbus_fast.service import ServiceInterface, dbus_property, method
class Root(ServiceInterface):
    def __init__(self):
        super().__init__('org.mpris.MediaPlayer2')
    @dbus_property(access=PropertyAccess.READ)
    def Identity(self) -> 's': return 'Pyxamp'
    @dbus_property(access=PropertyAccess.READ)
    def DesktopEntry(self) -> 's': return 'pyxamp'
class Player(ServiceInterface):
    def __init__(self):
        super().__init__('org.mpris.MediaPlayer2.Player')
        self.track = '${ownTrackId}'
        self.status = 'Playing'
        self.defer_pause_notification = False
        self.pause_notification_pending = False
    def notify_status(self):
        # Report current native state, not the old Pause that scheduled this.
        self.emit_properties_changed({'PlaybackStatus': self.status})
    def change(self, status):
        self.status = status
        self.emit_properties_changed({'PlaybackStatus': status})
    @method()
    def Pause(self):
        with open(sys.argv[2], 'a') as out: out.write('Pause\n')
        self.status = 'Paused'
        if self.defer_pause_notification:
            self.pause_notification_pending = True
        else:
            self.notify_status()
    @method()
    def Play(self):
        with open(sys.argv[2], 'a') as out: out.write('Play\n')
        self.change('Playing')
        if self.pause_notification_pending:
            self.pause_notification_pending = False
            asyncio.get_running_loop().call_soon(self.notify_status)
    @dbus_property(access=PropertyAccess.READ)
    def PlaybackStatus(self) -> 's': return self.status
    @dbus_property(access=PropertyAccess.READ)
    def Position(self) -> 'x': return 0
    @dbus_property(access=PropertyAccess.READ)
    def Metadata(self) -> 'a{sv}':
        return {'mpris:trackid': Variant('o', self.track),
                'xesam:title': Variant('s', 'Own song'), 'xesam:artist': Variant('as', ['Own artist'])}
    @dbus_property(access=PropertyAccess.READ)
    def CanControl(self) -> 'b': return True
    @dbus_property(access=PropertyAccess.READ)
    def CanPause(self) -> 'b': return True
    @dbus_property(access=PropertyAccess.READ)
    def CanPlay(self) -> 'b': return True
async def main():
    bus = await MessageBus().connect()
    player = Player()
    bus.export('/org/mpris/MediaPlayer2', Root())
    bus.export('/org/mpris/MediaPlayer2', player)
    await bus.request_name('${pyxampName}')
    previous = ''
    while True:
        try:
            with open(sys.argv[1]) as source: control = source.read()
        except FileNotFoundError:
            control = ''
        if control and control != previous:
            update = json.loads(control)
            player.track = update['trackId']
            player.defer_pause_notification = update['deferPauseNotification']
            player.change(update['state'])
            player.emit_properties_changed({'Metadata': player.Metadata})
            previous = control
            with open(sys.argv[3], 'w') as applied: applied.write(control)
        await asyncio.sleep(0.02)
asyncio.run(main())
`);
        players.push(start(python, [publisher, pyxampControl, pyxampCalls, pyxampApplied]));
        compositor = start(labwc, ["--config-dir", compositorConfig]);
        await until(() => fs.existsSync(path.join(runtime, "wayland-0")), "Wayland server did not start");
        shell = start(qs, ["-p", config, "--no-color"]);
        await until(() => snapshot(), "Dictation shell did not start");
        const states = s => Object.fromEntries(s.players.map(entry => entry.split("=")));
        async function changeTrack(trackId, state, deferPauseNotification = false) {
            const control = JSON.stringify({trackId, state, deferPauseNotification});
            fs.writeFileSync(pyxampControl, control);
            await until(() => {
                const s = snapshot();
                return fs.existsSync(pyxampApplied) && fs.readFileSync(pyxampApplied, "utf8") === control
                    && s && s.tracks.some(p => p.name === pyxampName && p.trackId === trackId)
                    && states(s)[pyxampName] === state;
            }, "Pyxamp metadata/configuration did not change");
        }
        const before = await until(() => {
            const s = snapshot();
            return s && s.players.length === 3 && Object.values(states(s)).sort().join() === "Paused,Playing,Playing" && s;
        }, "MPRIS players did not appear");
        const playing = Object.keys(states(before)).find(name => name !== pyxampName && states(before)[name] === "Playing");
        const paused = Object.keys(states(before)).find(name => states(before)[name] === "Paused");
        await until(() => snapshot()?.tracks.some(p => p.name === pyxampName && p.trackId === ownTrackId),
            "Quickshell did not expose the MPRIS object-path track id to QML as a string");
        ipc("press");
        await until(() => {
            const s = snapshot();
            return s && s.capture === "recording" && s.active && fs.existsSync(s.active);
        }, "Recorder did not start");
        const holding = await until(() => {
            const s = snapshot();
            return s && states(s)[playing] === "Paused" && states(s)[pyxampName] === "Paused" && s;
        }, "The playing player was not paused while recording");
        assert.equal(holding.held, 2, "playing foreign and Pyxamp own playback are held");
        assert.deepEqual(calls(), ["Pause"], "own playback is paused exactly once");
        assert.equal(states(holding)[paused], "Paused");
        await wait(325); // Production rejects takes shorter than 250 ms.
        ipc("release");
        const after = await until(() => {
            const s = snapshot();
            return s && states(s)[playing] === "Playing" && states(s)[pyxampName] === "Playing" && s;
        }, "Release did not resume the held player");
        assert.equal(after.held, 0);
        assert.deepEqual(calls(), ["Pause", "Play"], "own playback resumes exactly once");
        await wait(300);
        assert.equal(states(snapshot())[paused], "Paused", "release never plays a player the user had paused");
        const older = await until(() => {
            const s = snapshot();
            return s && s.state === "failed" && s.kind === "backend" && s;
        }, "Backend failure was not retained");
        assert.equal(older.canRetry, true);
        assert.ok(older.failed && fs.existsSync(older.failed));
        // Native Pause lands immediately; its notification waits for native Play.
        // Cancellation must send Play while Quickshell still caches Playing.
        await changeTrack(ownTrackId, "Playing", true);
        const shortTakeCalls = calls().length;
        ipc("press");
        await until(() => {
            const s = snapshot();
            return s && s.capture === "recording" && s.active && fs.existsSync(s.active)
                && calls().length === shortTakeCalls + 1;
        }, "Short-take recorder/native Pause did not start");
        assert.equal(states(snapshot())[pyxampName], "Playing", "Pause notification has not updated Quickshell's cached status");
        ipc("cancel");
        await until(() => calls().length === shortTakeCalls + 2,
            "Explicit Play was suppressed while Quickshell still cached Playing");
        assert.deepEqual(calls().slice(shortTakeCalls), ["Pause", "Play"]);
        await until(() => {
            const s = snapshot();
            return s && s.capture === "idle" && states(s)[playing] === "Playing"
                && states(s)[pyxampName] === "Playing";
        }, "Cancelled short take did not restore media");
        assert.equal(snapshot().held, 0);
        await changeTrack(ownTrackId, "Playing");
        const failureCalls = calls().length;
        fs.writeFileSync(env.DICTATION_TEST_MODE_FILE, "fail");
        ipc("press");
        const microphone = await until(() => {
            const s = snapshot();
            return s && s.state === "failed" && s.kind === "recorder" && s;
        }, "Microphone failure was not shown");
        assert.equal(microphone.text, "Microphone failed");
        assert.equal(microphone.canRetry, false, "Microphone failed offers Dismiss only, never stale Retry");
        assert.equal(microphone.failed, older.failed, "microphone failure preserves the older take");
        await until(() => {
            const s = snapshot();
            return s && states(s)[playing] === "Playing" && states(s)[pyxampName] === "Playing"
                && calls().length === failureCalls + 2;
        }, "Immediate microphone failure did not restore held media");
        assert.deepEqual(calls().slice(failureCalls), ["Pause", "Play"]);
        ipc("dismiss");
        const restored = snapshot();
        assert.equal(restored.state, "failed", "Dismiss brings back the older backend failure");
        assert.equal(restored.kind, "backend");
        assert.equal(restored.text, "Dictation failed");
        assert.equal(restored.canRetry, true, "the older failed take offers Retry again");
        assert.equal(restored.failed, older.failed);
        assert.ok(fs.existsSync(older.failed), "Dismiss did not delete the older take");
        ipc("dismiss");
        assert.equal(snapshot().state, "idle");
        fs.writeFileSync(env.DICTATION_TEST_MODE_FILE, "ok");
        // While the same Pyxamp object is held, it can switch targets. Neither
        // foreign metadata nor a new own occurrence belongs to this take.
        for (const nextTrack of ["/foreign/track", "/org/pyxamp/track/o6364"]) {
            await changeTrack(ownTrackId, "Playing");
            const count = calls().length;
            ipc("press");
            await until(() => {
                const s = snapshot();
                return s && s.capture === "recording" && s.active && fs.existsSync(s.active)
                    && states(s)[pyxampName] === "Paused";
            }, "Own playback was not held before switching tracks");
            assert.equal(snapshot().held, 2, "both playing identities are held before the target changes");
            assert.equal(calls().length, count + 1);
            await changeTrack(nextTrack, "Paused");
            ipc("release");
            await until(() => snapshot()?.capture === "idle", "Capture did not end");
            await until(() => states(snapshot() || {players: []})[playing] === "Playing", "Foreign playback did not resume");
            await wait(150);
            assert.equal(states(snapshot())[pyxampName], "Paused", "release must not play a changed target");
            assert.equal(calls().length, count + 1, "release sent no Play to a changed target");
        }
        await changeTrack("/foreign/track", "Playing");
        const count = calls().length;
        ipc("press");
        await until(() => {
            const s = snapshot();
            return s && s.capture === "recording" && s.active && fs.existsSync(s.active);
        }, "Mirror-mode take did not start");
        assert.equal(snapshot().held, 1, "only the real foreign player is held in mirror mode");
        ipc("release");
        await until(() => {
            const s = snapshot();
            return s && s.capture === "idle" && states(s)[playing] === "Playing";
        }, "Mirror-mode take did not restore foreign playback");
        await wait(150);
        assert.equal(calls().length, count, "no commands are sent through the foreign mirror");
        console.log("dictation-lifecycle: short take and immediate recorder failure restore media; Pyxamp own pauses/resumes once; retargeted own and foreign mirrors receive no Play; microphone failure has Dismiss only; Dismiss restores the older take and Retry");
    } catch (error) {
        console.error(logs);
        throw error;
    } finally {
        await stop(shell);
        for (const player of players) await stop(player);
        await stop(bus);
        await stop(compositor);
        fs.rmSync(work, {recursive: true, force: true});
    }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
