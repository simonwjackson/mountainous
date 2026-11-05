pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import QtQuick
import "themes/memphis/combo-plan.js" as Plan

// A Memphis drop-down list (CBS_DROPDOWNLIST).
//
// Closed: a 21-u sunken white field with the value and a 16 x 17 u button
// with the arrow. Focused, the value takes the selection colours and a
// dotted rectangle. Open: the button presses in and a list with a 1-u
// black edge drops below, the current item highlighted.
//
// Every name stays readable at every size. A value wider than its box
// wraps, and the field grows a line at a time; a field too narrow for a
// value box beside the button stacks the button under the value. The open
// list is as wide as its longest name needs, up to the window; narrower
// than that, its names wrap and their rows grow.
//
// The list escapes clipping: while open it is reparented to `overlay`
// (default: the window's content item). It shows at most maxRows single
// rows' worth and scrolls the rest, with a scroll bar, as Memphis's lists
// did. Where it goes is combo-plan.js's place(): below the field, above
// it when there is more room there, shortened to the room, or over the
// field when neither side holds a row. bottomInset keeps it off a strip
// at the window's foot (the taskbar under the picker).
//
// Keys: Up/Down change the value (closed) or the highlight (open);
// Page Up/Down, Home and End move the highlight a page or to an end;
// Alt+Down, F4 or Space opens; Enter takes the highlight; Esc closes.
// The highlighted row is always scrolled into view.
FocusScope {
    id: root

    property var model: []             // strings; "&" is literal
    property int currentIndex: 0
    property bool open: false
    property bool showFocus: false
    property Item overlay: null
    property int maxRows: Plan.MAX_ROWS
    property real bottomInset: 0

    signal activated(int index)

    readonly property real u: Kit.MemphisTokens.unitFor(QsWindow.window)
    readonly property bool focusShown: enabled && (showFocus || activeFocus)
    property int highlighted: currentIndex
    readonly property real listRow: Plan.ROW * u
    readonly property string value: root.model.length > root.currentIndex && root.currentIndex >= 0 ? root.model[root.currentIndex] : ""

    // The field: its widths from the width alone, its heights from the
    // lines the value needs at that width (two calls, so no loop).
    readonly property var shape: Plan.field(root.width / root.u, 1)
    readonly property int valueLines: Math.max(1, Math.round(valueText.implicitHeight / (Kit.MemphisTokens.lineUnits * root.u)))
    readonly property var sized: Plan.field(root.width / root.u, root.valueLines)

    // The open list, as place() last set it.
    property bool listScrolls: false
    property real listTextWidth: 1

    implicitWidth: Kit.MemphisTokens.ceilU(Kit.MemphisTokens.widest(model, false, root.u), root.u) + 4 * u + 23 * u + 4 * u
    implicitHeight: sized.height * u
    activeFocusOnTab: enabled

    onOpenChanged: {
        highlighted = currentIndex;
        if (open) { place(); replace.restart(); }
    }
    onHighlightedChanged: reveal()
    onWidthChanged: if (open) replace.restart()
    // A host that scrolls the field into view when it takes the focus
    // moves it after the list opened: place the list again once it has.
    Timer { id: replace; interval: 40; onTriggered: if (root.open) root.place() }

    function rowHeights() {
        const out = [];
        for (let i = 0; i < rowRepeater.count; i++) {
            const it = rowRepeater.itemAt(i);
            out.push(it ? it.height / root.u : Plan.ROW);
        }
        return out;
    }
    // Keep the highlighted row inside the list's view.
    function reveal() {
        if (!root.open) return;
        view.contentY = Plan.reveal(root.rowHeights(), root.highlighted, view.contentY / root.u, view.height / root.u) * root.u;
    }
    function choose(i) {
        if (i < 0 || i >= root.model.length) return;
        root.activated(i);
        root.currentIndex = i;
        root.open = false;
    }
    // Size the list for the window, then let the policy place it. A list
    // that scrolls gives its scroll bar room, which can rewrap its names,
    // so the width is settled first and checked once.
    function place() {
        const host = root.overlay || root.Window.contentItem;
        if (!host) return;
        list.parent = host;
        const u = root.u;
        const top = root.mapToItem(host, 0, 0).y / u;
        const fieldBottom = root.mapToItem(host, 0, root.height).y / u;
        const x = root.mapToItem(host, 0, 0).x / u;
        const widest = Kit.MemphisTokens.widest(root.model, false, u) / u;
        let scrolls = root.model.length > root.maxRows;
        let p = null;
        for (let pass = 0; pass < 2; pass++) {
            const w = Plan.listWidth(root.width / u, widest, host.width / u, scrolls);
            list.width = w * u;
            root.listScrolls = scrolls;
            root.listTextWidth = Plan.rowTextWidth(w, scrolls) * u;
            p = Plan.place({ rows: root.rowHeights(), fieldTop: top, fieldBottom: fieldBottom,
                area: (host.height - root.bottomInset) / u, maxRows: root.maxRows });
            if (p.scrolls === scrolls) break;
            scrolls = p.scrolls;
        }
        list.height = p.height * u;
        view.height = p.view * u;
        list.x = Kit.MemphisTokens.snap(Math.max(0, Math.min(x * u, host.width - list.width)), u);
        list.y = Kit.MemphisTokens.snap(p.y * u, u);
        view.contentY = 0;
        root.reveal();
    }

    Keys.onPressed: event => {
        const n = root.model.length;
        if (root.open) {
            if (event.key === Qt.Key_Down) root.highlighted = Math.min(n - 1, root.highlighted + 1);
            else if (event.key === Qt.Key_Up) root.highlighted = Math.max(0, root.highlighted - 1);
            else if (event.key === Qt.Key_PageDown) root.highlighted = Plan.page(root.rowHeights(), root.highlighted, view.height / root.u, 1);
            else if (event.key === Qt.Key_PageUp) root.highlighted = Plan.page(root.rowHeights(), root.highlighted, view.height / root.u, -1);
            else if (event.key === Qt.Key_Home) root.highlighted = 0;
            else if (event.key === Qt.Key_End) root.highlighted = n - 1;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.choose(root.highlighted);
            else if (event.key === Qt.Key_Escape || event.key === Qt.Key_F4) root.open = false;
            else return;
        } else {
            if ((event.key === Qt.Key_Down && (event.modifiers & Qt.AltModifier)) || event.key === Qt.Key_F4 || event.key === Qt.Key_Space) root.open = true;
            else if (event.key === Qt.Key_Down && root.currentIndex < n - 1) root.choose(root.currentIndex + 1);
            else if (event.key === Qt.Key_Up && root.currentIndex > 0) root.choose(root.currentIndex - 1);
            else return;
        }
        event.accepted = true;
    }

    MemphisBevel {
        anchors.fill: parent
        variant: "field"
        color: root.enabled ? Kit.MemphisTokens.win : Kit.MemphisTokens.face
    }

    // The value box: 3 u in; beside the button, or above it when stacked.
    Rectangle {
        id: valueBox
        objectName: "comboValue"
        x: Plan.INSET * root.u; y: Plan.INSET * root.u
        width: root.shape.valueWidth * root.u
        height: root.sized.valueHeight * root.u
        color: root.focusShown ? Kit.MemphisTokens.selection : "transparent"

        MemphisText {
            id: valueText
            x: 2 * root.u; y: root.u
            width: Math.max(root.u, valueBox.width - 4 * root.u)
            text: root.value
            accessMarks: false
            wrap: true
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            elide: Text.ElideNone
            color: root.focusShown ? Kit.MemphisTokens.selectionText : Kit.MemphisTokens.winText
            disabledLook: !root.enabled
        }
        MemphisFocusRect {
            visible: root.focusShown && valueBox.width > 0
            anchors.fill: parent
            color: Kit.MemphisTokens.selectionText
        }
    }

    Item {
        id: button
        x: root.shape.buttonX * root.u
        y: root.sized.buttonY * root.u
        width: Plan.BUTTON * root.u
        height: 17 * root.u
        MemphisBevel {
            anchors.fill: parent
            variant: root.open ? "pressed" : "button"
        }
        MemphisIcon {
            name: "arrow-down"
            color: root.enabled ? Kit.MemphisTokens.text : Kit.MemphisTokens.gray
            x: Kit.MemphisTokens.snap((button.width - width) / 2, root.u) + (root.open ? root.u : 0)
            y: Kit.MemphisTokens.snap((button.height - height) / 2, root.u) + (root.open ? root.u : 0)
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onPressed: { root.forceActiveFocus(); root.open = !root.open; }
    }

    Item {
        id: list
        objectName: "comboList"
        visible: root.open
        z: 1000
        width: root.width
        height: root.listRow + 2 * root.u

        Rectangle {
            anchors.fill: parent
            color: Kit.MemphisTokens.win
            border.width: root.u
            border.color: Kit.MemphisTokens.dk
        }
        Flickable {
            id: view
            x: root.u; y: root.u
            width: list.width - 2 * root.u - (root.listScrolls ? Kit.MemphisTokens.scrollBar * root.u : 0)
            height: root.listRow
            contentWidth: width
            contentHeight: rows.height
            interactive: false
            clip: true
            WheelHandler {
                onWheel: event => {
                    const max = Math.max(0, view.contentHeight - view.height);
                    view.contentY = Math.max(0, Math.min(max, view.contentY - Math.sign(event.angleDelta.y) * 3 * root.listRow));
                }
            }
            Column {
                id: rows
                Repeater {
                    id: rowRepeater
                    model: root.model
                    Rectangle {
                        id: row
                        required property string modelData
                        required property int index
                        objectName: "comboRow" + index
                        width: view.width
                        // One line is Memphis's 17-u row; a wrapped name adds a line.
                        height: Math.max(root.listRow, rowText.implicitHeight + 4 * root.u)
                        color: index === root.highlighted ? Kit.MemphisTokens.selection : "transparent"
                        MemphisText {
                            id: rowText
                            x: 4 * root.u; y: root.u
                            width: root.listTextWidth
                            text: row.modelData
                            accessMarks: false
                            wrap: true
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            elide: Text.ElideNone
                            color: row.index === root.highlighted ? Kit.MemphisTokens.selectionText : Kit.MemphisTokens.winText
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.highlighted = row.index
                            onClicked: root.choose(row.index)
                        }
                    }
                }
            }
        }
        // Below two rows' height the arrows would not fit: the wheel and
        // the keys still scroll the list.
        MemphisScrollBar {
            visible: root.listScrolls && view.height >= 2 * Kit.MemphisTokens.scrollBar * root.u
            x: list.width - root.u - width
            y: root.u
            width: Kit.MemphisTokens.scrollBar * root.u
            height: view.height
            flickable: view
            step: root.listRow
        }
    }
}
