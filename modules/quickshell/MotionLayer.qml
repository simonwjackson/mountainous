pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "window-motion.js" as Motion

// One screen's window motion, shared by the themes' motion layers: it takes
// WindowMotion's events for this screen and theme, keeps the moves in
// flight, and steps their frames. The theme's file draws each move
// (rectsOf) as its OS did. The surface is an overlay above the windows
// that takes no input; it is created with the Desktop and mapped only
// while a move runs, so a theme switch or a restart maps nothing.
PanelWindow {
    id: overlay

    required property var desktop
    // The theme whose moves this draws (window-motion.js MOVES).
    required property string theme
    // (e) -> { origin, target } in this screen's logical px, or null: no move.
    property var endpoints: null
    // Reduced motion: every move is the cut, so nothing is drawn.
    property bool reduced: GlanceState.reducedMotion

    // The surface's scale. It is unmapped (its scale unknown) when a move's
    // ends are measured, and QScreen reports the integer buffer scale, so a
    // theme reads it from a mapped surface of its own (the taskbar, the bar).
    property real dpr: overlay.devicePixelRatio > 0 ? overlay.devicePixelRatio : 1.5
    readonly property var source: desktop.shell && desktop.shell.motion ? desktop.shell.motion : null
    readonly property real slow: source ? Math.max(1, source.slow) : 1
    readonly property real held: source ? source.held : -1

    // { id, kind, style, origin, target, title, active, t0 }
    property var flights: []
    property real now: 0
    property int serial: 0

    screen: desktop.screen
    visible: desktop.active && flights.length > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "mountainous-motion"

    Connections {
        target: overlay.source
        function onRequested(e) { overlay.add(e); }
    }
    Connections {
        target: overlay.desktop
        function onActiveChanged() { if (!overlay.desktop.active) overlay.flights = []; }
    }

    function add(e) {
        if (!overlay.desktop.active || overlay.reduced || !e || e.theme !== overlay.theme) return;
        if (!overlay.desktop.screen || e.screen !== overlay.desktop.screen.name) return;
        const style = Motion.style(overlay.theme, e.kind);
        if (style === "") return;
        // A control can arrive a moment after its event (a new window's
        // tile): a move without both ends asks again on its first frame.
        const ends = overlay.endpoints ? overlay.endpoints(e) : null;
        const ready = !!(ends && ends.origin && ends.target);
        overlay.flights = overlay.flights.concat([{ id: ++overlay.serial, kind: e.kind, style: style, event: e, ready: ready,
            origin: ready ? ends.origin : null, target: ready ? ends.target : null,
            title: e.title || "", active: !!e.active, t0: 0 }]);
    }

    // Milliseconds into one move. A move's clock starts on its first frame,
    // so a surface that maps a frame late still shows frame 0.
    function elapsed(f) {
        if (overlay.held >= 0) return overlay.held;
        return f.t0 > 0 ? Math.max(0, overlay.now - f.t0) / overlay.slow : 0;
    }
    // The rects one move draws now, origin toward target.
    function rectsOf(f) {
        if (!f.ready) return [];
        const fr = Motion.frame(f.style, f.kind, overlay.elapsed(f), false);
        return fr.progress.map(function (p) { return Motion.between(f.origin, f.target, p); });
    }

    FrameAnimation {
        running: overlay.flights.length > 0
        onTriggered: {
            const t = Date.now();
            let lost = false;
            for (const f of overlay.flights) {
                if (f.t0) continue;
                f.t0 = t;
                if (f.ready) continue;
                const ends = overlay.endpoints ? overlay.endpoints(f.event) : null;
                f.ready = !!(ends && ends.origin && ends.target);
                if (f.ready) { f.origin = ends.origin; f.target = ends.target; } else lost = true;
            }
            overlay.now = t;
            const left = overlay.flights.filter(function (f) {
                return f.ready && (overlay.held >= 0 || !Motion.frame(f.style, f.kind, overlay.elapsed(f), false).done);
            });
            if (lost || left.length !== overlay.flights.length) overlay.flights = left;
        }
    }

    // For the harness and checks: the moves in flight and their rects.
    function debug() {
        return overlay.flights.map(function (f) {
            return { kind: f.kind, style: f.style, origin: f.origin, target: f.target, rects: overlay.rectsOf(f), t: overlay.elapsed(f) };
        });
    }
}
