.pragma library

// Push-to-talk media hold. A take pauses the players that are playing when
// Right Alt goes down, and on release resumes only those players.
//
// A player is a plain snapshot, so the rules run without D-Bus:
//   { key, dbusName, state: "playing" | "paused" | "stopped",
//     canPause, canPlay, title, artist, trackId }
// key is the live player object. Held snapshots keep that identity and the
// track at press time, even when the same object's metadata changes.
function isPyxamp(dbusName) {
    const name = String(dbusName || "").replace(/^org\.mpris\.MediaPlayer2\./, "");
    return name === "pyxamp" || name.startsWith("pyxamp.");
}

// Pyxamp uses the same bus name and Identity for own and foreign playback.
// Only own queue occurrences get this path (presence.rs own_track_id).
// Missing/foreign ids stay excluded: controlling the mirror would forward a
// duplicate command, or resume whichever foreign player it follows by then.
function isPyxampOwn(player) {
    return isPyxamp(player.dbusName) && typeof player.trackId === "string"
        && /^\/org\/pyxamp\/track\/o(?:[0-9a-f]{2})+$/.test(player.trackId);
}

// The mirror's track names the player Pyxamp follows. Exactly one held
// player with that track resumes last: Pyxamp follows the most recent start,
// so it keeps following the same player after the take.
function isFollowed(player, mirror) {
    return mirror !== null && player.title !== "" && player.title === mirror.title
        && player.artist === mirror.artist;
}

// The snapshots to hold, in the order to resume them later.
function toPause(players) {
    const list = Array.isArray(players) ? players : [];
    const mirror = list.find(p => isPyxamp(p.dbusName) && !isPyxampOwn(p) && p.state === "playing") || null;
    const held = list.filter(p => p.state === "playing" && p.canPause === true
        && (!isPyxamp(p.dbusName) || isPyxampOwn(p)));
    const followed = held.filter(p => !isPyxamp(p.dbusName) && isFollowed(p, mirror));
    if (followed.length !== 1) return held;
    return held.filter(p => p !== followed[0]).concat(followed);
}

// Resume only held identities that are still present, not stopped and playable.
// Pyxamp must still reflect the same own occurrence: Play must never reach a
// foreign target or a different own queue item selected during the take.
//
// A held player that still reports playing is resumed too. The pause is an
// asynchronous D-Bus call, so on a short take its state change may not have
// arrived yet; skipping it would leave it paused. Play on a playing player
// does nothing, and D-Bus delivers the pause and the play in order.
function toResume(heldPlayers, players) {
    const list = Array.isArray(players) ? players : [];
    const held = Array.isArray(heldPlayers) ? heldPlayers : [];
    return held.filter(previous => {
        const player = list.find(p => p.key === previous.key);
        return player !== undefined && player.state !== "stopped" && player.canPlay === true
            && (!isPyxamp(previous.dbusName) || (isPyxampOwn(player) && player.trackId === previous.trackId));
    });
}
