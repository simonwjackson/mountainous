import Quickshell
import QtQuick

// A Win98 group box: an etched frame (grey over white) with its title on
// the top line, 6 u in, on the face colour. Children go inside, 7 u from
// the sides and the bottom and 10 u below the line; the box takes the
// first child's implicit size unless you size it.
Item {
    id: root

    property string title: ""
    property color titleColor: Win98Tokens.text
    property bool titleDisabled: false
    default property alias content: body.data
    property real padUnits: 7
    property real topUnits: 10

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    // The title's line box sits across the frame's top line.
    readonly property real frameTop: 7 * u
    readonly property Item first: body.children.length > 0 ? body.children[0] : null

    implicitWidth: Math.max(first ? first.implicitWidth + 2 * padUnits * u : 0, label.implicitWidth + 16 * u)
    implicitHeight: frameTop + topUnits * u + (first ? first.implicitHeight : 0) + padUnits * u

    Win98Bevel {
        x: 0; y: root.frameTop
        width: root.width
        height: root.height - root.frameTop
        variant: "group"
        filled: false
    }
    Rectangle {
        visible: root.title !== ""
        x: 6 * root.u
        y: 0
        width: label.width + 4 * root.u
        height: label.height
        color: Win98Tokens.face
    }
    Win98Text {
        id: label
        visible: root.title !== ""
        x: 8 * root.u
        y: 0
        width: Math.min(implicitWidth, root.width - 16 * root.u)
        text: root.title
        color: root.titleColor
        disabledLook: root.titleDisabled
    }
    Item {
        id: body
        x: root.padUnits * root.u
        y: root.frameTop + root.topUnits * root.u
        width: root.width - 2 * root.padUnits * root.u
        height: root.height - y - root.padUnits * root.u
    }
}
