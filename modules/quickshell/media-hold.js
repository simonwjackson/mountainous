.pragma library

// Push-to-talk media hold. A take pauses the players that are playing when
// Right Alt goes down, and on release resumes only those players.
//
// A player is a plain descriptor, so the rules run without D-Bus:
//   { key, dbusName, state: "playing" | "paused" | "stopped",
//     canPause, canPlay, title, artist }
// key is the live player object. The caller compares keys with ===, so a
// player that quit, or restarted under the same bus name, has a new key and
// is never resumed.

// Pyxamp mirrors the player it follows under its own MPRIS name and forwards
// controls to that player. Pausing the mirror as well would send the real
// player a second command, and playing it later would reach whichever player
// Pyxamp follows by then. Same rule as Pyxamp's daemon (daemon/src/policy.rs).
function isPyxampMirror(dbusName) {
    const name = String(dbusName || "").replace(/^org\.mpris\.MediaPlayer2\./, "");
    return name === "pyxamp" || name.startsWith("pyxamp.");
}

// The mirror's track names the player Pyxamp follows. Exactly one held
// player with that track resumes last: Pyxamp follows the most recent start,
// so it keeps following the same player after the take.
function isFollowed(player, mirror) {
    return mirror !== null && player.title !== "" && player.title === mirror.title
        && player.artist === mirror.artist;
}

// The players to pause, in the order to resume them later.
function toPause(players) {
    const list = Array.isArray(players) ? players : [];
    const mirror = list.find(p => isPyxampMirror(p.dbusName) && p.state === "playing") || null;
    const held = list.filter(p => !isPyxampMirror(p.dbusName) && p.state === "playing" && p.canPause === true);
    const followed = held.filter(p => isFollowed(p, mirror));
    if (followed.length !== 1) return held.map(p => p.key);
    return held.filter(p => p !== followed[0]).concat(followed).map(p => p.key);
}

// The held players to resume. A player is skipped when it quit or restarted
// (its key is gone), when someone stopped it, or when it cannot play.
//
// A held player that still reports playing is resumed too. The pause is an
// asynchronous D-Bus call, so on a short take its state change may not have
// arrived yet; skipping it would leave it paused. Play on a playing player
// does nothing, and D-Bus delivers the pause and the play in order.
function toResume(heldKeys, players) {
    const list = Array.isArray(players) ? players : [];
    const keys = Array.isArray(heldKeys) ? heldKeys : [];
    return keys.filter(key => {
        const player = list.find(p => p.key === key);
        return player !== undefined && player.state !== "stopped" && player.canPlay === true;
    });
}
