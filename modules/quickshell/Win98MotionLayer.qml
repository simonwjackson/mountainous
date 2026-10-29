pragma ComponentBehavior: Bound

import Hensou as Kit
import QtQuick
import "window-motion.js" as Motion

// Windows 98's caption animation for windows (window-motion.js): on
// minimize a caption bar flies from the window's caption to its taskbar
// button, on restore back, on maximize and restore from the old caption
// to the new one; 150 ms, the glance space's caption timing. The caption
// is the window's own: its title, the active gradient (or the inactive one
// for a window that was not focused). Opening and closing a window has no
// animation in Win98, so neither has one here.
MotionLayer {
    id: overlay

    required property var taskbar

    theme: "win98"
    reduced: GlanceState.reducedMotion || Kit.Win98Tokens.reducedMotion
    endpoints: function (e) { return overlay.ends(e); }

    // 1 u is two physical px, at the taskbar's scale (always mapped while
    // its window buttons are there to fly to).
    dpr: taskbar.devicePixelRatio > 0 ? taskbar.devicePixelRatio : Kit.Win98Tokens.pixelRatio
    readonly property real u: 2 / overlay.dpr
    function units(n) { return n * overlay.u; }
    readonly property real captionH: overlay.units(Kit.Win98Tokens.captionHeight)
    // The caption sits a seam above the client (hyprbars-platinum).
    function caption(rect) {
        const r = Motion.captionOf(Motion.local(rect, overlay.desktop.screen), overlay.captionH + overlay.u);
        return { x: r.x, y: r.y, w: r.w, h: overlay.captionH };
    }
    // The window's taskbar button, or where the taskbar keeps it: the
    // windows chevron, then Start.
    function button(address) {
        const t = overlay.taskbar;
        const entries = overlay.desktop.laneEntries || [];
        let i = -1;
        for (let j = 0; j < entries.length; j++) if (entries[j].row.address === Motion.key(address)) i = j;
        const p = (i >= 0 ? t.placeOf("win" + i) : null) || t.placeOf("tasks") || t.placeOf("start");
        if (!p) return null;
        const h = overlay.desktop.screen ? overlay.desktop.screen.height : overlay.height;
        return { x: p.x, y: h - t.barHeight + overlay.units(4), w: p.w, h: overlay.units(22) };
    }
    // A restored window whose place was never seen: the work area's top.
    function workArea() {
        const s = overlay.desktop.screen;
        const w = s ? s.width : overlay.width, h = s ? s.height : overlay.height;
        return { x: overlay.units(4), y: overlay.units(4), w: Math.max(overlay.u, w - overlay.units(8)), h: overlay.captionH };
    }
    function ends(e) {
        if (e.kind === "maximize" || e.kind === "unmaximize")
            return e.rect && e.to ? { origin: overlay.caption(e.rect), target: overlay.caption(e.to) } : null;
        const b = overlay.button(e.address);
        if (!b) return null;
        return { origin: b, target: e.rect ? overlay.caption(e.rect) : overlay.workArea() };
    }

    Repeater {
        model: overlay.flights
        Item {
            id: flight
            required property var modelData
            Repeater {
                model: overlay.rectsOf(flight.modelData)
                Rectangle {
                    id: bar
                    required property var modelData
                    x: Kit.Win98Tokens.snap(modelData.x, overlay.u)
                    y: Kit.Win98Tokens.snap(modelData.y, overlay.u)
                    width: Math.max(overlay.u, Kit.Win98Tokens.snap(modelData.w, overlay.u))
                    height: Math.max(overlay.u, Kit.Win98Tokens.snap(modelData.h, overlay.u))
                    clip: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: flight.modelData.active ? Kit.Win98Tokens.caption1 : Kit.Win98Tokens.inactiveCaption1 }
                        GradientStop { position: 1; color: flight.modelData.active ? Kit.Win98Tokens.caption2 : Kit.Win98Tokens.inactiveCaption2 }
                    }
                    Win98Text {
                        x: overlay.units(3 + 16 + 3)
                        y: overlay.units(3)
                        visible: bar.height >= overlay.units(12)
                        text: flight.modelData.title
                        accessMarks: false
                        bold: true
                        color: flight.modelData.active ? Kit.Win98Tokens.captionText : Kit.Win98Tokens.inactiveCaptionText
                    }
                }
            }
        }
    }
}
