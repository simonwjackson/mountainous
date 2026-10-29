import QtQuick
import QtQuick.Layouts

// Platinum tabs: equal raised segments in one strip; the current one is
// sunken into a well. The strip spans the menu's text edge to its right
// edge, so its ends sit on the same lines as the rows below it.
Item {
    id: root

    // [{key, label, icon?}]; an icon (a mark in icons/) stands before its label.
    property var model: []
    property string current: ""
    property real rightInset: PlatinumTokens.menuRightInset
    // The strip's height, and the label size: a segmented control (Tiled,
    // Floating) is a little taller than the tabs.
    property real stripHeight: PlatinumTokens.menuButtonHeight
    signal selected(string key)

    Layout.fillWidth: true
    implicitHeight: root.stripHeight + 8

    Item {
        id: strip
        x: PlatinumTokens.menuTextLeft
        y: 2
        width: root.width - PlatinumTokens.menuTextLeft - root.rightInset
        height: root.stripHeight

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

                Row {
                    anchors.centerIn: parent
                    spacing: 7

                    PlatinumIcon {
                        id: tabIcon
                        visible: !!tab.modelData.icon
                        anchors.verticalCenter: parent.verticalCenter
                        name: tab.modelData.icon || ""
                        color: tabLabel.color
                    }

                    // Beside an icon a label shows whole or not at all:
                    // the icon alone says more than a cut word.
                    Text {
                        id: tabLabel
                        readonly property real room: tab.width - 8 - (tabIcon.visible ? tabIcon.width + 7 : 0)
                        visible: !tabIcon.visible || implicitWidth <= room
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, Math.min(implicitWidth, room))
                        elide: Text.ElideRight
                        text: tab.modelData.label
                        color: root.enabled ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumSmall
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
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
