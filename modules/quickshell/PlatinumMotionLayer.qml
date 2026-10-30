pragma ComponentBehavior: Bound

import Quickshell
import Hensou as Kit
import QtQuick
import "window-motion.js" as Motion

// The Finder's zoom rectangles for windows (window-motion.js): a window
// opens out of its Control Strip tile and closes back into it, the
// collapse box (hide) zooms it into its tile, Show out again; 150 ms, four
// thin outlines trailing, the glance space's zoom rects. Mac OS 8 had none
// for the zoom box, so maximize cuts.
MotionLayer {
    id: overlay

    required property var strip

    theme: "platinum"
    reduced: GlanceState.reducedMotion || Kit.PlatinumTokens.reducedMotion
    endpoints: function (e) { return overlay.ends(e); }

    // The window's title bar (hyprbars-platinum, bar_height).
    readonly property real titleBar: 20
    // Each window supplies its own device pixel ratio: ratioFor reads this
    // layer's window. The tokens' pixelRatio is only the fallback outside one.
    dpr: Kit.PlatinumTokens.ratioFor(QsWindow.window)
    function snap(v) { return Math.round(v * overlay.dpr) / overlay.dpr; }

    // The tiles as they were one change ago: a closed window's tile has
    // gone by the time its event arrives. kept: a hidden window's tile.
    property var tilesNow: ({})
    property var tilesBefore: ({})
    property var kept: ({})
    readonly property var stripTiles: strip.tiles
    onStripTilesChanged: { overlay.tilesBefore = overlay.tilesNow; overlay.tilesNow = overlay.stripTiles; }
    Component.onCompleted: overlay.tilesNow = overlay.stripTiles

    function tile(k, e) {
        const now = overlay.strip.tiles[k] || overlay.tilesNow[k];
        if (now) return now;
        if (e.kind === "close") return overlay.tilesBefore[k] || null;
        if (e.kind === "restore") return overlay.kept[k] || overlay.strip.tail;
        return null;
    }
    // A shown window whose place was never seen: the middle two thirds.
    function middle() {
        const s = overlay.desktop.screen;
        const w = s ? s.width : overlay.width, h = s ? s.height : overlay.height;
        return { x: w / 6, y: h / 6, w: w * 2 / 3, h: h * 2 / 3 };
    }
    function ends(e) {
        const k = Motion.key(e.address);
        const from = overlay.tile(k, e);
        if (!from) return null;
        if (e.kind === "minimize" || (e.kind === "restore" && overlay.kept[k])) {
            const next = Object.assign({}, overlay.kept);
            if (e.kind === "minimize") next[k] = from;
            else delete next[k];
            overlay.kept = next;
        }
        const win = e.rect ? Motion.frameOf(Motion.local(e.rect, overlay.desktop.screen), overlay.titleBar) : overlay.middle();
        return { origin: from, target: win };
    }

    Repeater {
        model: overlay.flights
        Item {
            id: flight
            required property var modelData
            Repeater {
                model: overlay.rectsOf(flight.modelData)
                Item {
                    required property var modelData
                    x: overlay.snap(modelData.x)
                    y: overlay.snap(modelData.y)
                    width: overlay.snap(Math.max(2 * Kit.PlatinumTokens.hairFor(QsWindow.window), modelData.w))
                    height: overlay.snap(Math.max(2 * Kit.PlatinumTokens.hairFor(QsWindow.window), modelData.h))
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: Kit.PlatinumTokens.hairFor(QsWindow.window)
                        border.color: PlatinumGlanceTokens.zoomOuter
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Kit.PlatinumTokens.hairFor(QsWindow.window)
                        color: "transparent"
                        border.width: Kit.PlatinumTokens.hairFor(QsWindow.window)
                        border.color: PlatinumGlanceTokens.zoomInner
                    }
                }
            }
        }
    }
}
