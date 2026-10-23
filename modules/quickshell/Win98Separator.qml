import QtQuick

// An etched line: grey over white (horizontal) or grey beside white
// (vertical), 2 u thick, with margins: 3 u above and below and 2 u at the
// ends horizontally, as menus draw it; 1 u and 2 u vertically, as the
// taskbar's band breaks.
Item {
    id: root

    property int orientation: Qt.Horizontal
    readonly property real u: Win98Tokens.u
    readonly property bool vertical: orientation === Qt.Vertical

    implicitWidth: vertical ? 6 * u : 20 * u
    implicitHeight: vertical ? 20 * u : 8 * u

    Rectangle {
        x: root.vertical ? 2 * root.u : 2 * root.u
        y: root.vertical ? root.u : 3 * root.u
        width: root.vertical ? root.u : root.width - 4 * root.u
        height: root.vertical ? root.height - 2 * root.u : root.u
        color: Win98Tokens.sh
    }
    Rectangle {
        x: root.vertical ? 3 * root.u : 2 * root.u
        y: root.vertical ? root.u : 4 * root.u
        width: root.vertical ? root.u : root.width - 4 * root.u
        height: root.vertical ? root.height - 2 * root.u : root.u
        color: Win98Tokens.hi
    }
}
