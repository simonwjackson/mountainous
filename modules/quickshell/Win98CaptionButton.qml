import Quickshell
import QtQuick

// A caption button: 16 x 14 u, raised, with Marlett's glyph (close "×" or
// help "?"). Pressed: sunken and the glyph 1 u down and right.
Item {
    id: root

    property string glyph: "close"     // "close" or "help"
    property bool showPressed: false
    property var scheme: null

    signal clicked

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    readonly property bool down: showPressed || (area.pressed && area.containsMouse)

    implicitWidth: Win98Tokens.captionButtonWidth * u
    implicitHeight: Win98Tokens.captionButtonHeight * u

    Win98Bevel {
        anchors.fill: parent
        variant: root.down ? "pressed" : "button"
        scheme: root.scheme
    }
    Win98Icon {
        name: root.glyph
        color: (root.scheme || Win98Tokens)[root.enabled ? "text" : "gray"]
        x: Win98Tokens.snap((root.width - width) / 2, root.u) + (root.down ? root.u : 0)
        y: Win98Tokens.snap((root.height - height) / 2, root.u) + (root.down ? root.u : 0)
    }
    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
