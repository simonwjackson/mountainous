import Quickshell
import QtQuick
import "lettermark.js" as Mark

// A period lettermark tile (lettermark.js): the Chi-Nata-style cube in
// Platinum, the raised Win98 tile in Memphis, with the app's letter.
//
//   Lettermark { themeId: Theme.name; label: "Krita"; appId: "org.kde.krita"; size: 32 }
//
// The art is drawn as runs of art pixels, each edge rounded to a whole
// device pixel, so the tile stays crisp at any size and scale (16 u for a
// Memphis tray icon, 16 to 32 px in Platinum, the desktop's 32).
//
// letter and tint override the derived ones: the desktop provider sends
// IconArt::Lettermark { letter, tint } and draws through the same tile.
Item {
    id: root

    property string themeId: "platinum"
    property string label: ""
    property string appId: ""
    property real size: 32
    property string letter: ""
    property string tint: ""
    // The window's device pixel ratio (QsWindow), 1.5 outside one.
    property real devicePixelRatio: QsWindow.window && QsWindow.window.devicePixelRatio > 0
        ? QsWindow.window.devicePixelRatio : 1.5

    readonly property bool win98: root.themeId === "win98"
    readonly property var derived: Mark.mark(root.themeId, root.label, root.appId)
    readonly property var colours: root.tint !== "" ? Mark.colours(root.themeId, root.tint) : root.derived
    readonly property string shownLetter: root.letter !== "" ? root.letter.charAt(0).toUpperCase() : root.derived.letter
    readonly property int grid: Mark.gridFor(root.themeId, root.size)
    readonly property var art: Mark.art(root.themeId, root.colours, root.grid)
    // Device pixels across the tile, and one art coordinate to logical px
    // on a whole device pixel.
    readonly property int device: Math.max(1, Math.round(root.size * root.devicePixelRatio))
    function at(v) { return Math.round(v * root.device / root.grid) / root.devicePixelRatio; }

    implicitWidth: root.size
    implicitHeight: root.size
    width: root.size
    height: root.size

    Repeater {
        model: root.art.rects
        Rectangle {
            required property var modelData
            x: root.at(modelData.x)
            y: root.at(modelData.y)
            width: root.at(modelData.x + modelData.w) - x
            height: root.at(modelData.y + modelData.h) - y
            color: modelData.color
            antialiasing: false
        }
    }

    // The letter, centred on the front face (Platinum) or the tile, struck
    // twice one art pixel apart in Memphis as Win98Text draws bold.
    Item {
        id: face
        x: root.at(root.art.face.x)
        y: root.at(root.art.face.y)
        width: root.at(root.art.face.x + root.art.face.w) - x
        height: root.at(root.art.face.y + root.art.face.h) - y
        Repeater {
            model: root.art.strike > 0 ? 2 : 1
            Text {
                required property int index
                x: index * (root.at(root.art.strike) - root.at(0))
                width: face.width
                height: face.height
                text: root.shownLetter
                color: root.colours.ink
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.win98 ? "W95FA Grid" : "ChicagoFLF"
                font.pixelSize: Math.max(6, Math.round(root.art.text * root.size / root.grid))
                font.hintingPreference: Font.PreferNoHinting
                font.kerning: false
                renderType: Text.QtRendering
            }
        }
    }
}
