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
const heldKeys = list => keys(Array.from(list, p => p.key));

// Own playback uses a queue-occurrence MPRIS path, unlike the foreign mirror.
{
    const own = player("pyxamp", "playing", {trackId: "/org/pyxamp/track/o6162"});
    assert.equal(heldKeys(model.toPause([own])), keys(["pyxamp"]), "press pauses Pyxamp own playback");
}

// Only playing players that can pause; Pyxamp's mirror never.
{
    const players = [
        player("mpv", "playing"),
        player("firefox", "paused"),
        player("spotify", "stopped"),
        player("stuck", "playing", {canPause: false}),
        player("pyxamp", "playing", {title: "mpv song", artist: "mpv"})
    ];
    assert.equal(heldKeys(model.toPause(players)), keys(["mpv"]));
    assert.equal(heldKeys(model.toPause([])), keys([]));
    assert.equal(heldKeys(model.toPause(undefined)), keys([]));
}

// Mirror names, with or without the MPRIS prefix.
for (const name of ["org.mpris.MediaPlayer2.pyxamp", "org.mpris.MediaPlayer2.pyxamp.instance2", "pyxamp"]) {
    assert.equal(model.isPyxamp(name), true, name);
}
for (const name of ["org.mpris.MediaPlayer2.pyxampish", "org.mpris.MediaPlayer2.mpv", "", undefined]) {
    assert.equal(model.isPyxamp(name), false, String(name));
}

// The player Pyxamp follows resumes last, so Pyxamp keeps following it.
{
    const players = [
        player("pyxamp", "playing", {title: "a song", artist: "a"}),
        player("a", "playing", {title: "a song", artist: "a"}),
        player("b", "playing")
    ];
    assert.equal(heldKeys(model.toPause(players)), keys(["b", "a"]));
    // Ambiguous: two held players show the mirror's track. Keep bus order.
    players.push(player("c", "playing", {title: "a song", artist: "a"}));
    assert.equal(heldKeys(model.toPause(players)), keys(["a", "b", "c"]));
    // A mirror that is not playing names no followed player.
    assert.equal(heldKeys(model.toPause([player("pyxamp", "paused", {title: "a song", artist: "a"}),
        player("a", "playing", {title: "a song", artist: "a"}), player("b", "playing")])), keys(["a", "b"]));
}

// Resume only what the take held, is still present, not stopped and playable.
{
    const held = ["a", "b", "c", "d", "e"].map(key => player(key, "playing"));
    const now = [
        player("a", "paused"),
        player("b", "playing"),            // its pause has not landed yet: play is a no-op
        player("c", "stopped"),            // someone stopped it
        player("e", "paused", {canPlay: false}),
        player("x", "paused")              // the user paused it before the take
    ];                                     // d quit
    assert.equal(heldKeys(model.toResume(held, now)), keys(["a", "b"]));
    assert.equal(heldKeys(model.toResume([], now)), keys([]));
    assert.equal(heldKeys(model.toResume(undefined, now)), keys([]));
}

// A restart under the same bus name is a new player object: never resumed.
{
    const before = {name: "mpv"};
    const after = {name: "mpv"};
    assert.equal(heldKeys(model.toResume([{...player("mpv", "playing"), key: before}], [{...player("mpv", "paused"), key: after}])), keys([]));
    assert.equal(model.toResume([{...player("mpv", "playing"), key: before}], [{...player("mpv", "paused"), key: before}])[0].key, before);
}

// Own playback is identified by metadata, never by track title or bus name alone.
for (const dbusName of ["org.mpris.MediaPlayer2.pyxamp", "pyxamp", "pyxamp.instance2"]) {
    const own = player("own", "playing", {dbusName, trackId: "/org/pyxamp/track/o6162", title: "", artist: ""});
    const held = model.toPause([own]);
    assert.equal(heldKeys(held), keys(["own"]));
    for (const state of ["paused", "playing"]) {
        assert.equal(heldKeys(model.toResume(held, [{...own, state}])), keys(["own"]));
    }
    for (const change of [
        {trackId: "/foreign/track"},                // same object now forwards to a foreign player
        {trackId: "/org/pyxamp/track/o6364"},       // user selected another own queue occurrence
        {trackId: ""}, {trackId: undefined},       // cannot prove it is still own playback
        {state: "stopped"}, {canPlay: false},
        {key: {name: dbusName}}                    // same bus name, different live object
    ]) {
        assert.equal(heldKeys(model.toResume(held, [{...own, state: "paused", ...change}])), keys([]), JSON.stringify(change));
    }
    assert.equal(heldKeys(model.toResume(held, [])), keys([]));
    for (const change of [{state: "paused"}, {state: "stopped"}, {canPause: false}]) {
        assert.equal(heldKeys(model.toPause([{...own, ...change}])), keys([]));
    }
    // A foreign player with identical title/artist must not suppress own playback.
    const collision = {...own, title: "Shared song", artist: "Shared artist"};
    assert.equal(heldKeys(model.toPause([collision, player("a", "playing", {title: collision.title, artist: collision.artist})])), keys(["own", "a"]));
    assert.equal(heldKeys(model.toResume(held, [{...own, state: "paused", title: "Corrected title"}])), keys(["own"]));
}

// Unknown metadata is conservative: never forward through a possible mirror,
// even if no matching foreign player is present or pausable.
for (const trackId of [undefined, "", {}, "/foreign/track", "/org/pyxamp/track/o", "/org/pyxamp/track/o6", "/org/pyxamp/track/oabz", "/org/pyxamp/track/o61/other"]) {
    const mirror = player("pyxamp", "playing", {trackId});
    assert.equal(heldKeys(model.toPause([mirror])), keys([]));
    assert.equal(heldKeys(model.toPause([mirror, player("stuck", "playing", {canPause: false})])), keys([]));
}

// A mirror that switches to own playback is not newly owned by the take.
{
    const foreign = player("a", "playing");
    const mirror = player("pyxamp", "playing", {title: foreign.title, artist: foreign.artist, trackId: "/foreign/track"});
    const held = model.toPause([mirror, foreign, player("b", "playing")]);
    assert.equal(heldKeys(held), keys(["b", "a"]), "foreign playback is held once and followed resumes last");
    assert.equal(heldKeys(model.toResume(held, [{...mirror, state: "paused", trackId: "/org/pyxamp/track/o6162"},
        {...foreign, state: "paused"}, player("b", "paused")])), keys(["b", "a"]));
}

console.log("media-hold: holds Pyxamp own occurrences, skips foreign mirrors, preserves resume ownership and followed-last order");
