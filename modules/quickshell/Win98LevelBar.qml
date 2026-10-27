pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

// A level bar, in two forms.
//
// The Sound window's bar (blocks: false): 4 u tall, a thin sunken edge, the
// level in the selection colour 1 u inside. On a selected row it inverts (a
// white frame and fill on the selection colour); muted draws the level in
// grey.
//
// Resource Meter's blocks (blocks: true), for the Fleet views: a thin
// sunken face; 3-u blocks with 1-u gaps, 2 u in from the edges, as many as
// the value fills (the mock's hbar). Horizontal in the Details rows
// (10 u tall), vertical in Large Icons (vertical: true, 6 u wide, 2-u
// blocks every 3 u from the bottom). The blocks take the tone (navy,
// warning, danger), grey while stale (the host is not up) or without a
// value. On a selected row the face is the selection colour with a 1-u
// frame, and the blocks are white.
Item {
    id: root

    property real value: 0             // 0..1
    property bool muted: false
    property bool onSelection: false
    property bool blocks: false
    property bool vertical: false
    property string tone: "normal"     // normal, warning, danger
    property bool stale: false

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    readonly property real fill: Math.max(0, Math.min(1, isNaN(root.value) ? 0 : root.value))
    readonly property color blockColor: root.onSelection ? Win98Tokens.selectionText
        : root.stale || isNaN(root.value) ? Win98Tokens.meterStale
        : root.tone === "danger" ? Win98Tokens.meterDanger : root.tone === "warning" ? Win98Tokens.meterWarn : Win98Tokens.meter
    // The mock's counts: (length - 4 + 1) / 4 horizontal blocks; 30 / 3
    // vertical ones in a 32-u meter.
    readonly property int count: !root.blocks ? 0 : root.vertical
        ? Math.round(root.fill * Math.max(0, Math.round(root.height / root.u) - 2) / 3)
        : Math.round(root.fill * (Math.round(root.width / root.u) - 4 + 1) / 4)

    implicitWidth: (blocks ? (vertical ? 6 : 42) : 100) * u
    implicitHeight: (blocks ? (vertical ? 32 : 10) : 4) * u

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
        visible: !root.blocks
        x: root.u; y: root.u
        height: root.height - 2 * root.u
        width: Math.max(0, Win98Tokens.snap(root.width * root.fill, root.u) - 2 * root.u)
        color: root.onSelection ? Win98Tokens.selectionText : root.muted ? Win98Tokens.gray : Win98Tokens.selection
    }
    Repeater {
        model: root.blocks ? root.count : 0
        Rectangle {
            required property int index
            x: root.vertical ? root.u : (2 + index * 4) * root.u
            y: root.vertical ? root.height - (1 + index * 3 + 2) * root.u : 2 * root.u
            width: root.vertical ? root.width - 2 * root.u : 3 * root.u
            height: root.vertical ? 2 * root.u : root.height - 4 * root.u
            color: root.blockColor
        }
    }
}
