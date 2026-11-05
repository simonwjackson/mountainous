pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import QtQuick

// A Memphis drop-down list (CBS_DROPDOWNLIST).
//
// Closed: a 21-u sunken white field with the value and a 16 x 17 u button
// with the arrow. Focused, the value takes the selection colours and a
// dotted rectangle. Open: the button presses in and a list with a 1-u
// black edge drops below, the current item highlighted.
//
// The list escapes clipping: while open it is reparented to `overlay`
// (default: the window's content item). It shows at most maxRows rows and
// scrolls the rest, with a scroll bar, as Memphis's lists did. It drops
// below the field, or rises above it when there is more room there; on a
// short window it shrinks to the room (one row at least) and scrolls, so
// every item stays reachable. bottomInset keeps it off a strip at the
// window's foot (the taskbar under the picker).
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
    property int maxRows: 10
    property real bottomInset: 0

    signal activated(int index)

    readonly property real u: Kit.MemphisTokens.unitFor(QsWindow.window)
    readonly property bool focusShown: enabled && (showFocus || activeFocus)
    property int highlighted: currentIndex
    readonly property real rowHeight: 15 * u
    readonly property real listRow: 17 * u
    // Rows the open list shows; place() sets it from the room.
    property int shownRows: Math.min(root.model.length, root.maxRows)
    readonly property bool listScrolls: shownRows < root.model.length

    implicitWidth: Kit.MemphisTokens.ceilU(Kit.MemphisTokens.widest(model, false, root.u), root.u) + 4 * u + 23 * u + 4 * u
    implicitHeight: Kit.MemphisTokens.fieldHeight * u
    activeFocusOnTab: enabled

    onOpenChanged: {
        highlighted = currentIndex;
        if (open) { place(); replace.restart(); }
    }
    // A host that scrolls the field into view when it takes the focus
    // moves it after the list opened: place the list again once it has.
    Timer { id: replace; interval: 40; onTriggered: if (root.open) root.place() }
    // The open list is at least as wide as its longest item (and its
    // scroll bar), as Memphis's drop-down lists could be, so a narrow field
    // still shows whole names; never wider than the window.
    readonly property real listWidth: Math.max(root.width, Kit.MemphisTokens.ceilU(Kit.MemphisTokens.widest(root.model, false, root.u), root.u)
        + 8 * root.u + 2 * root.u + (root.listScrolls ? Kit.MemphisTokens.scrollBar * root.u : 0))
    onHighlightedChanged: reveal()
    // Keep the highlighted row inside the list's view.
    function reveal() {
        if (!root.open) return;
        const top = root.highlighted * root.listRow;
        let y = view.contentY;
        if (top < y) y = top;
        else if (top + root.listRow > y + view.height) y = top + root.listRow - view.height;
        view.contentY = Math.max(0, Math.min(Math.max(0, view.contentHeight - view.height), y));
    }

    function choose(i) {
        if (i < 0 || i >= root.model.length) return;
        root.activated(i);
        root.currentIndex = i;
        root.open = false;
    }
    function place() {
        const host = root.overlay || root.Window.contentItem;
        if (!host) return;
        list.parent = host;
        const p = root.mapToItem(host, 0, root.height);
        const top = root.mapToItem(host, 0, 0).y;
        const n = root.model.length;
        const want = Math.max(1, Math.min(n, root.maxRows));
        const fit = room => Math.max(0, Math.floor((room - 2 * root.u + 1e-6) / root.listRow));
        const area = host.height - root.bottomInset;
        const below = fit(area - p.y), above = fit(top);
        const up = below < want && above > below;
        root.shownRows = Math.max(1, Math.min(want, up ? above : below));
        list.width = Math.min(root.listWidth, host.width);
        list.x = Kit.MemphisTokens.snap(Math.max(0, Math.min(p.x, host.width - list.width)), root.u);
        // No room for a row on either side: the one row lies over the
        // field, inside the window's usable height.
        const cramped = below < 1 && above < 1;
        list.y = Kit.MemphisTokens.snap(cramped ? Math.max(0, Math.min(top, area - list.height))
            : up ? top - list.height : p.y, root.u);
        view.contentY = 0;
        root.reveal();
    }

    Keys.onPressed: event => {
        const n = root.model.length;
        if (root.open) {
            const page = Math.max(1, root.shownRows - 1);
            if (event.key === Qt.Key_Down) root.highlighted = Math.min(n - 1, root.highlighted + 1);
            else if (event.key === Qt.Key_Up) root.highlighted = Math.max(0, root.highlighted - 1);
            else if (event.key === Qt.Key_PageDown) root.highlighted = Math.min(n - 1, root.highlighted + page);
            else if (event.key === Qt.Key_PageUp) root.highlighted = Math.max(0, root.highlighted - page);
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

    // The value box: 3 u in, up to the button.
    Rectangle {
        id: valueBox
        x: 3 * root.u; y: 3 * root.u
        width: Math.max(0, root.width - 3 * root.u - 2 * root.u - 16 * root.u - 2 * root.u)
        height: root.rowHeight
        color: root.focusShown ? Kit.MemphisTokens.selection : "transparent"
        // A field narrower than its value cuts it here, not past the button.
        clip: true

        MemphisText {
            x: 2 * root.u; y: root.u
            width: valueBox.width - 4 * root.u
            text: root.model.length > root.currentIndex && root.currentIndex >= 0 ? root.model[root.currentIndex] : ""
            accessMarks: false
            color: root.focusShown ? Kit.MemphisTokens.selectionText : Kit.MemphisTokens.winText
            disabledLook: !root.enabled
        }
        MemphisFocusRect {
            visible: root.focusShown
            anchors.fill: parent
            color: Kit.MemphisTokens.selectionText
        }
    }

    Item {
        id: button
        x: root.width - 2 * root.u - width
        y: 2 * root.u
        width: 16 * root.u
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
        height: root.shownRows * root.listRow + 2 * root.u

        Rectangle {
            anchors.fill: parent
            color: Kit.MemphisTokens.win
            border.width: root.u
            border.color: Kit.MemphisTokens.dk
        }
        Flickable {
            id: view
            x: root.u; y: root.u
            width: list.width - 2 * root.u - (root.listScrolls && root.shownRows >= 2 ? Kit.MemphisTokens.scrollBar * root.u : 0)
            height: root.shownRows * root.listRow
            contentWidth: width
            contentHeight: root.model.length * root.listRow
            interactive: false
            clip: true
            WheelHandler {
                onWheel: event => {
                    const max = Math.max(0, view.contentHeight - view.height);
                    view.contentY = Math.max(0, Math.min(max, view.contentY - Math.sign(event.angleDelta.y) * 3 * root.listRow));
                }
            }
            Column {
                Repeater {
                    model: root.model
                    Rectangle {
                        id: row
                        required property string modelData
                        required property int index
                        width: view.width
                        height: root.listRow
                        color: index === root.highlighted ? Kit.MemphisTokens.selection : "transparent"
                        MemphisText {
                            x: 4 * root.u; y: root.u
                            width: row.width - 8 * root.u
                            text: row.modelData
                            accessMarks: false
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
        // Below two rows the arrows would not fit: the wheel and the keys
        // still scroll the list.
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
