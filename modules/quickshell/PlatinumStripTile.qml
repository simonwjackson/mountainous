import QtQuick

// One window on the Control Strip: a square Platinum module.
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
    property string letter: ""
    property bool shown: true
    property bool focused: false
    property bool menuOpen: false
    property bool source: false
    property bool target: false

    readonly property real hair: PlatinumTokens.hair
    readonly property bool black: !PlatinumTokens.stripBevelled
    readonly property bool sunk: focused && !menuOpen && !source

    width: 30
    height: 30

    // The face.
    Rectangle {
        anchors.fill: parent
        visible: !tile.source
        color: tile.menuOpen ? PlatinumTokens.highlight
            : tile.sunk ? PlatinumTokens.tileSunk
            : tile.shown && !tile.black ? PlatinumTokens.tile : "transparent"
        border.width: tile.menuOpen || (tile.sunk && tile.black) ? tile.hair : 0
        border.color: tile.menuOpen ? PlatinumTokens.stripEdge : PlatinumTokens.tileSunkEdge
    }

    // The bevel: raised on the shown page, sunken for the focused window.
    Item {
        anchors.fill: parent
        visible: !tile.black && !tile.source && !tile.menuOpen && (tile.shown || tile.sunk)
        readonly property color lightEdge: tile.sunk ? PlatinumTokens.bevelDark : PlatinumTokens.bevelLight
        readonly property color darkEdge: tile.sunk ? PlatinumTokens.bevelLight : PlatinumTokens.bevelDark
        Rectangle { x: 0; y: 0; width: parent.width; height: tile.hair; color: parent.lightEdge }
        Rectangle { x: 0; y: 0; width: tile.hair; height: parent.height; color: parent.lightEdge }
        Rectangle { x: 0; y: parent.height - tile.hair; width: parent.width; height: tile.hair; color: parent.darkEdge }
        Rectangle { x: parent.width - tile.hair; y: 0; width: tile.hair; height: parent.height; color: parent.darkEdge }
    }

    // The icon sits a little left of centre, clear of the ▴. Pressed in, it
    // moves one physical pixel down and right, as a Platinum button's face.
    PlatinumAppIcon {
        id: image
        visible: !tile.source && tile.icon !== ""
        x: PlatinumTokens.snap(3) + (tile.sunk ? 1 / PlatinumTokens.pixelRatio : 0)
        y: PlatinumTokens.snap(5) + (tile.sunk ? 1 / PlatinumTokens.pixelRatio : 0)
        size: 20
        name: tile.icon
        inactive: !tile.shown
        surface: PlatinumTokens.stripSurface
    }

    // Until the app id arrives, the title's first letter.
    Text {
        visible: !tile.source && tile.icon === ""
        x: 3; y: 5; width: 20; height: 20
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: tile.letter
        color: tile.shown ? PlatinumTokens.barText : PlatinumTokens.barTextOff
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumSmall
    }

    PlatinumIcon {
        visible: !tile.source
        x: parent.width - 2 - 7
        y: parent.height - 2 - 5
        width: 7
        height: 5
        name: "pop"
        color: tile.menuOpen ? PlatinumTokens.highlightText : tile.shown ? PlatinumTokens.barText : PlatinumTokens.barTextOff
    }

    // The dragged tile's slot: a dotted outline.
    Canvas {
        anchors.fill: parent
        visible: tile.source
        onVisibleChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.strokeStyle = String(PlatinumTokens.barTextSecondary);
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
        border.color: PlatinumTokens.highlight
    }
}
