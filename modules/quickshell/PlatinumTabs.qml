import QtQuick
import QtQuick.Layouts

// Platinum tabs: equal raised segments in one strip; the current one is
// sunken into a well. The strip spans the menu's text edge to its right
// edge, so its ends sit on the same lines as the rows below it.
Item {
    id: root

    // [{key, label}]
    property var model: []
    property string current: ""
    property real rightInset: PlatinumTokens.menuRightInset
    signal selected(string key)

    Layout.fillWidth: true
    implicitHeight: PlatinumTokens.menuButtonHeight + 8

    Item {
        id: strip
        x: PlatinumTokens.menuTextLeft
        y: 2
        width: root.width - PlatinumTokens.menuTextLeft - root.rightInset
        height: PlatinumTokens.menuButtonHeight

        Repeater {
            model: root.model

            Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool active: root.current === modelData.key
                // Neighbours share one edge line, so the strip has no
                // doubled rule between segments. The last segment takes
                // what is left, so the strip ends on the grid's right edge.
                readonly property real step: Math.round(strip.width / root.model.length)
                x: index * step
                width: index < root.model.length - 1 ? step + PlatinumTokens.hair : strip.width - x
                height: strip.height

                PlatinumBevel {
                    anchors.fill: parent
                    sunken: tab.active || area.pressed
                    color: tab.active || area.pressed ? PlatinumTokens.well : PlatinumTokens.raised
                }

                Text {
                    anchors.centerIn: parent
                    text: tab.modelData.label
                    color: PlatinumTokens.menuText
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumSmall
                    font.letterSpacing: PlatinumTokens.platinumTracking
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    onClicked: root.selected(tab.modelData.key)
                }
            }
        }
    }
}
