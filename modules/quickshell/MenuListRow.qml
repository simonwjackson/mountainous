import QtQuick

// One item in a menu list, on the menu grid:
//
//   gutter  its mark: ● (on, default, connected), ○, ✓, or an icon
//   text    its name, and a detail line under it
//   right   its value or buttons, ending on the right edge
//
// The selected row inverts to the highlight, as a Mac OS menu item does.
// The pointer selects the row it is over, so the pointer and the arrow
// keys move one selection.
Item {
    id: root

    property string mark: ""
    property bool markDim: false
    property string name: ""
    property string detail: ""
    property color nameColor: Theme.menuText
    property color detailColor: Theme.menuTextSecondary
    property bool selected: false
    property real rightInset: Theme.menuRightInset
    property real rowHeight: detail !== "" ? Theme.menuRow : Theme.menuLine
    default property alias trailing: trailingRow.data
    property alias below: belowItem.data
    readonly property real textRight: trailingRow.width > 0
        ? trailingRow.x - Theme.menuGap : width - rightInset
    readonly property color fg: selected ? Theme.highlightText : nameColor
    readonly property color fg2: selected ? Theme.highlightText : detailColor
    signal entered
    signal clicked
    signal doubleClicked

    readonly property real belowHeight: belowItem.childrenRect.height > 0
        ? belowItem.childrenRect.height + 4 : 0
    implicitHeight: rowHeight

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        visible: root.selected
        color: Theme.highlight
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.entered()
        onClicked: root.clicked()
        onDoubleClicked: root.doubleClicked()
    }

    PlatinumIcon {
        visible: root.mark !== ""
        x: Theme.menuGutter + (Theme.menuGutterWidth - width) / 2
        // On the name's line, not the row's middle.
        y: textColumn.y + (nameText.height - height) / 2
        name: root.mark
        size: 12
        color: root.selected ? Theme.highlightText : root.markDim ? Theme.menuTextOff : Theme.menuText
    }

    Column {
        id: textColumn
        x: Theme.menuTextLeft
        y: Math.round((root.rowHeight - height - root.belowHeight) / 2)
        width: Math.max(0, root.textRight - x)
        spacing: 1

        Text {
            id: nameText
            width: parent.width
            text: root.name
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.fg
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
            color: root.fg2
            font.family: Theme.platinumFont
            font.pixelSize: Theme.platinumSmall
            font.letterSpacing: Theme.platinumTracking
        }
    }

    Item {
        id: belowItem
        x: Theme.menuTextLeft
        y: textColumn.y + textColumn.height + 4
        width: Math.max(0, root.textRight - x)
    }

    Row {
        id: trailingRow
        anchors.right: parent.right
        anchors.rightMargin: root.rightInset
        y: (root.rowHeight - height) / 2
        spacing: Theme.menuGap
    }
}
