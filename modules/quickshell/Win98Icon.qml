import Quickshell
import QtQuick

// One icon from the Win98 set, at its own grid size (16 u, or 24 u for the
// Start menu's large icons) unless size is set. Rasterised at one source
// pixel per physical pixel, so its 1-u lines are exact.
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

    readonly property var natural: Win98IconStore.size(name)

    implicitWidth: (size > 0 ? size : natural[0]) * root.u
    implicitHeight: (size > 0 ? size * natural[1] / natural[0] : natural[1]) * root.u

    Image {
        anchors.fill: parent
        smooth: true
        mipmap: false
        sourceSize.width: Math.max(1, Math.round(root.width * (2 / root.u)))
        sourceSize.height: Math.max(1, Math.round(root.height * (2 / root.u)))
        source: root.name === "" ? "" : Win98IconStore.url(root.name, root.color, root.level, root.levelColor)
    }
}
