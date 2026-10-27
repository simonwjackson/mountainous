pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "themes/win98/tab-strip.js" as TabStrip

// A Win98 property sheet: a row of tabs over a raised sheet. Tabs are
// 18 u tall with 2-u cut corners and overlap by 1 u; the current tab is
// 24 u tall (it rises 4 u above the others, as the mock draws it), 2 u
// wider on each side, its label 2 u higher, and opens into the sheet; the
// tab after it does not overlap it. Children go on the sheet, padUnits in
// from its edges. The sheet's top edge is 22 u below the item's top.
//
// Keys: Left/Right (and Ctrl+Tab, Ctrl+Shift+Tab) move between tabs and
// emit selected(index); the owner sets currentIndex. A tab's "&" letter is
// underlined. Focus: a dotted rectangle around the current tab's label.
//
// Narrow: when the tabs do not fit in one row they wrap into rows, as
// Win98's multi-row property sheets did. Each row is 20 u above the last
// (so the raised current tab never covers a label above it) and runs down
// behind the row below; its tabs stretch to the row's width. The row
// holding the current tab is the one on the sheet. A tab wider than the
// sheet elides its label.
//
// singleRow: the tabs stay in one row instead (Win98's tab control without
// multi-line). When they do not fit, the row scrolls: an up-down control
// at its right end moves the first tab shown (`firstTab`), and the current
// tab always shows (themes/win98/tab-strip.js).
FocusScope {
    id: root

    property var tabs: []              // labels; "&" marks the access key
    property int currentIndex: 0
    property bool showFocus: false
    property real padUnits: 8
    property bool singleRow: false
    property int firstTab: 0
    default property alias content: sheetBody.data

    signal selected(int index)

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    readonly property real strip: singleRow ? 24 * u : 24 * u + (rows.length - 1) * 20 * u
    readonly property Item first: sheetBody.children.length > 0 ? sheetBody.children[0] : null
    readonly property var tabWidths: tabs.map(t => Win98Tokens.ceilU(Win98Tokens.textWidth(Win98Tokens.plainText(t), false, root.u), root.u) + 14 * u)
    // Each tab's left edge in the row: 2 u in, every tab 1 u over the last,
    // except the one after the current tab.
    // One row: which tabs show (all of them while they fit).
    readonly property var line: TabStrip.tabStrip(tabWidths.map(w => Math.round(w / u)), Math.round(width / u), currentIndex, firstTab)
    readonly property bool scrolled: singleRow && line.mode === "scroll"
    readonly property var tabX: {
        const out = [];
        let x = 2 * u;
        const from = scrolled ? line.first : 0;
        for (let i = 0; i < tabWidths.length; i++) {
            if (i < from) { out.push(-1e6); continue; }
            out.push(x);
            x += tabWidths[i] - (i === currentIndex ? 0 : u);
        }
        return out;
    }
    function shown(i) { return !scrolled || (i >= line.first && i <= line.last); }
    readonly property real rowWidth: tabX.length ? tabX[tabX.length - 1] + tabWidths[tabWidths.length - 1] + 2 * u : 0
    readonly property bool wraps: !singleRow && width > 0 && rowWidth > width + 0.5
    // The rows, as lists of tab indexes, the current tab's row last.
    readonly property var rows: {
        if (!wraps) return [tabs.map((t, i) => i)];
        const avail = width - 4 * u;
        const out = [];
        let row = [], used = 0;
        for (let i = 0; i < tabWidths.length; i++) {
            if (row.length && used + tabWidths[i] - u > avail) { out.push(row); row = []; used = 0; }
            row.push(i);
            used += tabWidths[i] - (row.length > 1 ? u : 0);
        }
        if (row.length) out.push(row);
        const at = out.findIndex(r => r.indexOf(currentIndex) >= 0);
        return at < 0 ? out : out.slice(at + 1).concat(out.slice(0, at + 1));
    }
    // A tab's place when the row wraps: its row (0 is the top) and its
    // stretched x and width.
    function place(i) {
        const ri = rows.findIndex(r => r.indexOf(i) >= 0);
        const row = rows[ri];
        const avail = width - 4 * u;
        const total = row.reduce((a, j) => a + tabWidths[j], 0) - (row.length - 1) * u;
        const extra = Math.max(0, avail - total);
        let x = 2 * u;
        for (const j of row) {
            const share = Win98Tokens.snap(extra / row.length, u);
            const w = Math.min(avail, tabWidths[j] + share);
            if (j === i) return { row: ri, x: x, w: w };
            x += w - u;
        }
        return { row: ri, x: 2 * u, w: tabWidths[i] };
    }

    implicitWidth: Math.max(tabWidths.length ? Math.max(...tabWidths) + 4 * u : 0, first ? first.implicitWidth + 2 * padUnits * u : 0)
    implicitHeight: strip - 2 * u + (first ? first.implicitHeight : 0) + 2 * padUnits * u
    activeFocusOnTab: enabled

    Keys.onPressed: event => {
        const n = root.tabs.length;
        if (n === 0) return;
        let next = -1;
        if (event.key === Qt.Key_Right || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier))) next = (root.currentIndex + 1) % n;
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) next = (root.currentIndex - 1 + n) % n;
        if (next < 0) return;
        root.selected(next);
        event.accepted = true;
    }

    // The sheet: raised, its top edge 2 u under the tabs' bottom.
    Win98Bevel {
        id: sheet
        y: root.strip - 2 * root.u
        width: root.width
        height: root.height - y
        variant: "button"
    }
    Item {
        id: sheetBody
        x: root.padUnits * root.u
        y: sheet.y + root.padUnits * root.u
        width: root.width - 2 * root.padUnits * root.u
        height: sheet.height - 2 * root.padUnits * root.u
    }

    Repeater {
        model: root.tabs

        Item {
            id: tab
            required property string modelData
            required property int index
            readonly property bool current: index === root.currentIndex
            readonly property var spot: root.wraps ? root.place(index) : ({ row: 0, x: root.tabX[index], w: root.tabWidths[index] })
            // Rows above the sheet's row sit 20 u higher each.
            readonly property real rowTop: spot.row * 20 * root.u
            readonly property bool upper: spot.row < root.rows.length - 1
            readonly property real w: spot.w + (current ? 4 * root.u : 0)
            readonly property real h: (current ? 24 : upper ? 26 : 18) * root.u
            objectName: "tab" + index
            visible: root.shown(index)
            z: current ? 2 : upper ? 0 : 1
            x: Math.max(0, spot.x - (current ? 2 * root.u : 0))
            y: rowTop + (current ? 0 : 4 * root.u)
            // A scrolled row never draws a tab under its up-down control.
            width: root.scrolled ? Math.max(0, Math.min(w, updown.x - x)) : w
            height: h
            clip: root.scrolled && width < w
            // Face, then the edge pixel by pixel: the 2-u corners are cut
            // with one diagonal unit each, as Win98 drew them.
            Rectangle { x: 2 * root.u; y: 0; width: tab.w - 4 * root.u; height: root.u; color: Win98Tokens.hi }
            Rectangle { x: root.u; y: root.u; width: root.u; height: root.u; color: Win98Tokens.hi }
            Rectangle { x: 0; y: 2 * root.u; width: root.u; height: tab.h - 2 * root.u; color: Win98Tokens.hi }
            Rectangle { x: 2 * root.u; y: root.u; width: tab.w - 4 * root.u; height: root.u; color: Win98Tokens.li }
            Rectangle { x: root.u; y: 2 * root.u; width: root.u; height: tab.h - 2 * root.u; color: Win98Tokens.li }
            Rectangle { x: 2 * root.u; y: 2 * root.u; width: tab.w - 4 * root.u; height: tab.h - 2 * root.u; color: Win98Tokens.face }
            Rectangle { x: tab.w - 2 * root.u; y: root.u; width: root.u; height: root.u; color: Win98Tokens.dk }
            Rectangle { x: tab.w - root.u; y: 2 * root.u; width: root.u; height: tab.h - 2 * root.u; color: Win98Tokens.dk }
            Rectangle { x: tab.w - 2 * root.u; y: 2 * root.u; width: root.u; height: tab.h - 2 * root.u; color: Win98Tokens.sh }

            Win98Text {
                id: tabLabel
                objectName: "tabLabel" + tab.index
                x: (tab.current ? 9 : 7) * root.u
                y: (tab.current ? 5 : 3) * root.u    // 4.5 u and 2.5 u, snapped
                width: Math.max(0, Math.min(implicitWidth, tab.w - x - 5 * root.u))
                text: tab.modelData
            }
            Win98FocusRect {
                // The strip itself has the keyboard, not a control on the sheet.
                visible: tab.current && root.enabled && (root.showFocus || root.Window.activeFocusItem === root)
                x: tabLabel.x - root.u
                y: tabLabel.y - root.u
                width: tabLabel.width + 2 * root.u
                height: tabLabel.height + 2 * root.u
            }
            MouseArea {
                anchors.fill: parent
                onPressed: { root.forceActiveFocus(); root.selected(tab.index); }
            }
        }
    }

    // The scrolled row's up-down control: two arrow buttons at the right.
    Row {
        id: updown
        visible: root.scrolled
        x: root.width - width
        y: 4 * root.u
        Repeater {
            model: [-1, 1]
            Item {
                id: arrow
                required property int modelData
                readonly property bool can: arrow.modelData < 0 ? root.line.left : root.line.right
                readonly property bool down: area.pressed && area.containsMouse && can
                objectName: arrow.modelData < 0 ? "tabsLeft" : "tabsRight"
                width: 16 * root.u
                height: 16 * root.u
                Win98Bevel { anchors.fill: parent; variant: arrow.down ? "pressed" : "button" }
                Win98Icon {
                    name: arrow.modelData < 0 ? "arrow-left" : "arrow-right"
                    color: arrow.can ? Win98Tokens.text : Win98Tokens.gray
                    x: Win98Tokens.snap((arrow.width - width) / 2, root.u) + (arrow.down ? root.u : 0)
                    y: Win98Tokens.snap((arrow.height - height) / 2, root.u) + (arrow.down ? root.u : 0)
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    onClicked: if (arrow.can) root.firstTab = root.line.first + arrow.modelData
                }
            }
        }
    }
}
