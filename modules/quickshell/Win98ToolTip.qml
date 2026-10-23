pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

// A Win98 tooltip: pale yellow (olive-grey in dark grey), a 1-u edge,
// 2 u above and below the text and 4 u beside it. Lines break only at
// "\n"; a line longer than maxWidth units elides with three dots.
Item {
    id: root

    property string text: ""
    property real maxWidthUnits: 400

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    readonly property var lines: text.split("\n")
    readonly property real textWidth: Math.min(maxWidthUnits * u, Win98Tokens.ceilU(Win98Tokens.widest(lines, false, root.u), root.u))

    implicitWidth: textWidth + 8 * u
    implicitHeight: lines.length * (Win98Tokens.lineUnits * root.u) + 4 * u

    Rectangle {
        anchors.fill: parent
        color: Win98Tokens.tip
        border.width: root.u
        border.color: Win98Tokens.tipEdge
    }
    Column {
        x: 4 * root.u; y: 2 * root.u
        Repeater {
            model: root.lines
            Win98Text {
                required property string modelData
                width: Math.min(implicitWidth, root.width - 8 * root.u)
                text: modelData
                accessMarks: false
                color: Win98Tokens.tipText
            }
        }
    }
}
