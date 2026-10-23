import QtQuick
import QtQuick.Layouts

// The Platinum menu box that every bar menu draws in: a black edge, a
// one-rule bevel, and a hard shadow one rule down and right. The header
// puts the title on the text edge and the close box on the right edge;
// a detail line under the title is where a readout the bar gave up lives
// (the volume number, the Bluetooth count, the full date).
//
// The frame grows with its content up to maxHeight. A list inside takes
// what is left and scrolls; while it does, scrolls is true and the right
// edge of every row moves in by the scroll bar, all together.
Item {
    id: root

    property string title: ""
    property string detail: ""
    property color detailColor: Theme.menuTextSecondary
    // The width the menu asks for; MenuHost caps it by the screen.
    property real preferredWidth: 360
    property real menuWidth: preferredWidth
    property real maxHeight: 600
    property bool scrolls: false
    property bool showHeader: true
    readonly property real rightInset: Theme.menuRightInset + (scrolls ? Theme.menuScrollBar : 0)
    readonly property real hair: Theme.hair
    default property alias content: column.data
    property alias headerTrailing: headerRow.data
    signal closeRequested

    width: menuWidth
    implicitHeight: Math.min(maxHeight, column.implicitHeight + 4 + 6 + 2 * hair)
    height: implicitHeight

    // Clicks inside the menu stay inside it.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: function (w) { w.accepted = false; } }

    Rectangle {
        x: root.hair
        y: root.hair
        width: parent.width
        height: parent.height
        color: Theme.menuShadow
    }

    Bevel {
        anchors.fill: parent
        color: Theme.menuSurface
    }

    ColumnLayout {
        id: column
        x: root.hair
        y: root.hair + 4
        width: parent.width - 2 * root.hair
        height: parent.height - 2 * root.hair - 4 - 6
        spacing: 0

        Item {
            id: header
            visible: root.showHeader
            Layout.fillWidth: true
            Layout.preferredHeight: root.detail !== "" ? 42 : 28

            Column {
                x: Theme.menuTextLeft
                anchors.verticalCenter: parent.verticalCenter
                width: headerRow.x - x - Theme.menuGap
                spacing: 1

                Text {
                    width: parent.width
                    text: root.title
                    elide: Text.ElideRight
                    color: Theme.menuText
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumText
                    font.letterSpacing: Theme.platinumTracking
                }

                Text {
                    visible: root.detail !== ""
                    width: parent.width
                    text: root.detail
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.detailColor
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumSmall
                    font.letterSpacing: Theme.platinumTracking
                }
            }

            Row {
                id: headerRow
                anchors.right: closeBox.left
                anchors.rightMargin: children.length > 0 ? Theme.menuGap : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.menuGap
            }

            // The Platinum close box: a small raised square.
            Bevel {
                id: closeBox
                width: 16
                height: 16
                anchors.right: parent.right
                anchors.rightMargin: root.rightInset
                anchors.verticalCenter: parent.verticalCenter
                sunken: closeArea.pressed
                color: closeArea.pressed ? Theme.well : Theme.raised

                PlatinumIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 8
                    color: Theme.menuText
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: root.closeRequested()
                }
            }
        }
    }
}
