import QtQuick

// One icon from the Win98 set, at its own grid size (16 u, or 24 u for the
// Start menu's large icons) unless size is set. Rasterised at one source
// pixel per physical pixel, so its 1-u lines are exact.
Item {
    id: root

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

    implicitWidth: (size > 0 ? size : natural[0]) * Win98Tokens.u
    implicitHeight: (size > 0 ? size * natural[1] / natural[0] : natural[1]) * Win98Tokens.u

    Image {
        anchors.fill: parent
        smooth: true
        mipmap: false
        sourceSize.width: Math.max(1, Math.round(root.width * Win98Tokens.pixelRatio))
        sourceSize.height: Math.max(1, Math.round(root.height * Win98Tokens.pixelRatio))
        source: root.name === "" ? "" : Win98IconStore.url(root.name, root.color, root.level, root.levelColor)
    }
}
