import QtQuick

// The Sound window's level bar: 4 u tall, a thin sunken edge, the level in
// the selection colour 1 u inside. On a selected row it inverts (a white
// frame and fill on the selection colour); muted draws the level in grey.
Item {
    id: root

    property real value: 0             // 0..1
    property bool muted: false
    property bool onSelection: false

    readonly property real u: Win98Tokens.u

    implicitWidth: 100 * u
    implicitHeight: 4 * u

    Rectangle {
        anchors.fill: parent
        color: root.onSelection ? Win98Tokens.selection : Win98Tokens.face
    }
    Win98Bevel {
        anchors.fill: parent
        filled: false
        visible: !root.onSelection
        variant: "thinSunken"
    }
    Rectangle {
        visible: root.onSelection
        anchors.fill: parent
        color: "transparent"
        border.width: root.u
        border.color: Win98Tokens.selectionText
    }
    Rectangle {
        x: root.u; y: root.u
        height: root.height - 2 * root.u
        width: Math.max(0, Win98Tokens.snap(root.width * Math.max(0, Math.min(1, root.value))) - 2 * root.u)
        color: root.onSelection ? Win98Tokens.selectionText : root.muted ? Win98Tokens.gray : Win98Tokens.selection
    }
}
