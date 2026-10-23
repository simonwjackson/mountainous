pragma ComponentBehavior: Bound

import QtQuick

// A Win98 drop-down list (CBS_DROPDOWNLIST).
//
// Closed: a 21-u sunken white field with the value and a 16 x 17 u button
// with the arrow. Focused, the value takes the selection colours and a
// dotted rectangle. Open: the button presses in and a list with a 1-u
// black edge drops below, the current item highlighted.
//
// The list escapes clipping: while open it is reparented to `overlay`
// (default: the window's content item). A host that must leave the window
// (a list taller than the room below) should give it a popup surface.
//
// Keys: Up/Down change the value (closed) or the highlight (open);
// Alt+Down, F4 or Space opens; Enter takes the highlight; Esc closes.
FocusScope {
    id: root

    property var model: []             // strings; "&" is literal
    property int currentIndex: 0
    property bool open: false
    property bool showFocus: false
    property Item overlay: null

    signal activated(int index)

    readonly property real u: Win98Tokens.u
    readonly property bool focusShown: enabled && (showFocus || activeFocus)
    property int highlighted: currentIndex
    readonly property real rowHeight: 15 * u
    readonly property real listRow: 17 * u

    implicitWidth: Win98Tokens.ceilU(Win98Tokens.widest(model, false)) + 4 * u + 23 * u + 4 * u
    implicitHeight: Win98Tokens.fieldHeight * u
    activeFocusOnTab: enabled

    onOpenChanged: {
        highlighted = currentIndex;
        if (open) place();
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
        list.x = Win98Tokens.snap(p.x);
        list.y = Win98Tokens.snap(p.y);
    }

    Keys.onPressed: event => {
        const n = root.model.length;
        if (root.open) {
            if (event.key === Qt.Key_Down) root.highlighted = Math.min(n - 1, root.highlighted + 1);
            else if (event.key === Qt.Key_Up) root.highlighted = Math.max(0, root.highlighted - 1);
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

    Win98Bevel {
        anchors.fill: parent
        variant: "field"
        color: root.enabled ? Win98Tokens.win : Win98Tokens.face
    }

    // The value box: 3 u in, up to the button.
    Rectangle {
        id: valueBox
        x: 3 * root.u; y: 3 * root.u
        width: root.width - 3 * root.u - 2 * root.u - 16 * root.u - 2 * root.u
        height: root.rowHeight
        color: root.focusShown ? Win98Tokens.selection : "transparent"

        Win98Text {
            x: 2 * root.u; y: root.u
            width: valueBox.width - 4 * root.u
            text: root.model.length > root.currentIndex && root.currentIndex >= 0 ? root.model[root.currentIndex] : ""
            accessMarks: false
            color: root.focusShown ? Win98Tokens.selectionText : Win98Tokens.winText
            disabledLook: !root.enabled
        }
        Win98FocusRect {
            visible: root.focusShown
            anchors.fill: parent
            color: Win98Tokens.selectionText
        }
    }

    Item {
        id: button
        x: root.width - 2 * root.u - width
        y: 2 * root.u
        width: 16 * root.u
        height: 17 * root.u
        Win98Bevel {
            anchors.fill: parent
            variant: root.open ? "pressed" : "button"
        }
        Win98Icon {
            name: "arrow-down"
            color: root.enabled ? Win98Tokens.text : Win98Tokens.gray
            x: Win98Tokens.snap((button.width - width) / 2) + (root.open ? root.u : 0)
            y: Win98Tokens.snap((button.height - height) / 2) + (root.open ? root.u : 0)
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onPressed: { root.forceActiveFocus(); root.open = !root.open; }
    }

    Item {
        id: list
        visible: root.open
        z: 1000
        width: root.width
        height: root.model.length * root.listRow + 2 * root.u

        Rectangle {
            anchors.fill: parent
            color: Win98Tokens.win
            border.width: root.u
            border.color: Win98Tokens.dk
        }
        Column {
            x: root.u; y: root.u
            Repeater {
                model: root.model
                Rectangle {
                    id: row
                    required property string modelData
                    required property int index
                    width: list.width - 2 * root.u
                    height: root.listRow
                    color: index === root.highlighted ? Win98Tokens.selection : "transparent"
                    Win98Text {
                        x: 4 * root.u; y: root.u
                        width: row.width - 8 * root.u
                        text: row.modelData
                        accessMarks: false
                        color: row.index === root.highlighted ? Win98Tokens.selectionText : Win98Tokens.winText
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
}
