pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "glance-registry.js" as Registry

// Which screen shows the glance space and the standalone Fleet window, and
// the state both keep across restarts. Theme-neutral: a theme that has no
// Fleet views never reads it, and its IPC routes stay no-ops there.
//
// Saved in $XDG_STATE_HOME/mountainous/glance.json (glance-registry.js):
// the widget checks, the places dragged widgets keep until Clean Up, and
// the Fleet window's place, size and WindowShade.
Singleton {
    id: root

    // null while hidden.
    property var glanceScreen: null
    property var fleetScreen: null
    // Where the zoom rects start (summon) or end (dismiss), in the screen's
    // logical coordinates: {x, y, w, h}. null means the Fleet readout.
    property var origin: null
    readonly property var saved: state
    property var state: Registry.parse("")
    property bool loaded: false

    // Reduced motion: every glance motion is an instant cut. Nothing in the
    // session publishes the preference yet, so it is a file a later setting
    // (or a test) writes: "on" in $XDG_STATE_HOME/mountainous/reduced-motion.
    property bool reducedMotion: false

    // Review tools (the glance IPC's seek and slow): hold the space's motion
    // at a time in ms (-1: run), in a direction, or slow it down.
    property real held: -1
    property string heldDir: "in"
    property real slow: 1
    function hold(ms, dir) {
        root.heldDir = dir === "out" ? "out" : "in";
        root.held = Math.max(-1, ms);
    }

    readonly property string stateDir: Theme.stateDir + "/mountainous"

    function showGlance(screen, from) {
        if (!screen) return;
        root.origin = from || null;
        root.glanceScreen = screen;
    }
    function hideGlance(from) {
        if (!root.glanceScreen) return;
        root.origin = from || null;
        root.glanceScreen = null;
    }
    function toggleGlance(screen, from) {
        if (root.glanceScreen) root.hideGlance(from);
        else root.showGlance(screen, from);
    }

    function showFleet(screen) { if (screen) root.fleetScreen = screen; }
    function hideFleet() { root.fleetScreen = null; }
    function toggleFleet(screen) {
        if (root.fleetScreen) root.hideFleet();
        else root.showFleet(screen);
    }

    // A theme that goes away takes its surfaces with it.
    function forget(screen) {
        if (root.glanceScreen === screen) { root.origin = null; root.glanceScreen = null; }
        if (root.fleetScreen === screen) root.fleetScreen = null;
    }

    function enabled(id) { return root.state.enabled[id] !== false; }
    function setEnabled(id, on) { root.commit(Registry.withEnabled(root.state, id, on)); }
    function place(id, r, t) { root.commit(Registry.withPlace(root.state, id, r, t)); }
    function cleanUp() { root.commit(Registry.cleanedUp(root.state)); }
    readonly property bool hasPlaces: Registry.hasPlaces(root.state)
    function shaded(id) { return root.state.shaded[id] === true; }
    function setShaded(id, on) {
        const next = Registry.parse(JSON.stringify(root.state));
        next.shaded[id] = !!on;
        root.commit(next);
    }
    // The Fleet window: {r, t} margins from the top right under the bar,
    // {w, h} once resized, shaded.
    function setFleet(fields) {
        const next = Registry.parse(JSON.stringify(root.state));
        for (const key of Object.keys(fields)) next.fleet[key] = fields[key];
        root.commit(next);
    }
    function resetFleetSize() {
        const next = Registry.parse(JSON.stringify(root.state));
        delete next.fleet.w;
        delete next.fleet.h;
        root.commit(next);
    }

    function commit(next) {
        root.state = Registry.parse(JSON.stringify(next));
        if (root.loaded) stateFile.setText(Registry.serialize(root.state));
    }

    FileView {
        id: stateFile
        path: root.stateDir + "/glance.json"
        printErrors: false
        atomicWrites: true
        onLoaded: { root.state = Registry.parse(text()); root.loaded = true; }
        onLoadFailed: root.loaded = true
    }

    FileView {
        path: root.stateDir + "/reduced-motion"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.reducedMotion = text().trim() === "on"
        onLoadFailed: root.reducedMotion = false
    }
}
