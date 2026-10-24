import QtQuick

// A Mac OS 8 utility window (a windoid): a black edge and a one-rule bevel,
// a 16-px striped title bar with a close box on the left and a WindowShade
// box on the right, and a hard shadow one rule down and right. WindowShade
// rolls it up to its title bar. Drag the title bar to move it; the host
// decides what moving means (a layer surface's margins, a place in the
// glance space) through dragged(dx, dy).
Item {
    id: root

    property string title: ""
    property color titleColor: PlatinumTokens.menuText
    // A status light before the title (the Fleet summary when shaded).
    property string lightShape: ""
    property string lightTone: "normal"
    // Stripes show only on the front windoid, as on Mac OS.
    property bool front: true
    property bool shaded: false
    property bool closable: true
    property bool shadeable: true
    property string closeLabel: "Close"
    // The body's height, from the content.
    property real bodyHeight: 0
    default property alias body: bodyItem.data
    signal closeClicked
    signal shadeClicked
    signal dragged(real dx, real dy)
    signal dragFinished
    signal activated

    readonly property real h: PlatinumTokens.hair
    readonly property real titleHeight: PlatinumGlanceTokens.titleHeight
    // Everything that is not body: edges, bevel, title, the title's rule.
    readonly property real chromeHeight: 4 * h + titleHeight + (shaded ? 0 : h)
    readonly property real chromeWidth: 4 * h
    readonly property real contentWidth: width - chromeWidth

    implicitHeight: chromeHeight + (shaded ? 0 : bodyHeight)

    // A press anywhere brings the windoid to the front.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: function (mouse) { root.activated(); mouse.accepted = false; }
    }

    Rectangle {
        x: root.h
        y: root.h
        width: parent.width
        height: parent.height
        color: PlatinumTokens.menuShadow
    }

    PlatinumBevel {
        anchors.fill: parent
        color: PlatinumTokens.menuSurface
    }

    Item {
        id: titleBar
        x: 2 * root.h
        y: 2 * root.h
        width: parent.width - 4 * root.h
        height: root.titleHeight

        MouseArea {
            anchors.fill: parent
            property real pressX: 0
            property real pressY: 0
            preventStealing: true
            onPressed: function (mouse) { root.activated(); pressX = mouse.x; pressY = mouse.y; }
            onPositionChanged: function (mouse) {
                if (pressed) root.dragged(mouse.x - pressX, mouse.y - pressY);
            }
            onReleased: root.dragFinished()
            onDoubleClicked: if (root.shadeable) root.shadeClicked()
        }

        component Box: PlatinumBevel {
            id: box
            property bool held: false
            width: PlatinumGlanceTokens.boxSize
            height: PlatinumGlanceTokens.boxSize
            anchors.verticalCenter: parent.verticalCenter
            sunken: held
            color: held ? PlatinumTokens.well : PlatinumTokens.raised
        }

        component Stripes: Item {
            height: 8 * root.h
            anchors.verticalCenter: parent.verticalCenter
            visible: root.front && width > 0
            Repeater {
                model: 3
                Item {
                    required property int index
                    width: parent.width
                    y: index * 3 * root.h
                    height: 2 * root.h
                    Rectangle { width: parent.width; height: root.h; color: PlatinumTokens.bevelLight }
                    Rectangle { y: root.h; width: parent.width; height: root.h; color: PlatinumTokens.bevelDark }
                }
            }
        }

        Box {
            id: closeBox
            visible: root.closable
            x: 4
            held: closeArea.pressed && closeArea.containsMouse
            MouseArea {
                id: closeArea
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                onClicked: root.closeClicked()
            }
        }

        Box {
            id: shadeBox
            visible: root.shadeable
            anchors.right: parent.right
            anchors.rightMargin: 4
            held: shadeArea.pressed && shadeArea.containsMouse
            Rectangle { x: 2 * root.h; y: 3 * root.h; width: parent.width - 4 * root.h; height: root.h; color: PlatinumTokens.menuEdge }
            Rectangle { x: 2 * root.h; y: 5 * root.h; width: parent.width - 4 * root.h; height: root.h; color: PlatinumTokens.menuEdge }
            MouseArea {
                id: shadeArea
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                onClicked: root.shadeClicked()
            }
        }

        readonly property real leftEdge: root.closable ? closeBox.x + closeBox.width + 4 : 4
        readonly property real rightEdge: root.shadeable ? shadeBox.x - 4 : width - 4
        readonly property real room: Math.max(0, rightEdge - leftEdge)
        readonly property real labelWidth: Math.min(label.implicitWidth, Math.max(0, room - 12))

        Stripes {
            x: titleBar.leftEdge
            width: Math.max(0, label.x - 4 - x)
        }

        Row {
            id: label
            spacing: 5
            x: titleBar.leftEdge + Math.max(6, (titleBar.room - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            readonly property real lightRoom: root.lightShape !== "" ? 12 + spacing : 0
            width: Math.min(implicitWidth, Math.max(0, titleBar.room - 12))
            clip: true

            PlatinumStatusLight {
                visible: root.lightShape !== ""
                anchors.verticalCenter: parent.verticalCenter
                shape: root.lightShape
                tone: root.lightTone
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Math.max(0, titleBar.room - 12 - label.lightRoom))
                text: root.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.titleColor
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
        }

        Stripes {
            x: label.x + label.width + 4
            width: Math.max(0, titleBar.rightEdge - x)
        }
    }

    // The title's rule.
    Rectangle {
        visible: !root.shaded
        x: 2 * root.h
        y: titleBar.y + titleBar.height
        width: parent.width - 4 * root.h
        height: root.h
        color: PlatinumTokens.menuEdge
    }

    Item {
        id: bodyItem
        visible: !root.shaded
        x: 2 * root.h
        y: titleBar.y + titleBar.height + root.h
        width: parent.width - 4 * root.h
        height: root.bodyHeight
        clip: true
    }
}
