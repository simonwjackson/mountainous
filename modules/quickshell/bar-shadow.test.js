// Real PlatinumBarShadow.qml, PlatinumTokens.qml and Theme.qml under real
// Quickshell and a headless, software-rendered Wayland server. It pins the
// shadow's contract: it reserves no space, takes no input, maps only with
// its bar, and paints only on the light and grey bars, following the theme
// files live.
//   node bar-shadow.test.js <modules/quickshell>
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {spawn, spawnSync} = require("node:child_process");

const source = process.argv[2] || __dirname;
// The shadow, its tokens, and the shared Theme with the registry it reads.
const files = ["PlatinumBarShadow.qml", "Theme.qml", "ThemeCatalog.qml", "themes.json"];
const qs = process.env.QUICKSHELL || "qs";
const labwc = process.env.LABWC || "labwc";
const work = fs.mkdtempSync(path.join(os.tmpdir(), "bsh-"));
const runtime = path.join(work, "r");
const config = path.join(work, "shell");
const state = path.join(work, "state", "mountainous");
for (const dir of [runtime, config]) fs.mkdirSync(dir, {mode: 0o700});
fs.mkdirSync(state, {recursive: true});
let logs = "", compositor, shell;
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const env = {
    ...process.env, XDG_RUNTIME_DIR: runtime, XDG_STATE_HOME: path.join(work, "state"),
    XDG_CONFIG_HOME: path.join(work, "config"),
    WAYLAND_DISPLAY: "wayland-0", QT_QPA_PLATFORM: "wayland", QT_QUICK_BACKEND: "software",
    WLR_BACKENDS: "headless", WLR_RENDERER: "pixman", WLR_LIBINPUT_NO_DEVICES: "1"
};
delete env.HYPRLAND_INSTANCE_SIGNATURE;
delete env.DISPLAY;
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
function ipc(method, ...args) {
    const result = spawnSync(qs, ["-p", config, "ipc", "call", "shadow", method, ...args],
        {env, encoding: "utf8", timeout: 3000});
    return result.status === 0 ? result.stdout.trim() : "";
}
function snapshot() {
    try { return JSON.parse(ipc("snapshot")); } catch (_) { return null; }
}
// Write a state file the way desktop-theme does: a new file, then rename.
function publish(name, value) {
    fs.writeFileSync(path.join(state, name + ".new"), value + "\n");
    fs.renameSync(path.join(state, name + ".new"), path.join(state, name));
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
        for (const file of files) fs.copyFileSync(path.join(source, file), path.join(config, file));
        publish("theme-name", "platinum");
        publish("theme", "dark");
        publish("theme-extra", "off");
        // A stand-in for PlatinumTopBar: the shadow reads only its screen
        // and whether it is shown.
        fs.writeFileSync(path.join(config, "shell.qml"), `
import Hensou as Kit
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
ShellRoot {
    QtObject {
        id: fakeBar
        property bool visible: true
        property var screen: Quickshell.screens[0]
    }
    PlatinumBarShadow { id: shadow; bar: fakeBar }
    IpcHandler {
        target: "shadow"
        function bar(on: string): void { fakeBar.visible = on === "1"; }
        function snapshot(): string {
            return JSON.stringify({
                mode: Theme.mode, extra: Theme.extraState,
                visible: shadow.visible, painted: shadow.painted,
                ignore: shadow.exclusionMode === ExclusionMode.Ignore,
                height: shadow.implicitHeight, top: shadow.margins.top,
                anchors: [shadow.anchors.top, shadow.anchors.left, shadow.anchors.right, shadow.anchors.bottom],
                mask: shadow.mask ? [shadow.mask.width, shadow.mask.height] : null,
                namespace: shadow.WlrLayershell.namespace,
                topColor: String(Kit.PlatinumTokens.barShadowTop)
            });
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
        const grey = await until(() => {
            const s = snapshot();
            return s && s.mode === "dark" && s;
        }, "Shadow shell did not start");

        // The window contract: under the bar, no reserved space, no input.
        assert.equal(grey.ignore, true, "the shadow ignores exclusive zones and reserves none");
        assert.deepEqual(grey.mask, [0, 0], "an empty mask passes every pointer event through");
        assert.equal(grey.height, 4);
        assert.equal(grey.top, 28, "the shadow starts at the bar's bottom edge");
        assert.deepEqual(grey.anchors, [true, true, true, false]);
        assert.equal(grey.topColor, "#40000000", "25% black at the top edge");
        assert.equal(grey.namespace, "mountainous-bar-shadow");

        // Dark grey paints; extra dark does not; light ignores extra dark.
        assert.equal(grey.visible, true);
        assert.equal(grey.painted, true, "the dark grey bar casts a shadow");
        publish("theme-extra", "on");
        const black = await until(() => {
            const s = snapshot();
            return s && s.extra === "on" && s;
        }, "Extra dark did not reach the shadow");
        assert.equal(black.painted, false, "the black bar casts no shadow");
        assert.equal(black.visible, true, "a theme change does not remap the window");
        publish("theme", "light");
        const light = await until(() => {
            const s = snapshot();
            return s && s.mode === "light" && s;
        }, "Light mode did not reach the shadow");
        assert.equal(light.painted, true, "light mode ignores extra dark");

        // The shadow never shows without its bar.
        ipc("bar", "0");
        assert.equal(snapshot().visible, false, "chrome off hides the shadow with its bar");
        ipc("bar", "1");
        assert.equal(snapshot().visible, true);
        console.log("bar-shadow: no reserved space, no input, maps with its bar, paints on light and grey only");
    } catch (error) {
        console.error(logs);
        throw error;
    } finally {
        await stop(shell);
        await stop(compositor);
        fs.rmSync(work, {recursive: true, force: true});
    }
}
main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
