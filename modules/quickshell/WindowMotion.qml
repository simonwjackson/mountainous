import Quickshell
import Quickshell.Hyprland
import QtQuick
import "lanes.js" as Lanes
import "window-motion.js" as Motion

// Window motion events, for every theme: one owner at the shell root that
// turns the hide/show batches (WindowHider's moving signal) and Hyprland's
// openwindow, closewindow and fullscreen events into `requested(e)`. Each
// theme's motion layer draws its own move for an event on its screen
// (Win98MotionLayer, PlatinumMotionLayer); a theme without one ignores
// them. See window-motion.js for the table.
//
//   e = { kind, address, screen, rect, to, title, appId, active }
//   rect, to: global logical px (Hyprland's client rect), or null.
//
// Events come only from a hide, a show, a window opening or closing, or a
// maximize: never from a theme switch or a Quickshell restart (the first
// snapshot is taken without events).
Scope {
    id: motion

    // shell.qml's windowRows and its WindowHider.
    required property var rows
    property var hider: null

    readonly property string theme: Theme.name
    // Reduced motion: the glance space's preference (a file), shared.
    readonly property bool reduced: GlanceState.reducedMotion
    // Review tools (the motion IPC): hold every move at ms (-1 runs), or
    // play it n times slower.
    property real held: -1
    property real slow: 1
    readonly property real duration: Motion.DURATION * Math.max(1, motion.slow)
    // A restored window moves back when its caption or zoom lands, as the
    // OS drew the animation before the window: WindowHider waits this long.
    readonly property int revealDelay: !motion.reduced && Motion.style(motion.theme, "restore") !== ""
        ? Math.round(motion.duration) : 0

    signal requested(var e)

    // The last two snapshots: a closed window is found in the one before.
    property var known: ({})
    property var before: ({})
    // Where a minimized window stood, for its restore.
    property var remembered: ({})
    // openwindow addresses waiting for Hyprland to say where they stand.
    property var opening: ({})
    property bool started: false

    function shown(r) { return !!(r && r.page > 0 && Lanes.isShown(r.toplevel)); }
    function send(e) {
        if (Motion.style(motion.theme, e.kind) === "") return;
        e.theme = motion.theme;
        motion.requested(e);
    }

    onRowsChanged: motion.update()
    Component.onCompleted: motion.update()
    function update() {
        const next = Motion.snapshot(motion.rows, motion.shown);
        if (motion.started) {
            for (const z of Motion.zooms(motion.known, next)) motion.send(z);
            const now = Date.now();
            const waiting = Object.assign({}, motion.opening);
            for (const k of Object.keys(waiting)) {
                const e = next[k];
                if (now - waiting[k] > 1000) { delete waiting[k]; continue; }
                if (!e || !e.rect || !e.shown) continue;
                delete waiting[k];
                motion.send({ kind: "open", address: k, screen: e.screen, rect: e.rect, title: e.title, appId: e.appId, active: e.active });
            }
            motion.opening = waiting;
        }
        motion.started = motion.started || motion.rows.length > 0;
        motion.before = motion.known;
        motion.known = next;
    }

    // WindowHider's batch, before it runs (its state is still the old one).
    Connections {
        target: motion.hider
        function onMoving(moves, state, focus) {
            const pages = {};
            for (const m of Hyprland.monitors.values)
                if (m && m.activeWorkspace) pages[m.name] = m.activeWorkspace.id;
            const events = Motion.fromMoves(moves, motion.known, state, motion.remembered, pages, focus || "");
            const kept = Object.assign({}, motion.remembered);
            for (const e of events) {
                if (e.kind === "minimize") kept[e.address] = { rect: e.rect, screen: e.screen };
                else delete kept[e.address];
            }
            motion.remembered = kept;
            for (const e of events) motion.send(e);
        }
    }

    // shell.qml forwards Hyprland's raw events.
    function event(name, data) {
        if (name === "openwindow") {
            if (Motion.style(motion.theme, "open") === "") return;
            const next = Object.assign({}, motion.opening);
            next[Motion.eventAddress(data)] = Date.now();
            motion.opening = next;
            Hyprland.refreshToplevels();
        } else if (name === "closewindow") {
            const k = Motion.eventAddress(data);
            const e = motion.known[k] || motion.before[k];
            if (e && e.rect && e.shown)
                motion.send({ kind: "close", address: k, screen: e.screen, rect: e.rect, title: e.title, appId: e.appId, active: e.active });
            if (motion.remembered[k]) {
                const kept = Object.assign({}, motion.remembered);
                delete kept[k];
                motion.remembered = kept;
            }
        } else if (name === "fullscreen") {
            // The new rect comes with the next refresh; zooms() compares.
            if (Motion.style(motion.theme, "maximize") !== "") Hyprland.refreshToplevels();
        }
    }
}
