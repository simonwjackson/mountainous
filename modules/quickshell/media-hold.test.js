// The same pure rules Dictation.qml imports; no D-Bus is needed.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const model = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/media-hold.js", "utf8").replace(/^\.pragma library\s*$/m, ""), model);

const player = (key, state, extra) => ({
    key, dbusName: "org.mpris.MediaPlayer2." + key, state,
    canPause: true, canPlay: true, title: key + " song", artist: key, ...extra
});
const keys = list => JSON.stringify(list);

// Only playing players that can pause; Pyxamp's mirror never.
{
    const players = [
        player("mpv", "playing"),
        player("firefox", "paused"),
        player("spotify", "stopped"),
        player("stuck", "playing", {canPause: false}),
        player("pyxamp", "playing", {title: "mpv song", artist: "mpv"})
    ];
    assert.equal(keys(model.toPause(players)), keys(["mpv"]));
    assert.equal(keys(model.toPause([])), keys([]));
    assert.equal(keys(model.toPause(undefined)), keys([]));
}

// Mirror names, with or without the MPRIS prefix.
for (const name of ["org.mpris.MediaPlayer2.pyxamp", "org.mpris.MediaPlayer2.pyxamp.instance2", "pyxamp"]) {
    assert.equal(model.isPyxampMirror(name), true, name);
}
for (const name of ["org.mpris.MediaPlayer2.pyxampish", "org.mpris.MediaPlayer2.mpv", "", undefined]) {
    assert.equal(model.isPyxampMirror(name), false, String(name));
}

// The player Pyxamp follows resumes last, so Pyxamp keeps following it.
{
    const players = [
        player("pyxamp", "playing", {title: "a song", artist: "a"}),
        player("a", "playing", {title: "a song", artist: "a"}),
        player("b", "playing")
    ];
    assert.equal(keys(model.toPause(players)), keys(["b", "a"]));
    // Ambiguous: two held players show the mirror's track. Keep bus order.
    players.push(player("c", "playing", {title: "a song", artist: "a"}));
    assert.equal(keys(model.toPause(players)), keys(["a", "b", "c"]));
    // A mirror that is not playing names no followed player.
    assert.equal(keys(model.toPause([player("pyxamp", "paused", {title: "a song", artist: "a"}),
        player("a", "playing", {title: "a song", artist: "a"}), player("b", "playing")])), keys(["a", "b"]));
}

// Resume only what the take held, is still present, not stopped and playable.
{
    const held = ["a", "b", "c", "d", "e"];
    const now = [
        player("a", "paused"),
        player("b", "playing"),            // its pause has not landed yet: play is a no-op
        player("c", "stopped"),            // someone stopped it
        player("e", "paused", {canPlay: false}),
        player("x", "paused")              // the user paused it before the take
    ];                                     // d quit
    assert.equal(keys(model.toResume(held, now)), keys(["a", "b"]));
    assert.equal(keys(model.toResume([], now)), keys([]));
    assert.equal(keys(model.toResume(undefined, now)), keys([]));
}

// A restart under the same bus name is a new player object: never resumed.
{
    const before = {name: "mpv"};
    const after = {name: "mpv"};
    assert.equal(keys(model.toResume([before], [{...player("mpv", "paused"), key: after}])), keys([]));
    assert.equal(model.toResume([before], [{...player("mpv", "paused"), key: before}])[0], before);
}

console.log("media-hold: pauses playing players, skips Pyxamp's mirror, resumes only what the take paused");
