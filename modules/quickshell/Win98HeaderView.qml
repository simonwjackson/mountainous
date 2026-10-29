pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import QtQuick

// A list view's column headers that click: raised buttons 17 u tall, the
// label padded `pad` units in and aligned to its column; a press sinks the
// header (a flat sunken edge, the label 1 u down and right), and the
// release clicks it. Win98's report-mode headers drew no sort mark, so
// none is drawn here (the mock's choice).
//
// columns: [{ id, label, width (logical px), alignRight, sortKey }]. A
// column without a sortKey does not click. showPressed draws one header
// pressed (state sheets).
Item {
    id: root

    property var columns: []
    property real pad: 4
    property string showPressed: ""
    signal clicked(string sortKey)

    readonly property real u: Kit.Win98Tokens.unitFor(QsWindow.window)
    implicitHeight: 17 * u

    Row {
        height: root.height
        Repeater {
            model: root.columns
            Item {
                id: head
                required property var modelData
                readonly property bool down: root.showPressed === modelData.id || (area.pressed && area.containsMouse)
                objectName: "head-" + modelData.id
                width: modelData.width
                height: root.height
                Win98Bevel { anchors.fill: parent; variant: head.down ? "flatPressed" : "button" }
                Win98Text {
                    readonly property real room: Math.max(0, head.width - 2 * root.pad * root.u)
                    x: (head.modelData.alignRight ? head.width - root.pad * root.u - width : root.pad * root.u) + (head.down ? root.u : 0)
                    y: 2 * root.u + (head.down ? root.u : 0)
                    width: Math.min(implicitWidth, room)
                    text: head.modelData.label || ""
                    accessMarks: false
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    enabled: !!head.modelData.sortKey
                    onClicked: root.clicked(head.modelData.sortKey)
                }
            }
        }
    }
}
