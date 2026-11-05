import Hensou as Kit
import Quickshell
import Quickshell.Widgets
import QtQuick
import "lettermark.js" as Mark

// An app's tray icon (a StatusNotifierItem), for both themes: the icon
// theme's own art when the theme's set has the icon, otherwise the period
// lettermark (the shared rule in lettermark.js). Never Adwaita or
// hicolor art, never an app's own pixmap.
//
//   SniIcon { themeId: "win98"; row: <sni-tray.js row>; tray: <SniTray>; size: 16 * u }
Item {
    id: root

    property string themeId: "platinum"
    property var row: null
    property var tray: null
    property real size: 16

    readonly property string iconName: row ? row.iconName : ""
    readonly property string resolved: tray && iconName !== "" ? tray.resolvedPath(themeId, iconName) : ""
    readonly property bool lettermark: Mark.needs(iconName, resolved, themeId)
    readonly property var mark: Mark.mark(themeId, row ? row.label : "", row ? row.id : "")
    readonly property bool win98: themeId === "win98"
    // One art pixel: the tile is 16 art px across.
    readonly property real px: root.size / 16

    implicitWidth: root.size
    implicitHeight: root.size
    width: root.size
    height: root.size

    IconImage {
        visible: !root.lettermark
        anchors.fill: parent
        implicitSize: root.size
        source: root.lettermark ? "" : Quickshell.iconPath(root.iconName, true)
    }

    // The lettermark: Memphis a raised Win98 tile (white and black outer
    // bevel, grey inner shadow); Platinum a black-outlined face with a
    // lighter top edge. The letter is white, in the theme's face.
    Item {
        visible: root.lettermark
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: root.mark.edge; visible: !root.win98 }
        Rectangle {
            visible: root.win98
            anchors.fill: parent
            color: root.mark.dark
            Rectangle { width: parent.width - root.px; height: parent.height - root.px; color: root.mark.light }
            Rectangle {
                x: root.px; y: root.px
                width: parent.width - 2 * root.px; height: parent.height - 2 * root.px
                color: root.mark.shade
                Rectangle { width: parent.width - root.px; height: parent.height - root.px; color: root.mark.fill }
            }
        }
        Rectangle {
            visible: !root.win98
            x: root.px; y: root.px
            width: parent.width - 2 * root.px; height: parent.height - 2 * root.px
            color: root.mark.fill
            Rectangle { width: parent.width; height: root.px; color: root.mark.light }
        }
        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.win98 ? -root.px / 2 : 0
            anchors.verticalCenterOffset: root.win98 ? -root.px / 2 : root.px / 2
            text: root.mark.letter
            color: root.mark.ink
            font.family: root.win98 ? Kit.Win98Tokens.fontFamily : Kit.PlatinumTokens.platinumFont
            font.pixelSize: Math.round(root.size * (root.win98 ? 0.72 : 0.62))
            font.bold: root.win98
            font.hintingPreference: Font.PreferNoHinting
            renderType: Text.NativeRendering
        }
    }
}
