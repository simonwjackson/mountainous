import Quickshell
import Quickshell.Widgets
import QtQuick
import "app-icon.js" as AppIcon

// One icon from the Win98 set, at its own grid size (16 u, or 24 u for the
// Start menu's large icons) unless size is set. Rasterised at one source
// pixel per physical pixel, so its 1-u lines are exact.
//
// "theme:<name>" draws <name> from the icon theme instead (Chicago95 in
// Mountainous-win98): an app whose art is the theme's, not the set's
// (start-model.js appIcon). 16 u is 32 physical px at scale 1.5, one of
// Chicago95's own sizes.
Item {
    id: root
    readonly property real u: Win98Tokens.unitFor(QsWindow.window)

    property string name: ""
    // The colour for the icon's currentColor strokes (wifi bars, sound
    // waves, sun rays): the text colour of the surface under it.
    property color color: Win98Tokens.text
    // Battery only: level 0..1 and its tone colour.
    property var level: undefined
    property color levelColor: "#00a000"
    // Units; 0 means the file's own size.
    property real size: 0

    readonly property bool fromTheme: name.indexOf("theme:") === 0
    readonly property string themeName: fromTheme ? name.slice(6) : ""
    readonly property var natural: fromTheme ? [16, 16] : Win98IconStore.size(name)

    implicitWidth: (size > 0 ? size : natural[0]) * root.u
    implicitHeight: (size > 0 ? size * natural[1] / natural[0] : natural[1]) * root.u

    Image {
        visible: !root.fromTheme
        anchors.fill: parent
        smooth: true
        mipmap: false
        sourceSize.width: Math.max(1, Math.round(root.width * (2 / root.u)))
        sourceSize.height: Math.max(1, Math.round(root.height * (2 / root.u)))
        source: root.name === "" || root.fromTheme ? "" : Win98IconStore.url(root.name, root.color, root.level, root.levelColor)
    }
    IconImage {
        visible: root.fromTheme
        anchors.fill: parent
        source: root.fromTheme ? Quickshell.iconPath(root.themeName, AppIcon.fallback(root.themeName)) : ""
    }
}
