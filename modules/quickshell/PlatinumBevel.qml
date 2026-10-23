import QtQuick

// A Platinum surface: an optional black edge, then a one-rule bevel. A
// raised surface is light at the top and left and dark at the bottom and
// right; a sunken one (a pressed button, a well) is the reverse. Every
// line is PlatinumTokens.hair thick, so it lands on whole physical pixels.
Rectangle {
    id: root

    property bool sunken: false
    property bool edged: true
    property color edgeColor: PlatinumTokens.menuEdge
    property color lightColor: PlatinumTokens.bevelLight
    property color darkColor: PlatinumTokens.bevelDark
    property bool bevelled: true

    readonly property real h: PlatinumTokens.hair
    readonly property real inset: edged ? h : 0

    color: PlatinumTokens.raised
    border.width: edged ? h : 0
    border.color: edgeColor

    // top and left
    Rectangle {
        visible: root.bevelled
        x: root.inset; y: root.inset
        width: root.width - 2 * root.inset; height: root.h
        color: root.sunken ? root.darkColor : root.lightColor
    }
    Rectangle {
        visible: root.bevelled
        x: root.inset; y: root.inset
        width: root.h; height: root.height - 2 * root.inset
        color: root.sunken ? root.darkColor : root.lightColor
    }
    // bottom and right
    Rectangle {
        visible: root.bevelled
        x: root.inset; y: root.height - root.inset - root.h
        width: root.width - 2 * root.inset; height: root.h
        color: root.sunken ? root.lightColor : root.darkColor
    }
    Rectangle {
        visible: root.bevelled
        x: root.width - root.inset - root.h; y: root.inset
        width: root.h; height: root.height - 2 * root.inset
        color: root.sunken ? root.lightColor : root.darkColor
    }
}
