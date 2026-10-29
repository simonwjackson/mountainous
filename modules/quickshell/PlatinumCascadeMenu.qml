import Quickshell
import Hensou as Kit
import QtQuick
import QtQuick.Window
import "themes/platinum/menu-models.js" as Menus

// A Platinum menu drawn from rows (themes/platinum/menu-models.js), with
// cascading submenus. The Apple menu, the Application menu and a Control
// Strip tile's menu use it. PlatinumMenuHost places the first panel; each
// cascade opens beside the row that owns it, on the right, or on the left
// when the right has no room, and moves up or down to stay on screen.
//
// One selection runs through every level: the pointer and the arrow keys
// move it. Right (or a pause on the row) opens a cascade, Left closes it,
// Enter chooses, and Escape closes the innermost cascade first.
Item {
    id: root

    property var items: []
    // A row kept highlighted from outside: the app Super+Tab is on.
    property string highlightId: ""
    // PlatinumMenuHost's frame interface.
    property real preferredWidth: 0
    property real menuWidth: 0
    property real maxHeight: 600
    // Hang from the right end of its title (the Application menu), or open
    // upward with its bottom edge here, in window coordinates (a strip tile).
    property bool alignRight: false
    property real bottomY: -1
    signal closeRequested
    signal activated(var row)

    readonly property real hair: Kit.PlatinumTokens.hairFor(QsWindow.window)
    // levelRows[k] are the rows of panel k; selections[k] its selected row.
    // Panel k + 1 is the cascade of panel k's selected row. The two are kept
    // apart so moving the selection never rebuilds a panel's rows (which
    // would recreate the row under the pointer).
    property var levelRows: [root.items]
    property var selections: [-1]
    readonly property int depth: levelRows.length - 1
    onItemsChanged: {
        // The rows change under an open menu (a window closes, a title
        // changes): keep the open path while its rows still match by id.
        const rows = [root.items], sel = [Math.min(root.selections[0], root.items.length - 1)];
        for (let k = 1; k < root.levelRows.length; k++) {
            const owner = rows[k - 1][sel[k - 1]];
            const old = root.levelRows[k - 1][root.selections[k - 1]];
            if (!owner || !old || owner.id !== old.id || !owner.submenu) break;
            rows.push(owner.submenu);
            sel.push(Math.min(root.selections[k], owner.submenu.length - 1));
        }
        root.levelRows = rows;
        root.selections = sel;
    }
    onHighlightIdChanged: syncHighlight()
    Component.onCompleted: syncHighlight()
    function syncHighlight() {
        if (root.highlightId === "") return;
        const i = root.items.findIndex(function (r) { return r.id === root.highlightId; });
        if (i >= 0) root.select(0, i, false);
    }

    width: panels.count > 0 && panels.itemAt(0) ? panels.itemAt(0).width : 200
    height: panels.count > 0 && panels.itemAt(0) ? panels.itemAt(0).height : 40
    implicitHeight: height
    focus: true

    // ------------------------------------------------------------ actions
    function truncate(level) {
        if (root.levelRows.length > level + 1) {
            root.levelRows = root.levelRows.slice(0, level + 1);
            root.selections = root.selections.slice(0, level + 1);
        }
    }
    function setSelection(level, index) {
        if (root.selections[level] === index) return;
        const sel = root.selections.slice();
        sel[level] = index;
        root.selections = sel;
    }
    // The pointer (openSoon) keeps an open cascade until it rests on the new
    // row, so a diagonal move into a cascade does not close it on the way.
    // The keyboard closes deeper cascades at once.
    function select(level, index, openSoon) {
        if (level > root.depth) return;
        if (openSoon) {
            if (level < root.depth && root.selections[level] === index) { opener.stop(); return; }
            root.setSelection(level, index);
            opener.level = level;
            opener.index = index;
            opener.restart();
        } else {
            root.truncate(level);
            root.setSelection(level, index);
        }
    }
    function openCascade(level, index, selectFirst) {
        opener.stop();
        if (level > root.depth) return;
        const row = root.levelRows[level][index];
        root.truncate(level);
        root.setSelection(level, index);
        if (row && row.kind === "item" && row.submenu && row.submenu.length > 0 && !row.disabled) {
            root.levelRows = root.levelRows.concat([row.submenu]);
            root.selections = root.selections.concat([selectFirst ? Menus.nextEnabled(row.submenu, -1, 1) : -1]);
        }
    }
    function choose(level, index) {
        const row = root.levelRows[level] ? root.levelRows[level][index] : null;
        if (!row || row.kind !== "item" || row.disabled) return;
        if (row.submenu && row.submenu.length > 0) { root.openCascade(level, index, true); return; }
        opener.stop();
        if (row.action) { SoundEvents.requested("menuChoose"); root.activated(row); }
    }
    // Escape: the innermost cascade first, then the menu (the host closes it).
    function cancel() {
        if (root.depth > 0) { root.truncate(root.depth - 1); return true; }
        return false;
    }

    Timer {
        id: opener
        property int level: 0
        property int index: -1
        interval: 140
        onTriggered: root.openCascade(level, index, false)
    }

    Keys.onPressed: function (event) {
        const depth = root.depth;
        const here = { rows: root.levelRows[depth], selected: root.selections[depth] };
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
            const i = Menus.nextEnabled(here.rows, here.selected < 0 && event.key === Qt.Key_Up ? here.rows.length : here.selected,
                event.key === Qt.Key_Down ? 1 : -1);
            if (i >= 0) root.select(depth, i, false);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            if (here.selected >= 0) root.openCascade(depth, here.selected, true);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            if (depth > 0) root.truncate(depth - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (here.selected >= 0) root.choose(depth, here.selected);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            // Reached with a modifier held (Super during Super+Tab); a bare
            // Escape is the host's shortcut.
            if (!root.cancel()) root.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
            const i = Menus.nextEnabled(here.rows, event.key === Qt.Key_Home ? -1 : here.rows.length, event.key === Qt.Key_Home ? 1 : -1);
            if (i >= 0) root.select(depth, i, false);
            event.accepted = true;
        }
    }

    // ------------------------------------------------------------ panels
    // The window the menu draws in (the host's full-screen menu window) and
    // where the first panel sits in it.
    readonly property real originX: parent ? parent.x : 0
    readonly property real originY: parent ? parent.y : 0
    readonly property real areaWidth: root.Window.width > 0 ? root.Window.width : 1920
    readonly property real areaHeight: root.Window.height > 0 ? root.Window.height : 1200
    readonly property real topLimit: Kit.PlatinumTokens.barHeight - Kit.PlatinumTokens.hairFor(QsWindow.window)

    // Every panel lives in one item as large as the window, so a cascade
    // beside the first panel is inside its parent's bounds.
    Item {
        id: area
        x: -root.originX
        y: -root.originY
        width: root.areaWidth
        height: root.areaHeight

    Repeater {
        id: panels
        model: root.levelRows.length

        Panel {
            required property int index
            level: index
            rows: root.levelRows[index] || []
            selected: root.selections[index] !== undefined ? root.selections[index] : -1
            widthCap: index === 0 && root.menuWidth > 0 ? Math.min(root.menuWidth, 380) : Math.min(380, root.areaWidth - 8)
            heightCap: index === 0 ? root.maxHeight : root.areaHeight - root.topLimit - 8
            x: root.originX + panelX
            y: root.originY + panelY
            readonly property real panelX: {
                if (index === 0) return 0;
                const parentPanel = panels.itemAt(index - 1);
                if (!parentPanel) return 0;
                const right = parentPanel.panelX + parentPanel.width - 4;
                const left = parentPanel.panelX - width + 4;
                const gx = root.originX;
                if (gx + right + width <= root.areaWidth - 2) return right;
                if (gx + left >= 2) return left;
                // Neither side fits: over the parent, inside the screen.
                return Math.max(2 - gx, Math.min(right, root.areaWidth - 2 - gx - width));
            }
            readonly property real panelY: {
                if (index === 0) return 0;
                const parentPanel = panels.itemAt(index - 1);
                if (!parentPanel) return 0;
                const wanted = parentPanel.panelY + parentPanel.rowTop(parentPanel.selected) - 4 - root.hair;
                const gy = root.originY;
                const top = root.topLimit - gy;
                const bottom = root.areaHeight - 4 - gy - height;
                return Math.max(top, Math.min(wanted, bottom));
            }
        }
    }
    }

    // One panel: the Platinum menu box with its rows.
    component Panel: Item {
        id: panel

        property int level: 0
        property var rows: []
        property int selected: -1
        property real widthCap: 380
        property real heightCap: 600

        readonly property bool iconColumn: rows.some(function (r) { return r.kind === "item" && (r.icon || r.app || r.spacer); })
        // As the mock: gutter 30, gap 8, a 16 px icon pulled 4 px into the
        // gap, gap 8.
        readonly property real labelX: iconColumn ? 58 : Kit.PlatinumTokens.menuTextLeft + Kit.PlatinumTokens.menuGap
        // Each row needs its label and its trailing marks (count, hint, ▸);
        // the panel is as wide as its widest row, as a Mac OS menu is.
        function trailOf(r) {
            let t = 0;
            if (r.count) t += Kit.PlatinumMetrics.smallWidth(String(r.count)) + Kit.PlatinumTokens.menuGap;
            if (r.hint) t += Kit.PlatinumMetrics.smallWidth(r.hint) + Kit.PlatinumTokens.menuGap;
            if (r.submenu) t += 7 + Kit.PlatinumTokens.menuGap;
            return t;
        }
        readonly property real naturalWidth: {
            let w = 200;
            for (const r of rows) {
                if (r.kind === "item")
                    w = Math.max(w, labelX + Kit.PlatinumMetrics.width(r.label || "") + Kit.PlatinumTokens.menuGap + trailOf(r)
                        + Kit.PlatinumTokens.menuRightInset + 2 * root.hair);
                else if (r.kind === "header")
                    w = Math.max(w, Math.min(340, 36 + Kit.PlatinumMetrics.width(r.label || "") + Kit.PlatinumTokens.menuRightInset));
            }
            return Kit.PlatinumMetrics.even(w);
        }
        readonly property real contentHeight: {
            let h = 0;
            for (let i = 0; i < rows.length; i++) h += rowHeight(rows[i]);
            return h;
        }
        width: Math.max(120, Math.min(naturalWidth, widthCap))
        height: Math.min(contentHeight + 4 + 5 + 2 * root.hair, Math.max(60, heightCap))
        readonly property bool scrolls: contentHeight + 9 + 2 * root.hair > height + 0.5

        function rowHeight(r) {
            if (!r) return 0;
            if (r.kind === "separator") return 4 + 2 * root.hair + 5;
            if (r.kind === "header") return headerHeight(r);
            return Kit.PlatinumTokens.menuLine;
        }
        function headerHeight(r) {
            const lines = Kit.PlatinumMetrics.width(r.label || "") > panel.width - 48 ? 2 : 1;
            return 8 + lines * 18 + (r.detail ? 16 : 0) + 4;
        }
        // A row's top edge inside the panel, as drawn (after scrolling).
        function rowTop(index) {
            let h = 4 + root.hair;
            for (let i = 0; i < index && i < rows.length; i++) h += rowHeight(rows[i]);
            return h - list.contentY;
        }

        // The hard shadow, one rule down and right.
        Rectangle {
            x: 2 * root.hair
            y: 2 * root.hair
            width: parent.width
            height: parent.height
            color: Kit.PlatinumTokens.menuShadow
        }
        PlatinumBevel {
            anchors.fill: parent
            color: Kit.PlatinumTokens.menuSurface
        }

        Flickable {
            id: list
            x: root.hair
            y: root.hair + 4
            width: panel.width - 2 * root.hair - (panel.scrolls ? Kit.PlatinumTokens.menuScrollBar : 0)
            height: panel.height - 2 * root.hair - 4 - 5
            contentHeight: panel.contentHeight
            clip: panel.scrolls
            interactive: panel.scrolls
            boundsBehavior: Flickable.StopAtBounds
            onContentYChanged: root.truncate(panel.level)

            Column {
                width: list.width
                Repeater {
                    // A count, not the array: a new array with the same rows
                    // must not recreate the row under the pointer.
                    model: panel.rows.length
                    delegate: MenuRow {
                        owner: panel
                        required property int index
                        row: panel.rows[index] || ({})
                        rowIndex: index
                        width: list.width
                        height: panel.rowHeight(row)
                    }
                }
            }
        }

        PlatinumScrollBar {
            visible: panel.scrolls
            flickable: list
            anchors.right: parent.right
            anchors.rightMargin: root.hair
            y: list.y
            height: list.height
        }

        // One pointer area per panel, over its rows: it finds the row under
        // the pointer itself. Per-row hover areas lost the first hover after
        // a cascade appeared beside its parent (measured in the nested
        // session: the parent row got "exited", the cascade row no "entered").
        // Clicks inside a panel stay inside it.
        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: panel.scrolls ? Kit.PlatinumTokens.menuScrollBar + root.hair : 0
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onWheel: function (w) { w.accepted = false; }
            function rowAt(my) {
                const y = my - list.y + list.contentY;
                let top = 0;
                for (let i = 0; i < panel.rows.length; i++) {
                    const h = panel.rowHeight(panel.rows[i]);
                    if (y >= top && y < top + h) return i;
                    top += h;
                }
                return -1;
            }
            function track(my) {
                const i = rowAt(my);
                const r = i >= 0 ? panel.rows[i] : null;
                if (r && r.kind === "item" && !r.disabled && panel.selected !== i) root.select(panel.level, i, true);
            }
            onEntered: track(mouseY)
            onPositionChanged: function (mouse) { track(mouse.y); }
            onClicked: function (mouse) {
                if (mouse.button !== Qt.LeftButton && mouse.button !== Qt.RightButton) return;
                const i = rowAt(mouse.y);
                if (i >= 0) root.choose(panel.level, i);
            }
        }

    }

    // One row.
    component MenuRow: Item {
        id: rowItem
        property var owner: null
        property var row: ({})
        property int rowIndex: -1
        readonly property bool isItem: row.kind === "item"
        readonly property bool lit: isItem && !row.disabled
            && (owner.selected === rowIndex || (owner.level === 0 && row.highlight === true && owner.selected < 0))
        readonly property color fg: row.disabled ? Kit.PlatinumTokens.menuTextOff : lit ? Kit.PlatinumTokens.highlightText : Kit.PlatinumTokens.menuText
        readonly property color fg2: row.disabled ? Kit.PlatinumTokens.menuTextOff : lit ? Kit.PlatinumTokens.highlightText : Kit.PlatinumTokens.menuTextSecondary

        // A separator: an etched rule, dark over light.
        Rectangle {
            visible: rowItem.row.kind === "separator"
            y: 4; width: parent.width; height: root.hair
            color: Kit.PlatinumTokens.bevelDark
        }
        Rectangle {
            visible: rowItem.row.kind === "separator"
            y: 4 + root.hair; width: parent.width; height: root.hair
            color: Kit.PlatinumTokens.bevelLight
        }

        // A header: the window a tile's menu is about, with its icon.
        Item {
            visible: rowItem.row.kind === "header"
            anchors.fill: parent
            PlatinumAppIcon {
                x: 8; y: 6
                size: 20
                name: rowItem.row.app || ""
                visible: name !== ""
                surface: Kit.PlatinumTokens.menuSurface
            }
            Column {
                x: 36; y: 4
                width: parent.width - x - Kit.PlatinumTokens.menuRightInset
                spacing: 2
                Text {
                    width: parent.width
                    text: rowItem.row.label || ""
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 1.1
                    color: Kit.PlatinumTokens.menuText
                    font.family: Kit.PlatinumTokens.platinumFont
                    font.pixelSize: Kit.PlatinumTokens.platinumText
                    font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                }
                Text {
                    visible: text !== ""
                    width: parent.width
                    text: rowItem.row.detail || ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Kit.PlatinumTokens.menuTextSecondary
                    font.family: Kit.PlatinumTokens.platinumFont
                    font.pixelSize: Kit.PlatinumTokens.platinumSmall
                    font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                }
            }
        }

        // An item.
        Item {
            visible: rowItem.isItem
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                visible: rowItem.lit
                color: Kit.PlatinumTokens.highlight
            }
            PlatinumIcon {
                visible: rowItem.row.check === true
                x: (Kit.PlatinumTokens.menuTextLeft - width) / 2 - 2
                anchors.verticalCenter: parent.verticalCenter
                name: "check"
                size: 12
                color: rowItem.fg
            }
            PlatinumIcon {
                visible: !!rowItem.row.icon
                x: 34
                anchors.verticalCenter: parent.verticalCenter
                name: rowItem.row.icon || ""
                size: 16
                color: rowItem.fg
                knock: rowItem.lit ? Kit.PlatinumTokens.highlight : Kit.PlatinumTokens.menuSurface
            }
            PlatinumAppIcon {
                visible: !rowItem.row.icon && !!rowItem.row.app
                x: 34
                anchors.verticalCenter: parent.verticalCenter
                size: 16
                name: rowItem.row.app || ""
                inactive: rowItem.row.dim === true
                surface: rowItem.lit ? Kit.PlatinumTokens.highlight : Kit.PlatinumTokens.menuSurface
            }
            Text {
                x: owner.labelX
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, trail.x - x - Kit.PlatinumTokens.menuGap)
                text: rowItem.row.label || ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: rowItem.fg
                font.family: Kit.PlatinumTokens.platinumFont
                font.pixelSize: Kit.PlatinumTokens.platinumText
                font.letterSpacing: Kit.PlatinumTokens.platinumTracking
            }
            Row {
                id: trail
                anchors.right: parent.right
                anchors.rightMargin: Kit.PlatinumTokens.menuRightInset - 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: Kit.PlatinumTokens.menuGap
                Text {
                    visible: !!rowItem.row.count
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(rowItem.row.count || "")
                    color: rowItem.fg2
                    font.family: Kit.PlatinumTokens.platinumFont
                    font.pixelSize: Kit.PlatinumTokens.platinumSmall
                    font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                }
                Text {
                    visible: !!rowItem.row.hint
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowItem.row.hint || ""
                    color: rowItem.fg2
                    font.family: Kit.PlatinumTokens.platinumFont
                    font.pixelSize: Kit.PlatinumTokens.platinumSmall
                    font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                }
                PlatinumIcon {
                    visible: !!rowItem.row.submenu
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 10
                    name: "submenu"
                    color: rowItem.fg
                }
            }
        }

    }
}
