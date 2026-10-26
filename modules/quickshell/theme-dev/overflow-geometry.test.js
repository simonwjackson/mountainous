// Production overflow menu in the real QML engine; no GPU or seat.
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const assert = require("node:assert/strict");
const {spawn, spawnSync} = require("node:child_process");
const source = path.resolve(process.argv[2] || path.join(__dirname, ".."));
const temp = fs.mkdtempSync(path.join(os.tmpdir(), "overflow-geometry-"));
const config = path.join(temp, "shell"), runtime = path.join(temp, "run");
fs.mkdirSync(runtime, {mode: 0o700});
fs.cpSync(source, config, {recursive: true});
fs.chmodSync(config, 0o755);
fs.unlinkSync(path.join(config, "shell.qml"));
fs.copyFileSync(path.join(source, "theme-dev/overflow-geometry.qml"), path.join(config, "shell.qml"));
const env = {...process.env, HOME: temp, XDG_RUNTIME_DIR: runtime, XDG_STATE_HOME: path.join(temp, "state"),
    XDG_CONFIG_HOME: path.join(temp, "config"), WAYLAND_DISPLAY: "wayland-0",
    QT_QPA_PLATFORM: "wayland", QT_QUICK_BACKEND: "software",
    WLR_BACKENDS: "headless", WLR_RENDERER: "pixman", WLR_LIBINPUT_NO_DEVICES: "1",
    LIBSEAT_BACKEND: "seatd", SEATD_SOCK: "/nonexistent/seatd.sock", AQ_DRM_DEVICES: "/nonexistent/card"};
delete env.HYPRLAND_INSTANCE_SIGNATURE;
delete env.DISPLAY;
let logs = "", compositor, shell;
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
function start(command, args) {
    const child = spawn(command, args, {env, detached: true, stdio: ["ignore", "pipe", "pipe"]});
    child.on("error", error => { logs += error.stack; });
    child.stdout.on("data", data => { logs += data; });
    child.stderr.on("data", data => { logs += data; });
    return child;
}
function ipc(method, ...args) {
    const result = spawnSync(process.env.QUICKSHELL, ["-p", config, "ipc", "call", "overflowProbe", method, ...args.map(String)],
        {env, encoding: "utf8", timeout: 2000});
    return result.status === 0 ? result.stdout.trim() : "";
}
function snapshot() { try { return JSON.parse(ipc("snapshot")); } catch { return {}; } }
async function until(predicate, label) {
    for (let i = 0; i < 150; i++) { if (predicate()) return; await wait(50); }
    throw Error("Timed out: " + label + "\n" + logs);
}
async function stop(child) {
    if (!child || child.exitCode !== null) return;
    try { process.kill(-child.pid, "SIGTERM"); } catch { return; }
    await Promise.race([new Promise(resolve => child.once("exit", resolve)), wait(1000)]);
    if (child.exitCode === null && child.signalCode === null) process.kill(-child.pid, "SIGKILL");
}
function rowIsVisible(s, index) {
    const id = s.entries[index];
    const label = {apple: "Apple menu", bt: "Bluetooth", wifi: "Wi-Fi", vol: "Sound", bri: "Brightness", oci: "OCI egress",
        disk: "Server storage", fleet: "Fleet", builder: "Remote builds", ntf: "Notifications", battery: "Battery",
        clock: "Clock", app: "Applications", status: "The recording could not be transcribed.", retry: "Retry dictation", dismiss: "Dismiss"}[id] || id;
    const row = s.rows.find(row => row.name === label || row.name === id);
    assert.ok(row, label + " was not instantiated");
    assert.ok(row.y >= s.viewport.y - 0.1 && row.y + row.height <= s.viewport.y + s.viewport.height + 0.1,
        label + " is outside the scroll viewport: " + JSON.stringify(s));
}
(async () => {
    try {
        compositor = start(process.env.LABWC, []);
        await until(() => fs.existsSync(path.join(runtime, "wayland-0")), "compositor");
        shell = start(process.env.QUICKSHELL, ["-p", config]);
        await until(() => snapshot().entries, "overflow menu");
        for (const height of [130, 60, 600]) {
            ipc("resize", height); await wait(80);
            const initial = snapshot();
            assert.ok(initial.height <= height && initial.height > 0);
            for (let index = 0; index < initial.entries.length; index++) {
                ipc("reveal", index); await wait(20); rowIsVisible(snapshot(), index);
            }
            if (height < 600) assert.equal(snapshot().scrolls, true, "short menus show a scroll bar");
            ipc("reveal", 0);
            for (let index = 1; index < initial.entries.length; index++) {
                ipc("step"); await wait(20); const s = snapshot();
                assert.equal(s.index, index); rowIsVisible(s, index);
            }
            console.log(`OVERFLOW_GEOMETRY_PASSED maxHeight=${height}: all ${initial.entries.length} rows reachable by scrolling and selection`);
        }
        let scanned = 0;
        for (const pid of fs.readdirSync("/proc").filter(name => /^\d+$/.test(name))) {
            let environment;
            try { environment = fs.readFileSync(`/proc/${pid}/environ`, "utf8"); } catch { continue; }
            if (!environment.split("\0").includes(`XDG_RUNTIME_DIR=${runtime}`)) continue;
            scanned++;
            let descriptors; try { descriptors = fs.readdirSync(`/proc/${pid}/fd`); } catch { continue; }
            for (const fd of descriptors) {
                let target; try { target = fs.readlinkSync(`/proc/${pid}/fd/${fd}`); } catch { continue; }
                assert.ok(!target.startsWith("/dev/dri/card"), `DRM card open: ${pid} ${target}`);
            }
        }
        assert.ok(scanned >= 2, "the scan includes the compositor and shell");
        console.log(`DRM_PROOF: private software compositor; scanned all ${scanned} session processes: 0 card nodes`);
        if (/WARN.*scene|TypeError|ReferenceError|Failed to load configuration/i.test(logs)) throw Error(logs);
    } finally {
        await stop(shell); await stop(compositor);
        if (process.env.KEEP_OVERFLOW_TEST) { fs.writeFileSync(path.join(temp, "test.log"), logs); console.log("Evidence: " + temp); }
        else fs.rmSync(temp, {recursive: true, force: true});
    }
})().catch(error => { console.error(error); process.exitCode = 1; });
