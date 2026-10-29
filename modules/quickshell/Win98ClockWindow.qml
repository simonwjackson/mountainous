pragma ComponentBehavior: Bound

import Hensou as Kit
import QtQuick
import "themes/win98/tray-model.js" as Tray

// Date/Time as a Win98 window: the full date, the time, and the month with
// today marked. Only a readout; nothing here sets the clock.
Win98Window {
    id: root

    required property date now

    readonly property var clock: Tray.clock(now)
    readonly property int firstDay: new Date(now.getFullYear(), now.getMonth(), 1).getDay()
    readonly property int days: new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
    title: "Date/Time"
    iconName: "doc"
    onCloseClicked: MenuState.close()

    Column {
        id: body
        width: root.bodyWidth
        spacing: 6 * root.u

        Win98Text { text: Qt.formatDateTime(root.now, "dddd, MMMM d, yyyy"); accessMarks: false; bold: true; width: Math.min(implicitWidth, body.width) }
        Win98Text { text: root.clock.time + " " + root.clock.ampm; accessMarks: false }
        Item {
            width: parent.width
            height: month.height - 3 * root.u
            Win98GroupBox {
                id: month
                y: -3 * root.u
                width: parent.width
                title: Qt.formatDateTime(root.now, "MMMM yyyy")
                Win98Bevel {
                    width: 7 * 22 * root.u + 4 * root.u
                    height: grid.height + 4 * root.u
                                implicitHeight: height
                    variant: "field"
                    color: Kit.Win98Tokens.win
                    Grid {
                        id: grid
                        x: 2 * root.u; y: 2 * root.u
                        columns: 7
                        Repeater {
                            model: ["S", "M", "T", "W", "T", "F", "S"]
                            Rectangle {
                                required property string modelData
                                width: 22 * root.u; height: 15 * root.u
                                color: Kit.Win98Tokens.dark ? "#2a2a2a" : Kit.Win98Tokens.sh
                                Win98Text {
                                    x: Kit.Win98Tokens.half((parent.width - width) / 2, root.u); y: root.u
                                    text: parent.modelData; accessMarks: false
                                    color: Kit.Win98Tokens.dark ? "#dddddd" : Kit.Win98Tokens.hi
                                }
                            }
                        }
                        Repeater {
                            model: root.firstDay
                            Item { width: 22 * root.u; height: 15 * root.u }
                        }
                        Repeater {
                            model: root.days
                            Rectangle {
                                required property int index
                                readonly property bool today: index + 1 === root.now.getDate()
                                width: 22 * root.u; height: 15 * root.u
                                color: today ? Kit.Win98Tokens.selection : "transparent"
                                Win98Text {
                                    x: Kit.Win98Tokens.half((parent.width - width) / 2, root.u); y: root.u
                                    text: String(parent.index + 1); accessMarks: false
                                    color: parent.today ? Kit.Win98Tokens.selectionText : Kit.Win98Tokens.winText
                                }
                            }
                        }
                    }
                }
            }
        }
        Item {
            width: parent.width
            height: 20 * root.u
            Win98StatusBar { y: 2 * root.u; width: parent.width; panes: ["Esc close"] }
        }
    }
}
