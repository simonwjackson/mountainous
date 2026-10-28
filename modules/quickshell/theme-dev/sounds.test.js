// Run the production event player against a recording sink, never host audio.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const source = process.argv[2] || path.resolve(__dirname, '..');
const themes = JSON.parse(fs.readFileSync(path.join(source, 'themes.json')));
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-sounds-'));
try {
    for (const file of ['ThemeSoundPlayer.qml', 'ThemeSoundBank.qml', 'ThemeSoundSink.qml', 'SoundEvents.qml', 'MenuState.qml'])
        fs.copyFileSync(path.join(source, file), path.join(dir, file));
    fs.writeFileSync(path.join(dir, 'qmldir'), 'singleton MenuState 1.0 MenuState.qml\nsingleton SoundEvents 1.0 SoundEvents.qml\n');
    fs.writeFileSync(path.join(dir, 'test.qml'), `
import QtQuick
import "."
Item {
    id: test
    property int opened: 0
    property int destroyed: 0
    property var calls: []
    property var registry: ${JSON.stringify(themes)}
    ThemeSoundPlayer {
        id: player
        enabled: true
        available: true
        muted: false
        soundSet: test.registry[0].sounds
        sinkComponent: Component {
            ThemeSoundSink {
                Component.onCompleted: test.opened++
                Component.onDestruction: test.destroyed++
                function play(source: string): bool { test.calls = test.calls.concat([source]); return true; }
            }
        }
    }
    Connections {
        target: SoundEvents
        function onRequested(event) { player.play(event); }
    }
    Connections {
        target: MenuState
        function onOpened(name) { SoundEvents.requested(name === "shutdown" || name === "logoff" ? "alert" : "menuOpen"); }
    }
    function check(ok, message) { if (!ok) throw new Error(message); }
    Timer {
        interval: 10; running: true
        onTriggered: {
            try {
                const screen = {name: "test"};
                for (const theme of test.registry) {
                    player.soundSet = theme.sounds;
                    for (const event of Object.keys(theme.sounds)) {
                        const n = test.calls.length;
                        SoundEvents.requested(event);
                        check(test.calls.length === n + 1 && test.calls[n] === theme.sounds[event], theme.id + ": " + event);
                    }
                    let n = test.calls.length;
                    MenuState.open("start", screen, 0);
                    MenuState.open("start", screen, 0);
                    check(test.calls.length === n + 1 && test.calls[n] === theme.sounds.menuOpen, "open exactly once");
                    MenuState.close(); MenuState.close();
                    check(test.calls.length === n + 1, "close silent");
                    MenuState.open("shutdown", screen, 0);
                    check(test.calls.length === n + 2 && test.calls[n+1] === theme.sounds.alert, "dialog once");
                    MenuState.close();
                    n = test.calls.length;
                    player.enabled = false;
                    for (const event of Object.keys(theme.sounds)) SoundEvents.requested(event);
                    check(test.calls.length === n && !player.sinkActive, "off silent and sink destroyed");
                    const count = test.opened;
                    player.muted = true; player.enabled = true;
                    SoundEvents.requested("menuOpen");
                    check(test.calls.length === n && test.opened === count && !player.sinkActive, "muted opens no sink");
                    player.muted = false;
                    player.available = false;
                    SoundEvents.requested("menuOpen");
                    check(test.calls.length === n && !player.sinkActive, "unavailable silent");
                    player.available = true;
                    check(!player.play("unknown"), "unknown silent");
                }
                player.enabled = false;
                check(test.opened === test.destroyed, "every sink destroyed");
                console.log("SOUNDS_PASSED: two themes, every event, once, off, mute, unavailable, teardown");
                Qt.exit(37);
            } catch(e) { console.error(e); Qt.exit(1); }
        }
    }
}
`);
    const result = spawnSync(process.env.QML || 'qml', [path.join(dir, 'test.qml')], {
        encoding: 'utf8', timeout: 15000,
        env: {...process.env, QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software'}
    });
    assert.equal(result.status, 37, result.error?.message || result.stdout + result.stderr);
    console.log(result.stdout + result.stderr);
} finally { fs.rmSync(dir, {recursive: true, force: true}); }
