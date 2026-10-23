import QtQuick
import QtQuick.Layouts

// A menu's list: as tall as its rows, until the menu runs out of screen,
// then it scrolls with a Platinum scroll bar on the menu's right edge.
// scrolls tells the frame to move its right edge in by the bar.
Item {
    id: root

    property alias view: list
    property alias model: list.model
    property alias delegate: list.delegate
    property alias currentIndex: list.currentIndex
    property alias count: list.count
    property alias spacing: list.spacing
    readonly property bool scrolls: scrollBar.needed

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: list.contentHeight
    implicitHeight: list.contentHeight

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        focus: true
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationWraps: true
        highlightMoveDuration: 0
        interactive: contentHeight > height
    }

    PlatinumScrollBar {
        id: scrollBar
        flickable: list
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    function moveSelection(offset) {
        if (list.count === 0) return;
        list.currentIndex = (list.currentIndex + offset + list.count) % list.count;
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
}
