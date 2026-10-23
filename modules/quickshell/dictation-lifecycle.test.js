// Real Dictation.qml, real Quickshell and a software-rendered Wayland server.
// Only the recorder/backend boundary is controlled; no QML source is changed.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {spawn, spawnSync} = require("node:child_process");

const source = process.argv[2] || path.join(__dirname, "Dictation.qml");
const theme = process.argv[3] || path.join(__dirname, "Theme.qml");
const qs = process.env.QUICKSHELL || "qs";
const labwc = process.env.LABWC || "labwc";
const work = fs.mkdtempSync(path.join(os.tmpdir(), "dcl-"));
const runtime = path.join(work, "r");
const config = path.join(work, "shell");
const bin = path.join(work, "bin");
for (const dir of [runtime, config, bin]) fs.mkdirSync(dir, {mode: 0o700});
let logs = "", compositor, shell;
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const env = {
    ...process.env, XDG_RUNTIME_DIR: runtime, XDG_STATE_HOME: path.join(work, "state"),
    XDG_CONFIG_HOME: path.join(work, "config"), XDG_SESSION_ID: "dictation-test",
    WAYLAND_DISPLAY: "wayland-0", QT_QPA_PLATFORM: "wayland", QT_QUICK_BACKEND: "software",
    PATH: bin + path.delimiter + process.env.PATH, DICTATION_TEST_MODE_FILE: path.join(work, "mode"),
    WLR_BACKENDS: "headless", WLR_RENDERER: "pixman", WLR_LIBINPUT_NO_DEVICES: "1"
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
ShellRoot {
    Dictation { id: dictation }
    IpcHandler {
        target: "lifecycle"
        function press(): void { dictation.press(false); }
        function release(): void { dictation.release(); }
        function dismiss(): void { dictation.dismissFailure(); }
        function snapshot(): string {
            return JSON.stringify({state: dictation.state, kind: dictation.failureKind,
                canRetry: dictation.canRetry, text: dictation.statusText,
                capture: dictation.captureState, active: dictation.activeTake ? dictation.activeTake.path : "",
                failed: dictation.failedTake ? dictation.failedTake.path : ""});
        }
    }
}
`);
        const compositorConfig = path.join(work, "config", "labwc");
        fs.mkdirSync(compositorConfig, {recursive: true});
        fs.writeFileSync(path.join(compositorConfig, "autostart"), "");
        compositor = start(labwc, ["--config-dir", compositorConfig]);
        await until(() => fs.existsSync(path.join(runtime, "wayland-0")), "Wayland server did not start");
        shell = start(qs, ["-p", config, "--no-color"]);
        await until(() => snapshot(), "Dictation shell did not start");
        ipc("press");
        await until(() => {
            const s = snapshot();
            return s && s.capture === "recording" && s.active && fs.existsSync(s.active);
        }, "Recorder did not start");
        await wait(325); // Production rejects takes shorter than 250 ms.
        ipc("release");
        const older = await until(() => {
            const s = snapshot();
            return s && s.state === "failed" && s.kind === "backend" && s;
        }, "Backend failure was not retained");
        assert.equal(older.canRetry, true);
        assert.ok(older.failed && fs.existsSync(older.failed));
        fs.writeFileSync(env.DICTATION_TEST_MODE_FILE, "fail");
        ipc("press");
        const microphone = await until(() => {
            const s = snapshot();
            return s && s.state === "failed" && s.kind === "recorder" && s;
        }, "Microphone failure was not shown");
        assert.equal(microphone.text, "Microphone failed");
        assert.equal(microphone.canRetry, false, "Microphone failed offers Dismiss only, never stale Retry");
        assert.equal(microphone.failed, older.failed, "microphone failure preserves the older take");
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
        console.log("dictation-lifecycle: microphone failure has Dismiss only; Dismiss restores the older take and Retry");
    } catch (error) {
        console.error(logs);
        throw error;
    } finally {
        await stop(shell);
        await stop(compositor);
        fs.rmSync(work, {recursive: true, force: true});
    }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
