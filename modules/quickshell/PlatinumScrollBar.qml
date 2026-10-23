import QtQuick

// A Platinum scroll bar for one Flickable: a sunken track with a raised
// thumb. It shows only while the content is taller than the view, so a
// list that fits keeps its full width. Drag the thumb, or click the track
// to page.
Item {
    id: root

    required property Flickable flickable
    readonly property bool needed: flickable.contentHeight > flickable.height + 1

    visible: needed
    width: Theme.menuScrollBar - Theme.hair

    readonly property real span: Math.max(1, flickable.contentHeight - flickable.height)
    readonly property real thumbHeight: Math.max(18, height * flickable.height / Math.max(1, flickable.contentHeight))
    readonly property real thumbY: (height - thumbHeight)
        * Math.min(1, Math.max(0, (flickable.contentY - flickable.originY) / span))

    Rectangle {
        anchors.fill: parent
        color: Theme.well
        Rectangle {
            width: Theme.hair
            height: parent.height
            color: Theme.bevelDark
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: function (mouse) {
            const page = flickable.height * 0.9;
            const top = flickable.originY;
            const bottom = flickable.originY + root.span;
            const next = flickable.contentY + (mouse.y < root.thumbY ? -page : page);
            flickable.contentY = Math.max(top, Math.min(bottom, next));
        }
    }

    Bevel {
        id: thumb
        x: 0
        width: parent.width
        y: root.thumbY
        height: root.thumbHeight
        color: drag.pressed ? Theme.well : Theme.raised

        MouseArea {
            id: drag
            anchors.fill: parent
            preventStealing: true
            property real startY: 0
            property real startContent: 0
            onPressed: function (mouse) {
                startY = mapToItem(root, mouse.x, mouse.y).y;
                startContent = flickable.contentY;
            }
            onPositionChanged: function (mouse) {
                if (!pressed) return;
                const dy = mapToItem(root, mouse.x, mouse.y).y - startY;
                const room = Math.max(1, root.height - root.thumbHeight);
                const next = startContent + dy * root.span / room;
                flickable.contentY = Math.max(flickable.originY,
                    Math.min(flickable.originY + root.span, next));
            }
        }
    }
}
