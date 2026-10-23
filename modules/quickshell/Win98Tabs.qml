pragma ComponentBehavior: Bound

import QtQuick

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
FocusScope {
    id: root

    property var tabs: []              // labels; "&" marks the access key
    property int currentIndex: 0
    property bool showFocus: false
    property real padUnits: 8
    default property alias content: sheetBody.data

    signal selected(int index)

    readonly property real u: Win98Tokens.u
    readonly property real strip: 24 * u
    readonly property Item first: sheetBody.children.length > 0 ? sheetBody.children[0] : null
    readonly property var tabWidths: tabs.map(t => Win98Tokens.ceilU(Win98Tokens.textWidth(Win98Tokens.plainText(t), false)) + 14 * u)
    // Each tab's left edge in the row: 2 u in, every tab 1 u over the last,
    // except the one after the current tab.
    readonly property var tabX: {
        const out = [];
        let x = 2 * u;
        for (let i = 0; i < tabWidths.length; i++) { out.push(x); x += tabWidths[i] - (i === currentIndex ? 0 : u); }
        return out;
    }
    readonly property real rowWidth: tabX.length ? tabX[tabX.length - 1] + tabWidths[tabWidths.length - 1] + 2 * u : 0

    implicitWidth: Math.max(rowWidth, first ? first.implicitWidth + 2 * padUnits * u : 0)
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
            readonly property real w: root.tabWidths[index] + (current ? 4 * root.u : 0)
            readonly property real h: (current ? 24 : 18) * root.u
            z: current ? 2 : 1
            x: root.tabX[index] - (current ? 2 * root.u : 0)
            y: current ? 0 : 4 * root.u
            width: w
            height: h

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
                x: (tab.current ? 9 : 7) * root.u
                y: (tab.current ? 5 : 3) * root.u    // 4.5 u and 2.5 u, snapped
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
}
