pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

// A Win98 list view: a sunken white well, 2 u of padding, the rows, and a
// scroll bar 2 u to the right of them when the rows do not fit. An empty
// list shows emptyText, centred and grey, saying what to do.
//
// Scrolling moves whole rows (rowUnits per step), so rows stay on the unit
// grid; the wheel and the scroll bar both step. Up/Down/Home/End/Page keys
// move currentIndex and keep it in view; activated(index) on Enter or a
// double click. Use Win98ListRow as the delegate; it reads the view's
// currentIndex and focus through ListView.view.
FocusScope {
    id: root

    property alias model: view.model
    property alias delegate: view.delegate
    property alias currentIndex: view.currentIndex
    property alias view: view
    property alias count: view.count
    property real rowUnits: Win98Tokens.listRowTwo
    property string emptyText: ""
    // Draw the current row's focus mark without keyboard focus (galleries).
    property bool showFocus: false
    readonly property bool focusShown: showFocus || activeFocus

    signal activated(int index)

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    readonly property real step: rowUnits * u
    readonly property bool overflows: view.contentHeight > view.height + 0.5

    implicitWidth: 200 * u
    implicitHeight: 4 * u + 5 * step
    activeFocusOnTab: true

    Keys.onPressed: event => {
        const n = view.count;
        if (n === 0) return;
        const page = Math.max(1, Math.floor(view.height / root.step) - 1);
        let i = view.currentIndex;
        if (event.key === Qt.Key_Down) i = Math.min(n - 1, i + 1);
        else if (event.key === Qt.Key_Up) i = Math.max(0, i - 1);
        else if (event.key === Qt.Key_Home) i = 0;
        else if (event.key === Qt.Key_End) i = n - 1;
        else if (event.key === Qt.Key_PageDown) i = Math.min(n - 1, i + page);
        else if (event.key === Qt.Key_PageUp) i = Math.max(0, i - page);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.activated(i); event.accepted = true; return; }
        else return;
        view.currentIndex = i;
        root.reveal(i);
        event.accepted = true;
    }

    // Keep row i in view, scrolling by whole rows.
    function reveal(i) {
        const item = view.itemAtIndex(i);
        const top = item ? item.y : i * root.step;
        const bottom = top + (item ? item.height : root.step);
        let y = view.contentY;
        if (top < y) y = top;
        else if (bottom > y + view.height) y = bottom - view.height;
        y = Math.ceil(y / root.step - 1e-6) * root.step;
        view.contentY = Math.max(0, Math.min(y, Math.max(0, view.contentHeight - view.height)));
    }

    Win98Bevel {
        anchors.fill: parent
        variant: "field"
        color: Win98Tokens.win
    }

    ListView {
        id: view
        x: 2 * root.u; y: 2 * root.u
        width: root.width - 4 * root.u - (root.overflows ? Win98Tokens.scrollBar * root.u + 2 * root.u : 0)
        height: root.height - 4 * root.u
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: false
        currentIndex: -1
        focus: true

        WheelHandler {
            onWheel: event => {
                const d = event.angleDelta.y > 0 ? -1 : 1;
                const max = Math.max(0, view.contentHeight - view.height);
                view.contentY = Math.max(0, Math.min(max, Math.round(view.contentY / root.step + d) * root.step));
            }
        }
    }

    Win98ScrollBar {
        visible: root.overflows
        x: root.width - 2 * root.u - width
        y: 2 * root.u
        height: root.height - 4 * root.u
        flickable: view
        step: root.step
    }

    Win98Text {
        visible: view.count === 0 && root.emptyText !== ""
        x: 12 * root.u
        width: root.width - 24 * root.u
        y: Win98Tokens.snap((root.height - height) / 2, root.u)
        wrap: true
        horizontalAlignment: Text.AlignHCenter
        text: root.emptyText
        accessMarks: false
        color: Win98Tokens.gray
    }
}
