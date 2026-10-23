import QtQuick

// One row of a Win98 list view.
//
// One line (16 u): mark or icon, title, value at the right edge. Two lines
// (34 u): a detail line in grey under the title, or a level bar (the
// Sound window). Selected: the selection colour, white text (the detail
// too); with keyboard focus, a dotted rectangle on the row's edge.
//
// Alignment: every title starts on one edge (markUnits + 4 u in) and every
// value ends on one edge; a value column takes the width of the role's
// widest value (valueUnits), so 9%, 42% and 100% share an edge.
Item {
    id: root

    property string title: ""
    property string detail: ""
    property string value: ""
    property string iconName: ""       // a 16-u icon
    property string mark: ""           // "dot" or "ring", in a 10-u column
    property bool bold: false
    property real level: -1            // 0..1 shows a level bar as line two
    property bool muted: false
    property color detailColor: Win98Tokens.gray
    property color titleColor: Win98Tokens.winText
    property real valueUnits: 34
    property bool selected: ListView.view ? ListView.isCurrentItem : false
    // The Win98ListView around the view, when the row is its delegate.
    readonly property Win98ListView list: ListView.view ? ListView.view.parent as Win98ListView : null
    property bool focused: selected && list !== null && list.focusShown

    signal clicked
    signal doubleClicked

    readonly property real u: Win98Tokens.u
    readonly property bool twoLine: detail !== "" || level >= 0
    readonly property real markWidth: iconName !== "" ? 16 * u : mark !== "" ? 10 * u : 0
    readonly property color ink: selected ? Win98Tokens.selectionText : titleColor

    width: ListView.view ? ListView.view.width : implicitWidth
    implicitWidth: 200 * u
    implicitHeight: (twoLine ? Win98Tokens.listRowTwo : Win98Tokens.listRow) * u

    Rectangle {
        anchors.fill: parent
        color: root.selected ? Win98Tokens.selection : "transparent"
    }

    Item {
        id: markCell
        visible: root.markWidth > 0
        x: 3 * root.u
        width: root.markWidth
        height: root.height
        Win98Icon {
            name: root.iconName !== "" ? root.iconName : root.mark
            color: root.ink
            x: Win98Tokens.snap((markCell.width - width) / 2)
            y: Win98Tokens.snap((markCell.height - height) / 2)
        }
    }

    Column {
        id: textColumn
        x: 3 * root.u + (root.markWidth > 0 ? root.markWidth + 4 * root.u : 0)
        width: (root.value !== "" ? valueText.x - 4 * root.u : root.width - 3 * root.u) - x
        y: Win98Tokens.snap((root.height - height) / 2)
        spacing: root.level >= 0 ? 3 * root.u : 0

        Win98Text {
            width: Math.min(implicitWidth, textColumn.width)
            text: root.title
            accessMarks: false
            bold: root.bold
            color: root.ink
        }
        Win98Text {
            visible: root.detail !== "" && root.level < 0
            width: Math.min(implicitWidth, textColumn.width)
            text: root.detail
            accessMarks: false
            color: root.selected ? Win98Tokens.selectionText : root.detailColor
        }
        Win98LevelBar {
            visible: root.level >= 0
            width: textColumn.width
            value: root.level
            muted: root.muted
            onSelection: root.selected
        }
    }

    Win98Text {
        id: valueText
        visible: root.value !== ""
        x: root.width - 3 * root.u - width
        y: Win98Tokens.snap((root.height - height) / 2)
        width: Math.max(implicitWidth, root.valueUnits * root.u)
        horizontalAlignment: Text.AlignRight
        text: root.value
        accessMarks: false
        color: root.ink
    }

    Win98FocusRect {
        visible: root.focused
        anchors.fill: parent
        color: Win98Tokens.selectionText
    }

    // The row's index, from the view (the delegate may not declare one).
    function rowIndex() { return root.ListView.view ? root.ListView.view.indexAt(root.x + 1, root.y + 1) : -1; }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            const view = root.ListView.view;
            if (view) view.currentIndex = root.rowIndex();
            if (root.list) root.list.forceActiveFocus();
            root.clicked();
        }
        onDoubleClicked: {
            root.doubleClicked();
            if (root.list) root.list.activated(root.rowIndex());
        }
    }
}
