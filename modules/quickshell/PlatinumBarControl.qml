import QtQuick

// One title on the top bar: an icon and an optional readout, with three
// looks. At rest it is flat. Under the pointer it takes a light tint.
// Pressed, or while its menu is open, it inverts to the highlight, as a
// Mac OS 8 menu title does. The bar has no focus ring: Super+O is its
// keyboard path.
//
// A control with a menu (menu !== "") opens it on press, closes it on a
// second press, and takes over from another open menu when the pointer
// arrives (sticky menus). A control without a menu runs activated().
Item {
    id: root

    property string menu: ""
    property var screen: null
    property bool open: false
    property string icon: ""
    property real iconWidth: 16
    property real iconHeight: 16
    property bool slashed: false
    property color tone: PlatinumTokens.barText
    property real pad: 8
    property bool hoverable: true
    default property alias readout: readoutRow.data
    property alias readoutRow: readoutRow
    property alias iconItem: iconBox
    // Marks drawn over the icon: the battery fill and bolt, a badge.
    property alias iconExtras: iconExtrasItem.data
    signal activated
    signal wheel(real delta)

    readonly property bool hovered: area.containsMouse
    readonly property bool held: area.pressed
    readonly property bool inverted: open || (held && menu === "")
    // Colours for children: the readout follows the inversion.
    readonly property color fg: inverted ? PlatinumTokens.highlightText : tone
    readonly property color bg: inverted ? PlatinumTokens.highlight
        : hovered && hoverable ? Qt.tint(PlatinumTokens.barSurface, PlatinumTokens.barHover) : PlatinumTokens.barSurface

    implicitWidth: PlatinumMetrics.even(pad * 2 + content.implicitWidth)
    implicitHeight: PlatinumTokens.barHeight - PlatinumTokens.hair

    // Hover lays a translucent tint over the bar instead of a flat fill,
    // so the bevel under the title still shows. Where the bar is flat it
    // gives the colour the old Qt.tint fill gave.
    Rectangle {
        anchors.fill: parent
        color: root.inverted ? root.bg : root.hovered && root.hoverable ? PlatinumTokens.barHover : "transparent"
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: readoutRow.children.length > 0 && readoutRow.implicitWidth > 0 ? 6 : 0

        Item {
            id: iconBox
            visible: root.iconWidth > 0
            width: root.iconWidth
            height: root.iconHeight
            anchors.verticalCenter: parent.verticalCenter

            PlatinumIcon {
                anchors.fill: parent
                name: root.icon
                color: root.fg
                knock: root.bg
            }

            PlatinumIcon {
                visible: root.slashed
                anchors.centerIn: parent
                name: "slash"
                size: 16
                color: root.fg
                knock: root.bg
            }

            Item {
                id: iconExtrasItem
                anchors.fill: parent
            }
        }

        Row {
            id: readoutRow
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        // A right-click opens a title's menu too.
        acceptedButtons: root.menu === "" ? Qt.LeftButton : Qt.LeftButton | Qt.RightButton
        onPressed: {
            if (root.menu === "") return;
            MenuState.toggle(root.menu, root.screen, root.mapToItem(null, 0, 0).x);
        }
        onClicked: if (root.menu === "") root.activated()
        onWheel: function (event) { root.wheel(event.angleDelta.y); }
        onEntered: {
            if (root.menu === "" || MenuState.current === "" || MenuState.current === root.menu) return;
            if (MenuState.screen !== root.screen) return;
            if (root.open) return;
            MenuState.open(root.menu, root.screen, root.mapToItem(null, 0, 0).x);
        }
    }
}
