import Quickshell
import Hensou as Kit
import QtQuick
import "themes/platinum/strip-plan.js" as StripPlan

// One window on the Control Strip: a Platinum module, the icon and then a
// column for the ▴ (StripPlan.tileGeometry has every part's device px).
//
//   on the page the screen shows   raised bevelled tile
//   the focused window             pressed in (sunken bevel, well colour)
//   on another page                flat, the icon in the disabled stipple
//   its menu open                  the highlight, as an open bar title
//   dragged                        a dotted slot where it was
//   under a drag                   a two-hair highlight ring
//
// The ▴ in the corner opens the tile's menu. The strip owns the gestures;
// the tile only draws.
Item {
    id: tile

    property string icon: ""
    property var toplevel: null
    property string letter: ""
    property bool shown: true
    property bool focused: false
    property bool menuOpen: false
    property bool source: false
    property bool target: false

    readonly property real hair: Kit.PlatinumTokens.hairFor(QsWindow.window)
    readonly property bool black: !Kit.PlatinumTokens.stripBevelled
    readonly property bool sunk: focused && !menuOpen && !source
    readonly property real ratio: Kit.PlatinumTokens.ratioFor(QsWindow.window)
    // Device px from the tile's corner; divide by ratio for logical px.
    readonly property var g: StripPlan.tileGeometry(tile.ratio)
    readonly property real press: tile.sunk ? tile.g.sunk : 0

    width: StripPlan.TILE_W
    height: StripPlan.TILE_H

    // The face.
    Rectangle {
        anchors.fill: parent
        visible: !tile.source
        color: tile.menuOpen ? Kit.PlatinumTokens.highlight
            : tile.sunk ? Kit.PlatinumTokens.tileSunk
            : tile.shown && !tile.black ? Kit.PlatinumTokens.tile : "transparent"
        border.width: tile.menuOpen || (tile.sunk && tile.black) ? tile.hair : 0
        border.color: tile.menuOpen ? Kit.PlatinumTokens.stripEdge : Kit.PlatinumTokens.tileSunkEdge
    }

    // The bevel: raised on the shown page, sunken for the focused window.
    Item {
        anchors.fill: parent
        visible: !tile.black && !tile.source && !tile.menuOpen && (tile.shown || tile.sunk)
        readonly property color lightEdge: tile.sunk ? Kit.PlatinumTokens.bevelDark : Kit.PlatinumTokens.bevelLight
        readonly property color darkEdge: tile.sunk ? Kit.PlatinumTokens.bevelLight : Kit.PlatinumTokens.bevelDark
        Rectangle { x: 0; y: 0; width: parent.width; height: tile.hair; color: parent.lightEdge }
        Rectangle { x: 0; y: 0; width: tile.hair; height: parent.height; color: parent.lightEdge }
        Rectangle { x: 0; y: parent.height - tile.hair; width: parent.width; height: tile.hair; color: parent.darkEdge }
        Rectangle { x: parent.width - tile.hair; y: 0; width: tile.hair; height: parent.height; color: parent.darkEdge }
    }

    // Every icon draws in one box, the same distance from the inside of the
    // bevel on three sides, with the ▴ in its own column to the right: a
    // generated token's inner box, and theme art at that size, 1:1 (32 px
    // at scale 1.5). Pressed in, the icon moves one physical pixel down and
    // right, as a Platinum button's face.
    PlatinumAppIcon {
        id: image
        visible: !tile.source && tile.icon !== ""
        x: (tile.g.canvas.x + tile.press) / tile.ratio
        y: (tile.g.canvas.y + tile.press) / tile.ratio
        size: StripPlan.ICON
        artPixels: tile.g.box.size
        name: tile.icon
        toplevel: tile.toplevel
        inactive: !tile.shown
        surface: Kit.PlatinumTokens.stripSurface
    }

    // Until the app id arrives, the title's first letter, in the same box.
    Text {
        visible: !tile.source && tile.icon === ""
        x: (tile.g.box.x + tile.press) / tile.ratio
        y: (tile.g.box.y + tile.press) / tile.ratio
        width: tile.g.box.size / tile.ratio
        height: tile.g.box.size / tile.ratio
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: tile.letter
        color: tile.shown ? Kit.PlatinumTokens.barText : Kit.PlatinumTokens.barTextOff
        font.family: Kit.PlatinumTokens.platinumFont
        font.pixelSize: Kit.PlatinumTokens.platinumSmall
    }

    PlatinumIcon {
        visible: !tile.source
        x: tile.g.pop.x / tile.ratio
        y: tile.g.pop.y / tile.ratio
        width: tile.g.pop.w / tile.ratio
        height: tile.g.pop.h / tile.ratio
        name: "pop"
        color: tile.menuOpen ? Kit.PlatinumTokens.highlightText : tile.shown ? Kit.PlatinumTokens.barText : Kit.PlatinumTokens.barTextOff
    }

    // The dragged tile's slot: a dotted outline.
    Canvas {
        anchors.fill: parent
        visible: tile.source
        onVisibleChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.strokeStyle = String(Kit.PlatinumTokens.barTextSecondary);
            c.lineWidth = tile.hair;
            c.setLineDash([1.5, 1.5]);
            c.strokeRect(2 + tile.hair / 2, 2 + tile.hair / 2, width - 4 - tile.hair, height - 4 - tile.hair);
        }
    }

    // The drop target's ring.
    Rectangle {
        anchors.fill: parent
        visible: tile.target
        color: "transparent"
        border.width: 2 * tile.hair
        border.color: Kit.PlatinumTokens.highlight
    }
}
