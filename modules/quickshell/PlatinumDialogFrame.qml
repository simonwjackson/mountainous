import QtQuick

// A small Platinum dialog frame: a black edge, the one-rule bevel, a hard
// shadow, and a title bar with a close box at the left and engraved stripes
// either side of the title. About and the confirmation alerts draw in it.
// An alert passes closable: false and gets plain stripes. The Fleet window
// and the glance space use PlatinumWindoid, a utility window with a
// WindowShade box.
Item {
    id: root

    property string title: ""
    property bool closable: true
    default property alias content: body.data
    property real padding: 16
    signal closeRequested

    readonly property real hair: PlatinumTokens.hair
    readonly property real titleHeight: title !== "" || closable ? 20 : 0

    implicitWidth: body.childrenRect.width + 2 * padding + 2 * hair
    implicitHeight: titleHeight + body.childrenRect.height + 2 * padding + 2 * hair

    Rectangle {
        x: 2 * root.hair
        y: 2 * root.hair
        width: parent.width
        height: parent.height
        color: PlatinumTokens.menuShadow
    }
    PlatinumBevel {
        anchors.fill: parent
        color: PlatinumTokens.menuSurface
    }
    // Clicks inside stay inside.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    Item {
        id: titleBar
        visible: root.titleHeight > 0
        x: root.hair
        y: root.hair
        width: parent.width - 2 * root.hair
        height: root.titleHeight

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: root.hair
            color: PlatinumTokens.menuEdge
        }

        // The close box: a small raised square.
        PlatinumBevel {
            id: box
            visible: root.closable
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -root.hair / 2
            width: 11
            height: 11
            sunken: boxArea.pressed
            color: boxArea.pressed ? PlatinumTokens.well : PlatinumTokens.raised
            MouseArea {
                id: boxArea
                anchors.fill: parent
                anchors.margins: -6
                onClicked: root.closeRequested()
            }
        }

        Text {
            id: label
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -root.hair / 2
            text: root.title
            textFormat: Text.PlainText
            color: PlatinumTokens.menuText
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: 13
            font.letterSpacing: PlatinumTokens.platinumTracking
        }

        // Engraved stripes: light, dark, gap, repeated.
        component Stripes: Column {
            spacing: root.hair
            Repeater {
                model: 3
                Column {
                    width: parent.width
                    Rectangle { width: parent.width; height: root.hair; color: PlatinumTokens.bevelLight }
                    Rectangle { width: parent.width; height: root.hair; color: PlatinumTokens.bevelDark }
                }
            }
        }
        Stripes {
            x: root.closable ? box.x + box.width + 6 : 6
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, label.x - 6 - x)
        }
        Stripes {
            x: label.x + label.width + 6
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - 6 - x)
        }
    }

    Item {
        id: body
        x: root.hair + root.padding
        y: root.hair + root.titleHeight + root.padding
        width: parent.width - 2 * root.hair - 2 * root.padding
        height: parent.height - y - root.hair - root.padding
    }
}
