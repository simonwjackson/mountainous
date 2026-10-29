pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import Quickshell.Widgets
import QtQuick
import "lanes.js" as Lanes
import "find-model.js" as FindModel
import "themes/win98/find-plan.js" as Plan
import "themes/win98/start-model.js" as StartModel
import "app-icon.js" as AppIcon

// Win98's Find window: Super+P, F1, Start ▸ Find and Start ▸ Run… open it
// above the Start button. It is the Win98 view of the omni service
// (OmniBar.qml), as the Find menu is Platinum's: the same rows from
// find-model.js (windows by screen, Recent Applications, Commands), the
// same scopes and the same keys, drawn as Start ▸ Find ▸ Files or Folders
// was: a Named field, Look in (the four scopes and Go to Address…), Open
// and Close, a Details list and a status bar. The list filters as you
// type (Win98 waited for Find Now) and keeps its height while you type
// (Win98 dialogs did not resize). Win98 list views had no groups, so the
// groups are rows: a bold label on the face colour and an etched rule.
//
// Keys, as find-model.js and the Platinum menu: Up/Down/Page move, Enter
// or Open runs the row, Ctrl+1/2/3 pick a scope, Ctrl+L opens Go to
// Address, Alt+Down or F4 opens Look in; Esc and Backspace on an empty
// field leave the scope, then close; a held Backspace stops at the empty
// field. A chosen row goes back to the Desktop, which runs it through the
// service on the next turn of the event loop.
//
// Layout: themes/win98/find-plan.js findPlan(), in units of the room
// above the taskbar. The host places the window at placeX, placeY.
FocusScope {
    id: root
    focus: true

    required property var omni
    // The room above the taskbar, logical px (the menu host's window).
    property real areaWidth: 1920
    property real areaHeight: 1160
    // A row was chosen, or a request ("address", "close") made.
    signal action(string kind, var arg)

    readonly property real u: Kit.Win98Tokens.unitFor(QsWindow.window)
    readonly property var plan: Plan.findPlan(Math.floor(root.areaWidth / root.u + 1e-6), Math.floor(root.areaHeight / root.u + 1e-6))
    readonly property real placeX: root.plan.x * root.u
    readonly property real placeY: root.plan.y * root.u

    readonly property string scope: FindModel.scopeOf(root.omni.mode)
    readonly property string query: root.omni.query || ""

    // A window's or an app's Win98 icon when the set has one, else "".
    function win98Icon(id, name) { return StartModel.appIcon(id, name); }
    readonly property var ctx: ({
        windows: (root.omni.windowRows || []).map(function (r) {
            return { label: r.label, page: r.page, shown: !!r.shown, screen: r.screen, order: r.order, appId: r.appId || "",
                     icon: r.appId || "", ref: r };
        }),
        here: root.omni.screen ? root.omni.screen.name : "",
        screenLabel: Lanes.screenLabel,
        apps: (root.omni.appRows || []).map(function (a) {
            return { label: a.label, id: a.entry && a.entry.id ? a.entry.id : "", generic: a.detail || "",
                     icon: a.entry && a.entry.icon ? a.entry.icon : "", ref: a };
        }),
        recent: Launcher.recent,
        commands: root.omni.commandRows || []
    })
    readonly property var rows: FindModel.findRows(root.scope, root.query, root.ctx)

    // The selection. Until a key or a click moves it, it follows the first
    // row Enter would run, so Super+P, Enter goes back to the last window.
    property int current: -1
    property bool moved: false
    property string rowsKey: ""
    Timer {
        id: selectionReveal
        interval: 0
        onTriggered: root.reveal()
    }
    onRowsChanged: {
        const key = root.scope + "\u0000" + root.query;
        if (key !== root.rowsKey) { root.rowsKey = key; root.moved = false; list.contentY = 0; root.tipIndex = -1; }
        // Read here, not from a binding on rows: a binding may not have run yet.
        if (!root.moved || !FindModel.selectable(root.rows[root.current])) root.current = FindModel.firstSelectable(root.rows);
        selectionReveal.restart();
    }
    Component.onCompleted: {
        field.text = root.query;
        root.rowsKey = root.scope + "\u0000" + root.query;
        root.current = FindModel.firstSelectable(root.rows);
    }
    Connections {
        target: root.omni
        function onQueryChanged() { if (field.text !== root.query) field.text = root.query; }
    }
    Connections {
        target: field.input
        function onTextEdited() { root.omni.query = field.text; }
    }

    readonly property var statusInfo: Plan.status(root.rows, root.current)
    // How far the list is scrolled, and whether the chosen row is whole in it.
    readonly property real scrollY: list.contentY
    readonly property bool currentInView: {
        if (root.current < 0) return false;
        const top = Plan.rowTop(root.rows, root.current) * root.u;
        return top >= list.contentY - 0.5 && top + 16 * root.u <= list.contentY + list.height + 0.5;
    }

    function reveal() {
        const top = Plan.scrollFor(root.rows, root.current, list.contentY / root.u, root.plan.list, FindModel.firstSelectable(root.rows));
        list.contentY = Math.max(0, Math.min(top * root.u, list.contentHeight - list.height));
    }
    function select(i) {
        if (i < 0) return;
        root.current = i;
        root.moved = true;
        root.reveal();
    }
    function move(dir) { root.select(FindModel.step(root.rows, root.current, dir)); }
    function movePage(dir) {
        root.select(FindModel.page(root.rows, root.current, dir, Math.max(1, Math.floor(root.plan.list / 16) - 1)));
    }
    function choose(i) {
        const r = root.rows[i];
        if (!FindModel.selectable(r)) return;
        root.action("row", r);
    }
    function setScope(id) {
        root.dropOpen = false;
        root.omni.enterMode(FindModel.modeOf(id));
    }
    // Esc and Backspace on an empty field: Look in's list first, then the
    // scope (back to All), then the window closes.
    function back() {
        root.tipIndex = -1;
        if (root.dropOpen) { root.dropOpen = false; return; }
        if (root.scope !== "all") { root.omni.back(); return; }
        root.action("close", null);
    }

    function key(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        root.tipIndex = -1;
        if (root.dropOpen) {
            if (event.key === Qt.Key_Down) root.dropStep(1);
            else if (event.key === Qt.Key_Up && !alt) root.dropStep(-1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.chooseDrop(root.dropIndex);
            else if (event.key === Qt.Key_Escape || event.key === Qt.Key_F4 || (alt && event.key === Qt.Key_Up)) root.dropOpen = false;
            else return;
            event.accepted = true;
            return;
        }
        if (ctrl && event.key === Qt.Key_1) { root.setScope("app"); event.accepted = true; return; }
        if (ctrl && event.key === Qt.Key_2) { root.setScope("win"); event.accepted = true; return; }
        if (ctrl && event.key === Qt.Key_3) { root.setScope("cmd"); event.accepted = true; return; }
        if (ctrl && event.key === Qt.Key_L) { root.action("address", root.query); event.accepted = true; return; }
        if ((alt && event.key === Qt.Key_Down) || event.key === Qt.Key_F4) { root.dropOpen = true; event.accepted = true; return; }
        switch (event.key) {
        case Qt.Key_Down: root.move(1); event.accepted = true; return;
        case Qt.Key_Up: root.move(-1); event.accepted = true; return;
        case Qt.Key_PageDown: root.movePage(1); event.accepted = true; return;
        case Qt.Key_PageUp: root.movePage(-1); event.accepted = true; return;
        case Qt.Key_Return: case Qt.Key_Enter: root.choose(root.current); event.accepted = true; return;
        case Qt.Key_Escape: root.back(); event.accepted = true; return;
        case Qt.Key_Backspace:
            if (field.text === "") {
                // A held Backspace stops at the empty field; a new press leaves.
                if (!event.isAutoRepeat) root.back();
                event.accepted = true;
            }
            return;
        }
    }
    Keys.onPressed: event => root.key(event)

    // ------------------------------------------------------------ Look in
    property bool dropOpen: false
    property int dropIndex: 0
    readonly property var dropRows: FindModel.SCOPES.map(function (s) { return { id: s.id, label: s.label, key: s.key }; })
        .concat([{ id: "" }, { id: "address", label: "Go to Address...", key: "Ctrl+L" }])
    onDropOpenChanged: {
        if (dropOpen) dropIndex = Math.max(0, root.dropRows.findIndex(function (r) { return r.id === root.scope; }));
        root.settle();
    }
    function dropStep(d) {
        let i = root.dropIndex;
        do { i = (i + d + root.dropRows.length) % root.dropRows.length; } while (!root.dropRows[i].id);
        root.dropIndex = i;
    }
    function chooseDrop(i) {
        const r = root.dropRows[i];
        if (!r || !r.id) return;
        root.dropOpen = false;
        if (r.id === "address") root.action("address", root.query);
        else root.setScope(r.id);
    }

    Shortcut { sequence: "Alt+N"; context: Qt.WindowShortcut; onActivated: { root.dropOpen = false; field.forceActiveFocus(); } }
    Shortcut { sequence: "Alt+L"; context: Qt.WindowShortcut; onActivated: { field.forceActiveFocus(); root.dropOpen = !root.dropOpen; } }
    Shortcut { sequence: "Alt+O"; context: Qt.WindowShortcut; onActivated: root.choose(root.current) }

    // ------------------------------------------------------------ the in-place tip
    // A cut name shows in full over its row while the pointer rests on it,
    // as Win98 list views showed a cut label.
    property int tipIndex: -1
    property int tipCandidate: -1
    Timer {
        id: tipTimer
        interval: 500
        onTriggered: {
            const item = rowRepeater.itemAt(root.tipCandidate) as FindRow;
            root.tipIndex = item && item.cut ? root.tipCandidate : -1;
        }
    }
    // A text broken into lines no wider than `room` logical px: at spaces
    // where it can, inside a word where a word alone is wider.
    function lines(text, room) {
        const out = [];
        let line = "";
        const fits = function (t) { return Kit.Win98Tokens.textWidth(t, false, root.u) <= room; };
        for (const word of String(text).split(" ")) {
            const next = line === "" ? word : line + " " + word;
            if (fits(next)) { line = next; continue; }
            if (line !== "") out.push(line);
            line = "";
            for (const ch of word) {
                if (line !== "" && !fits(line + ch)) { out.push(line); line = ""; }
                line += ch;
            }
        }
        if (line !== "") out.push(line);
        return out.join("\n");
    }
    function hoverRow(i) {
        if (i === root.tipCandidate) return;
        root.tipIndex = -1;
        root.tipCandidate = i;
        if (i >= 0) tipTimer.restart(); else tipTimer.stop();
    }

    // Where an item stands in this window. The other arguments are what the
    // answer depends on, so a binding that calls this is read again. A place
    // read while the layout is still moving can be stale, so layoutTick
    // reads it once more on the next turn of the event loop.
    function origin(item, ...depends) { return item.mapToItem(root, 0, 0); }
    property int layoutTick: 0
    Timer {
        id: layoutSettle
        interval: 0
        onTriggered: root.layoutTick++
    }
    function settle() { layoutSettle.restart(); }
    onTipIndexChanged: root.settle()
    onPlanChanged: root.settle()
    onHeightChanged: root.settle()

    // ------------------------------------------------------------ geometry (units)
    readonly property real bodyW: root.plan.width - 2 * Kit.Win98Tokens.frame - 12
    readonly property real buttonW: Kit.Win98Tokens.buttonMinWidth
    readonly property real critW: root.plan.inline ? root.bodyW - 2 * root.buttonW - 12
        : root.plan.buttonColumn ? root.bodyW - root.buttonW - 6 : root.bodyW
    readonly property real critH: root.plan.criteria
    // Each criteria row's height, and the field's place in it (centred).
    readonly property real critRow: root.plan.inline ? root.plan.criteria : (root.plan.criteria - 4) / 2
    readonly property real critPad: Math.floor((root.critRow - Kit.Win98Tokens.fieldHeight) / 2)
    readonly property real listY: 6 + root.critH + 6
    readonly property real listH: root.plan.list + 4 + 17
    readonly property real contentU: Plan.contentHeight(root.rows)
    readonly property bool scrolls: root.contentU > root.plan.list
    readonly property real listInner: root.bodyW - 4 - (root.scrolls ? Kit.Win98Tokens.scrollBar : 0)
    readonly property real detailW: Math.round(root.listInner * root.plan.detail)
    readonly property real statusY: root.listY + root.listH + 8
    readonly property real buttonRowY: root.statusY + (root.plan.status ? Kit.Win98Tokens.statusPane + 6 : -2)
    readonly property real bodyH: root.plan.natural - 2 * Kit.Win98Tokens.frame - Kit.Win98Tokens.captionHeight - 1

    width: root.plan.width * root.u
    height: frame.height
    implicitHeight: height

    Win98Window {
        id: frame
        focus: true
        width: root.width
        title: "Find: " + FindModel.scopeLabel(root.scope) + (root.plan.status ? "" : " (" + root.statusInfo.items + ")")
        iconName: "find"
        margins: false
        // Half a unit over, so the window's whole-unit floor keeps every unit.
        availableHeight: (root.plan.height + 0.5) * root.u
        onCloseClicked: root.action("close", null)

        Item {
            id: body
            width: frame.bodyWidth
            implicitHeight: root.bodyH * root.u

            // Named and Look in, on two rows (one on a short, wide screen).
            Item {
                id: criteria
                x: 6 * root.u; y: 6 * root.u
                width: root.critW * root.u
                height: root.critH * root.u

                Win98Text {
                    id: namedLabel
                    y: root.critPad * root.u + Kit.Win98Tokens.snap((Kit.Win98Tokens.fieldHeight * root.u - height) / 2, root.u)
                    text: "&Named:"
                }
                Win98TextField {
                    id: field
                    focus: true
                    objectName: "findField"
                    y: root.critPad * root.u
                    x: root.plan.inline ? namedLabel.implicitWidth + 4 * root.u : 48 * root.u
                    width: (root.plan.inline ? criteria.width - 158 * root.u : criteria.width) - x
                    onKeyPressed: function (event) { root.key(event); }
                }

                Win98Text {
                    id: lookLabel
                    x: root.plan.inline ? criteria.width - 150 * root.u : 0
                    y: (root.plan.inline ? root.critPad : root.critRow + 4 + root.critPad) * root.u + Kit.Win98Tokens.snap((Kit.Win98Tokens.fieldHeight * root.u - height) / 2, root.u)
                    text: "&Look in:"
                }
                Item {
                    id: combo
                    objectName: "findScope"
                    x: root.plan.inline ? lookLabel.x + lookLabel.implicitWidth + 4 * root.u : 48 * root.u
                    y: (root.plan.inline ? root.critPad : root.critRow + 4 + root.critPad) * root.u
                    width: criteria.width - x
                    height: Kit.Win98Tokens.fieldHeight * root.u
                    Win98Bevel { anchors.fill: parent; variant: "field"; color: Kit.Win98Tokens.win }
                    Win98Text {
                        x: 4 * root.u; y: 4 * root.u
                        width: Math.max(0, combo.width - 24 * root.u)
                        text: FindModel.scopeLabel(root.scope)
                        accessMarks: false
                        color: Kit.Win98Tokens.winText
                    }
                    Item {
                        id: dropButton
                        x: combo.width - 2 * root.u - width
                        y: 2 * root.u
                        width: 16 * root.u
                        height: 17 * root.u
                        Win98Bevel { anchors.fill: parent; variant: root.dropOpen ? "flatPressed" : "button" }
                        Win98Icon {
                            name: "arrow-down"
                            x: Kit.Win98Tokens.snap((dropButton.width - width) / 2, root.u) + (root.dropOpen ? root.u : 0)
                            y: Kit.Win98Tokens.snap((dropButton.height - height) / 2, root.u) + (root.dropOpen ? root.u : 0)
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onPressed: { field.forceActiveFocus(); root.dropOpen = !root.dropOpen; }
                    }
                }
            }

            // Open and Close: beside the criteria (stacked, or in their row
            // when it is one row), or a row under the list.
            Row {
                visible: root.plan.inline
                x: (6 + root.bodyW) * root.u - width
                y: 6 * root.u
                spacing: 6 * root.u
                Win98Button { objectName: "findOpen"; text: "&Open"; isDefault: true; widthUnits: root.buttonW; onClicked: root.choose(root.current) }
                Win98Button { objectName: "findClose"; text: "Close"; widthUnits: root.buttonW; onClicked: root.action("close", null) }
            }
            Column {
                visible: root.plan.buttonColumn && !root.plan.inline
                x: (6 + root.bodyW - root.buttonW) * root.u
                y: 6 * root.u
                spacing: 4 * root.u
                Win98Button { objectName: "findOpen"; text: "&Open"; isDefault: true; widthUnits: root.buttonW; onClicked: root.choose(root.current) }
                Win98Button { objectName: "findClose"; text: "Close"; widthUnits: root.buttonW; onClicked: root.action("close", null) }
            }
            Row {
                visible: !root.plan.buttonColumn
                x: (6 + root.bodyW) * root.u - width
                y: root.buttonRowY * root.u
                spacing: 6 * root.u
                Win98Button { objectName: "findOpen"; text: "&Open"; isDefault: true; widthUnits: root.buttonW; onClicked: root.choose(root.current) }
                Win98Button { objectName: "findClose"; text: "Close"; widthUnits: root.buttonW; onClicked: root.action("close", null) }
            }

            // The Details list: a sunken well, the column headers, the rows
            // and a scroll bar beside both, as a Win98 list view.
            Item {
                id: well
                objectName: "findList"
                x: 6 * root.u
                y: root.listY * root.u
                width: root.bodyW * root.u
                height: root.listH * root.u
                Win98Bevel { anchors.fill: parent; variant: "field"; color: Kit.Win98Tokens.win }

                Row {
                    x: 2 * root.u; y: 2 * root.u
                    Header { width: (root.listInner - root.detailW) * root.u; text: "Name" }
                    Header { visible: root.detailW > 0; width: root.detailW * root.u; text: "Details" }
                }

                Flickable {
                    id: list
                    x: 2 * root.u
                    y: 19 * root.u
                    width: root.listInner * root.u
                    height: root.plan.list * root.u
                    contentWidth: width
                    contentHeight: root.contentU * root.u
                    // Mapping can settle the scale/viewport after selection.
                    // Reveal against those final bounds, not just new rows.
                    onHeightChanged: selectionReveal.restart()
                    onContentHeightChanged: selectionReveal.restart()
                    interactive: false
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        width: list.width
                        Repeater {
                            id: rowRepeater
                            // A count, not the array: new rows reuse the row items.
                            model: root.rows.length
                            delegate: FindRow {
                                required property int index
                                row: root.rows[index] || ({})
                                lit: index === root.current && FindModel.selectable(row)
                                width: list.width
                            }
                        }
                    }

                    MouseArea {
                        width: list.width
                        height: Math.max(list.height, list.contentHeight)
                        hoverEnabled: true
                        function rowAt(y) { return Plan.rowAt(root.rows, y / root.u); }
                        onPositionChanged: mouse => root.hoverRow(rowAt(mouse.y))
                        onExited: root.hoverRow(-1)
                        onPressed: mouse => {
                            root.dropOpen = false;
                            const i = rowAt(mouse.y);
                            if (FindModel.selectable(root.rows[i])) { root.current = i; root.moved = true; }
                            field.forceActiveFocus();
                        }
                        onDoubleClicked: mouse => {
                            const i = rowAt(mouse.y);
                            if (FindModel.selectable(root.rows[i])) root.choose(i);
                        }
                        onWheel: wheel => {
                            root.tipIndex = -1;
                            const max = Math.max(0, list.contentHeight - list.height);
                            list.contentY = Math.max(0, Math.min(max, list.contentY - Math.sign(wheel.angleDelta.y) * 3 * 16 * root.u));
                        }
                    }
                }

                Win98ScrollBar {
                    visible: root.scrolls
                    x: well.width - 2 * root.u - width
                    y: 2 * root.u
                    height: well.height - 4 * root.u
                    flickable: list
                    step: 16 * root.u
                }
            }

            Win98StatusBar {
                visible: root.plan.status
                x: 6 * root.u
                y: root.statusY * root.u
                width: root.bodyW * root.u
                maximumLineCount: 1
                panes: [root.statusInfo.count, root.statusInfo.detail]
            }
        }
    }

    // Look in's list: under the field, or over it when the room below is short.
    Item {
        id: drop
        objectName: "findDrop"
        visible: root.dropOpen
        z: 10
        // Read again whenever the list opens or the layout changes.
        readonly property point at: root.origin(combo, root.layoutTick, root.dropOpen, root.plan, combo.x, combo.y, root.u, frame.height)
        readonly property var place: Plan.dropPlan(root.areaWidth / root.u, root.areaHeight / root.u,
            { x: (root.placeX + at.x) / root.u, y: (root.placeY + at.y) / root.u, w: combo.width / root.u, h: combo.height / root.u },
            root.dropRows.length - 1, 170)
        x: drop.place.x * root.u - root.placeX
        y: drop.place.y * root.u - root.placeY
        width: drop.place.width * root.u
        height: dropColumn.height + 2 * root.u
        Rectangle { anchors.fill: parent; color: Kit.Win98Tokens.win; border.width: root.u; border.color: Kit.Win98Tokens.dk }
        Column {
            id: dropColumn
            x: root.u; y: root.u
            width: drop.width - 2 * root.u
            Repeater {
                model: root.dropRows
                delegate: Item {
                    id: dropRow
                    required property var modelData
                    required property int index
                    readonly property bool lit: index === root.dropIndex && !!modelData.id
                    width: dropColumn.width
                    height: (modelData.id ? 16 : 6) * root.u
                    Rectangle { visible: !dropRow.modelData.id; x: 2 * root.u; y: 2 * root.u; width: parent.width - 4 * root.u; height: root.u; color: Kit.Win98Tokens.gray }
                    Rectangle { visible: dropRow.lit; anchors.fill: parent; color: Kit.Win98Tokens.selection }
                    Win98Text {
                        visible: !!dropRow.modelData.id
                        x: 3 * root.u; y: Kit.Win98Tokens.snap((dropRow.height - height) / 2, root.u)
                        width: Math.max(0, Math.min(implicitWidth, keyText.x - 6 * root.u - x))
                        text: dropRow.modelData.label || ""
                        accessMarks: false
                        color: dropRow.lit ? Kit.Win98Tokens.selectionText : Kit.Win98Tokens.winText
                    }
                    Win98Text {
                        id: keyText
                        visible: !!dropRow.modelData.id
                        x: dropRow.width - 3 * root.u - width
                        y: Kit.Win98Tokens.snap((dropRow.height - height) / 2, root.u)
                        width: implicitWidth
                        text: dropRow.modelData.key || ""
                        accessMarks: false
                        color: dropRow.lit ? Kit.Win98Tokens.selectionText : Kit.Win98Tokens.gray
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: if (dropRow.modelData.id) root.dropIndex = dropRow.index
                        onClicked: root.chooseDrop(dropRow.index)
                    }
                }
            }
        }
    }

    // The full name of a cut row, in a tip under the row (above it when the
    // room below is short), as the mock draws it: the row and its details
    // stay readable.
    Win98ToolTip {
        id: tip
        objectName: "findTip"
        z: 11
        readonly property var row: root.tipIndex >= 0 ? root.rows[root.tipIndex] : null
        readonly property point at: root.origin(well, root.layoutTick, root.tipIndex, root.plan, well.x, well.y, root.u, frame.height)
        readonly property real rowY: list.y + Plan.rowTop(root.rows, root.tipIndex) * root.u - list.contentY
        visible: tip.row !== null && tip.rowY >= list.y - 1 && tip.rowY + 16 * root.u <= list.y + list.height + 1
        x: tip.at.x + list.x + 20 * root.u
        readonly property real below: tip.at.y + tip.rowY + 16 * root.u + 8 * root.u
        y: tip.below + tip.height <= root.areaHeight - root.placeY ? tip.below : tip.at.y + tip.rowY - tip.height - 4 * root.u
        // Inside the screen, its 4-u sides included; a name longer than
        // that breaks into lines, so all of it stays readable.
        maxWidthUnits: Math.max(40, Math.floor((root.areaWidth - root.placeX - tip.x) / root.u) - 2 - 8)
        text: tip.row ? root.lines(tip.row.label || "", tip.maxWidthUnits * root.u) : ""
    }

    // ------------------------------------------------------------ parts
    component Header: Item {
        id: header
        property string text: ""
        height: 17 * root.u
        Win98Bevel { anchors.fill: parent; variant: "button" }
        Win98Text {
            x: 4 * root.u; y: 2 * root.u
            width: Math.max(0, Math.min(implicitWidth, header.width - 8 * root.u))
            text: header.text
            accessMarks: false
        }
    }

    // One row: a group (bold on the face colour, an etched rule), a rule,
    // or an item with its icon, name and details.
    component FindRow: Item {
        id: rowItem
        property var row: ({})
        property bool lit: false
        readonly property bool isItem: rowItem.row.t === "item"
        readonly property bool cut: nameText.truncated
        readonly property string kind: rowItem.row.k || ""
        readonly property string win98Icon: !rowItem.isItem ? ""
            : rowItem.kind === "cmd" ? "term" : rowItem.kind === "scope" ? "find" : rowItem.kind === "addr" ? "globe"
            : rowItem.kind === "win" ? root.win98Icon(rowItem.row.id || "", "")
            : rowItem.kind === "app" || rowItem.kind === "recent" ? root.win98Icon(rowItem.row.id || "", rowItem.row.label || "") : ""
        // The icon theme's icon, or "" when the theme has none.
        readonly property string themeIcon: {
            if (!rowItem.isItem || rowItem.win98Icon !== "" || !(rowItem.kind === "win" || rowItem.kind === "app" || rowItem.kind === "recent")) return "";
            const id = rowItem.row.icon || "";
            if (id === "") return "";
            const e = rowItem.kind === "win" ? DesktopEntries.heuristicLookup(id) : null;
            return Quickshell.iconPath(AppIcon.themeName(rowItem.kind === "win" ? id : "", e && e.icon ? e.icon : id), true);
        }
        readonly property color ink: rowItem.lit ? Kit.Win98Tokens.selectionText : rowItem.row.dis ? Kit.Win98Tokens.gray : Kit.Win98Tokens.winText
        height: Plan.rowHeight(rowItem.row) * root.u

        Rectangle { visible: rowItem.row.t === "head"; anchors.fill: parent; color: Kit.Win98Tokens.face }
        Rectangle { visible: rowItem.lit; anchors.fill: parent; color: Kit.Win98Tokens.selection }
        Rectangle { visible: rowItem.row.t === "sep"; x: 2 * root.u; y: 3 * root.u; width: parent.width - 4 * root.u; height: root.u; color: Kit.Win98Tokens.gray }

        Win98Text {
            id: headText
            visible: rowItem.row.t === "head"
            x: 2 * root.u
            y: Kit.Win98Tokens.snap((rowItem.height - height) / 2, root.u)
            width: Math.max(0, Math.min(implicitWidth, rowItem.width - 4 * root.u))
            text: rowItem.row.t === "head" ? rowItem.row.label || "" : ""
            accessMarks: false
            bold: true
            color: Kit.Win98Tokens.text
        }
        // The etched rule after the group's name.
        Item {
            visible: rowItem.row.t === "head"
            x: headText.x + headText.width + 4 * root.u
            y: Kit.Win98Tokens.snap(rowItem.height / 2, root.u) - root.u
            width: Math.max(0, rowItem.width - x - 2 * root.u)
            height: 2 * root.u
            Rectangle { width: parent.width; height: root.u; color: Kit.Win98Tokens.sh }
            Rectangle { y: root.u; width: parent.width; height: root.u; color: Kit.Win98Tokens.hi }
        }

        Item {
            id: iconCell
            visible: rowItem.isItem
            x: 2 * root.u
            width: 16 * root.u
            height: rowItem.height
            // A Win98 icon, else the icon theme's, else a document.
            Win98Icon {
                visible: name !== "" && rowItem.themeIcon === ""
                name: rowItem.win98Icon !== "" ? rowItem.win98Icon
                    : rowItem.kind === "win" || rowItem.kind === "app" || rowItem.kind === "recent" ? "doc" : ""
                color: rowItem.ink
            }
            IconImage {
                visible: rowItem.themeIcon !== ""
                implicitSize: 16 * root.u
                source: rowItem.themeIcon
            }
        }
        Win98Text {
            id: nameText
            visible: rowItem.isItem
            x: (rowItem.kind === "none" ? 2 : 22) * root.u
            y: Kit.Win98Tokens.snap((rowItem.height - height) / 2, root.u)
            width: Math.max(0, rowItem.width - x - (root.detailW > 0 ? root.detailW : 2) * root.u)
            text: rowItem.isItem ? rowItem.row.label || "" : ""
            accessMarks: false
            color: rowItem.ink
        }
        Win98Text {
            visible: rowItem.isItem && root.detailW > 0
            x: rowItem.width - root.detailW * root.u + 6 * root.u
            y: nameText.y
            width: Math.max(0, root.detailW * root.u - 8 * root.u)
            text: rowItem.isItem ? rowItem.row.hint || "" : ""
            accessMarks: false
            color: rowItem.lit ? Kit.Win98Tokens.selectionText : Kit.Win98Tokens.gray
        }
        Win98FocusRect {
            visible: rowItem.lit
            anchors.fill: parent
            color: Kit.Win98Tokens.selectionText
        }
    }
}
