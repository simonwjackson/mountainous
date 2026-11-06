pragma ComponentBehavior: Bound

import Hensou as Kit
import QtQuick

// Brightness as a Memphis window: one trackbar for every screen that follows
// the level, and the screens in a list (those that keep their own level,
// and monitors not showing this computer, say so). The shared
// BrightnessPanel owns the level and every write.
//
// Keys: Left/Right step the level, as the brightness keys do.
MemphisWindow {
    id: root

    required property var panel

    readonly property int level: panel.shownLevel
    title: "Brightness"
    iconName: "brightness"
    onCloseClicked: MenuState.close()

    Column {
        id: body
        width: root.bodyWidth

        Item { width: 1; height: 2 * root.u }
        Item {
            width: parent.width
            height: 28 * root.u
            MemphisIcon {
                name: "brightness"
                opacity: 0.6
                y: 6 * root.u
            }
            MemphisSlider {
                id: slider
                x: 22 * root.u
                width: 200 * root.u
                enabled: root.level >= 0
                value: root.level < 0 ? 0 : (root.level - root.panel.minimum) / (root.panel.maximum - root.panel.minimum)
                onMoved: function (v) { root.panel.setLevel(root.panel.minimum + v * (root.panel.maximum - root.panel.minimum)); }
            }
            MemphisText {
                x: parent.width - width
                y: Kit.MemphisTokens.snap((parent.height - height) / 2, root.u)
                text: root.level >= 0 ? root.level + "%" : "--"
                accessMarks: false
            }
        }
        Item { width: 1; height: 3 * root.u }
        MemphisGroupBox {
            width: parent.width
            title: "Screens"
            Item {
                width: body.width - 14 * root.u
                implicitHeight: root.panel.rows.length ? screens.height : none.height
                MemphisListView {
                    id: screens
                    visible: root.panel.rows.length > 0
                    width: parent.width
                    height: Math.min(3, root.panel.rows.length) * 34 * root.u + 4 * root.u
                    model: root.panel.rows
                    currentIndex: 0
                    delegate: MemphisListRow {
                        required property var modelData
                        iconName: "display"
                        title: modelData.label
                        titleColor: modelData.follows ? Kit.MemphisTokens.winText : Kit.MemphisTokens.gray
                        detail: modelData.follows ? modelData.detail : "Keeps its own brightness"
                        trailing: modelData.follows ? "dot" : "ring"
                    }
                }
                MemphisText {
                    id: none
                    visible: root.panel.rows.length === 0
                    width: parent.width
                    wrap: true
                    text: "No screen here can change its brightness."
                    accessMarks: false
                    color: Kit.MemphisTokens.gray
                }
            }
        }
        Item { width: 1; height: 8 * root.u }
        MemphisStatusBar {
            width: parent.width
            panes: ["\u2190\u2192 brightness \u00b7 Esc close"]
        }
    }

    Shortcut { sequence: "Left"; context: Qt.WindowShortcut; onActivated: root.panel.step(-1) }
    Shortcut { sequence: "Right"; context: Qt.WindowShortcut; onActivated: root.panel.step(1) }
}
