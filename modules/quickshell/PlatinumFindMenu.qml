import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Window
import "lanes.js" as Lanes
import "find-model.js" as FindModel
import "themes/platinum/find-plan.js" as FindPlan

// The Find menu: Super+P, F1 and Apple menu ▸ Find… drop it from the
// mountain. Its first item is a scope pop-up ("All ⇕") and a type-in field;
// the menu filters live as Simon types. Rows come from the omni service
// (OmniBar.qml) through find-model.js; a chosen row goes back to the
// Desktop, which runs it through the service on the next turn of the loop.
//
// Like a Mac OS 8 menu it appears at once with no veil, keeps a highlight
// that the pointer and the arrows move, and scrolls behind ▲ / ▼ arrow
// bands when its rows do not fit. A cut-off title shows in full in a
// Balloon Help tag while the pointer rests on it.
FocusScope {
    id: root
    focus: true

    // The omni service, and the Desktop that draws this menu (app icons).
    required property var omni
    property var owner: null
    // PlatinumMenuHost's frame interface.
    property real preferredWidth: root.plan.width
    property real menuWidth: 0
    property real maxHeight: 600
    signal closeRequested
    // A row was chosen, or a request ("address") made; the Desktop runs it.
    signal action(string kind, var arg)

    readonly property real hair: PlatinumTokens.hair
    readonly property real originX: parent ? parent.x : 0
    readonly property real areaWidth: root.Window.width > 0 ? root.Window.width : 1920
    readonly property real areaHeight: root.Window.height > 0 ? root.Window.height : 1200
    readonly property var plan: FindPlan.menuPlan(root.areaWidth, root.areaHeight)

    readonly property string scope: FindModel.scopeOf(root.omni.mode)
    readonly property string query: root.omni.query || ""

    function iconOf(appId) {
        return root.owner && typeof root.owner.appIcon === "function" ? root.owner.appIcon(appId) : appId;
    }
    readonly property var ctx: ({
        windows: (root.omni.windowRows || []).map(function (r) {
            return { label: r.label, page: r.page, screen: r.screen, order: r.order, appId: r.appId || "",
                     icon: r.appId ? root.iconOf(r.appId) : "", ref: r };
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

    // The highlight. Until the pointer or a key moves it, it follows the
    // first row Return would run, so Super+P, Return goes back to the last
    // window even when the window list arrives a moment after the menu.
    property int current: -1
    property bool moved: false
    property real scroll: 0
    property string rowsKey: ""
    onRowsChanged: {
        const key = root.scope + "\u0000" + root.query;
        if (key !== root.rowsKey) { root.rowsKey = key; root.moved = false; root.scroll = 0; root.balloonIndex = -1; }
        if (!root.moved || !FindModel.selectable(root.rows[root.current])) root.current = FindModel.firstSelectable(root.rows);
        root.scroll = Math.max(0, Math.min(root.scroll, root.maxScroll));
        root.reveal();
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

    // ------------------------------------------------------------ geometry
    readonly property real band: 16
    readonly property real headerHeight: 7 + 24 + 6
    readonly property real chrome: root.hair + root.headerHeight + 2 * root.hair + 3 + 5 + root.hair
    readonly property real contentHeight: FindModel.contentHeight(root.rows)
    readonly property real listCap: Math.max(2 * FindModel.ROW, Math.min(root.maxHeight, root.plan.maxHeight) - root.chrome)
    readonly property real listHeight: Math.min(root.contentHeight, root.listCap)
    readonly property real maxScroll: Math.max(0, root.contentHeight - root.listHeight)
    readonly property bool scrolls: root.maxScroll > 0.5

    width: root.plan.width
    height: root.chrome + root.listHeight
    implicitHeight: height

    function reveal() {
        root.scroll = FindModel.scrollFor(root.rows, root.current, root.scroll, root.listHeight, root.band);
    }
    function move(dir) {
        const i = FindModel.step(root.rows, root.current, dir);
        if (i >= 0) { root.current = i; root.moved = true; root.reveal(); }
    }
    function movePage(dir) {
        const i = FindModel.page(root.rows, root.current, dir, 10);
        if (i >= 0) { root.current = i; root.moved = true; root.reveal(); }
    }
    function choose(i) {
        const r = root.rows[i];
        if (!FindModel.selectable(r)) return;
        root.action("row", r);
    }
    function setScope(id) {
        root.popupOpen = false;
        root.omni.enterMode(FindModel.modeOf(id));
    }
    // Esc and Backspace on an empty field: the pop-up first, then the
    // scope (back to All), then the host closes the menu.
    function cancel() {
        root.balloonIndex = -1;
        if (root.popupOpen) { root.popupOpen = false; return true; }
        if (root.scope !== "all") { root.omni.back(); return true; }
        return false;
    }

    function key(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        root.balloonIndex = -1;
        if (ctrl && event.key === Qt.Key_Period) { root.closeRequested(); event.accepted = true; return; }
        if (root.popupOpen) {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) { root.popupIndex = Math.min(root.popupRows.length - 1, root.popupIndex + 1); if (!root.popupRows[root.popupIndex].id) root.popupIndex++; event.accepted = true; return; }
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) { root.popupIndex = Math.max(0, root.popupIndex - 1); if (!root.popupRows[root.popupIndex].id) root.popupIndex--; event.accepted = true; return; }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.choosePopup(root.popupIndex); event.accepted = true; return; }
            if (event.key === Qt.Key_Escape) { root.popupOpen = false; event.accepted = true; return; }
            root.popupOpen = false;
        }
        if (ctrl && event.key === Qt.Key_1) { root.setScope("app"); event.accepted = true; return; }
        if (ctrl && event.key === Qt.Key_2) { root.setScope("win"); event.accepted = true; return; }
        if (ctrl && event.key === Qt.Key_3) { root.setScope("cmd"); event.accepted = true; return; }
        if (ctrl && event.key === Qt.Key_L) { root.action("address", root.query); event.accepted = true; return; }
        switch (event.key) {
        case Qt.Key_Down: case Qt.Key_Tab: root.move(1); event.accepted = true; return;
        case Qt.Key_Up: case Qt.Key_Backtab: root.move(-1); event.accepted = true; return;
        case Qt.Key_PageDown: root.movePage(1); event.accepted = true; return;
        case Qt.Key_PageUp: root.movePage(-1); event.accepted = true; return;
        case Qt.Key_Return: case Qt.Key_Enter: root.choose(root.current); event.accepted = true; return;
        case Qt.Key_Escape: if (!root.cancel()) root.closeRequested(); event.accepted = true; return;
        case Qt.Key_Backspace:
            if (field.text === "") {
                // A held Backspace stops at the empty field; a new press leaves.
                if (!event.isAutoRepeat && !root.cancel()) root.closeRequested();
                event.accepted = true;
            }
            return;
        }
    }

    // ------------------------------------------------------------ the scope pop-up
    property bool popupOpen: false
    property int popupIndex: 0
    readonly property var popupRows: FindModel.SCOPES.map(function (s) { return { id: s.id, label: s.label, key: s.key }; })
        .concat([{ id: "" }, { id: "address", label: "Go to Address…", key: "Ctrl+L" }])
    onPopupOpenChanged: if (popupOpen) popupIndex = Math.max(0, popupRows.findIndex(function (r) { return r.id === root.scope; }))
    function choosePopup(i) {
        const r = root.popupRows[i];
        if (!r || !r.id) return;
        root.popupOpen = false;
        if (r.id === "address") root.action("address", "");
        else root.setScope(r.id);
    }

    // ------------------------------------------------------------ Balloon Help
    property int balloonIndex: -1
    property int balloonCandidate: -1
    Timer {
        id: balloonTimer
        interval: 600
        onTriggered: {
            const item = rowRepeater.itemAt(root.balloonCandidate);
            root.balloonIndex = item && item.cut ? root.balloonCandidate : -1;
        }
    }
    function hoverRow(i) {
        if (i === root.balloonCandidate) return;
        root.balloonIndex = -1;
        root.balloonCandidate = i;
        if (i >= 0) balloonTimer.restart(); else balloonTimer.stop();
    }

    // ------------------------------------------------------------ drawing
    Item {
        id: frame
        width: root.width
        height: root.height

        // The hard shadow, one rule down and right.
        Rectangle {
            x: 2 * root.hair
            y: 2 * root.hair
            width: parent.width
            height: parent.height
            color: PlatinumTokens.menuShadow
        }
        PlatinumBevel {
            anchors.fill: parent
            color: PlatinumTokens.menuSurface
        }
        // Clicks inside the menu stay inside it.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.popupOpen = false
        }

        // The first item: the scope pop-up and the field.
        Item {
            id: header
            x: root.hair + 8
            y: root.hair + 7
            width: frame.width - 2 * root.hair - 8 - 9
            height: 24

            Item {
                id: popButton
                visible: root.plan.popup
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? PlatinumMetrics.even(8 + popLabel.implicitWidth + 5 + root.hair + 4 + 7 + 5) : 0
                height: 22
                readonly property bool down: popArea.pressed || root.popupOpen

                PlatinumBevel {
                    anchors.fill: parent
                    radius: 3
                    sunken: popButton.down
                    color: popButton.down ? PlatinumTokens.well : PlatinumTokens.raised
                }
                Text {
                    id: popLabel
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: FindModel.scopeLabel(root.scope)
                    textFormat: Text.PlainText
                    color: PlatinumTokens.menuText
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumSmall
                    font.letterSpacing: PlatinumTokens.platinumTracking
                }
                Rectangle {
                    x: popLabel.x + popLabel.implicitWidth + 5
                    y: root.hair
                    width: root.hair
                    height: parent.height - 2 * root.hair
                    color: PlatinumTokens.bevelDark
                }
                PlatinumIcon {
                    x: popLabel.x + popLabel.implicitWidth + 5 + root.hair + 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 11
                    name: "popup"
                    color: PlatinumTokens.menuText
                }
                MouseArea {
                    id: popArea
                    anchors.fill: parent
                    anchors.margins: -3
                    onPressed: root.popupOpen = !root.popupOpen
                }
            }

            // Too narrow for the pop-up: the scope as a label.
            Text {
                id: scopeText
                visible: !root.plan.popup && root.scope !== "all"
                anchors.verticalCenter: parent.verticalCenter
                text: FindModel.scopeLabel(root.scope) + ":"
                textFormat: Text.PlainText
                color: PlatinumTokens.menuTextSecondary
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }

            PlatinumTextField {
                id: field
                focus: true
                x: popButton.visible ? popButton.width + 6 : scopeText.visible ? scopeText.implicitWidth + 6 : 0
                width: header.width - x
                height: 24
                onEdited: function (text) { root.omni.query = text; }
                onKeyPressed: function (event) { root.key(event); }
            }
        }

        // The etched rule under the first item.
        Rectangle {
            x: root.hair; y: root.hair + root.headerHeight
            width: frame.width - 2 * root.hair; height: root.hair
            color: PlatinumTokens.bevelDark
        }
        Rectangle {
            x: root.hair; y: root.hair + root.headerHeight + root.hair
            width: frame.width - 2 * root.hair; height: root.hair
            color: PlatinumTokens.bevelLight
        }

        Item {
            id: viewport
            x: root.hair
            y: root.hair + root.headerHeight + 2 * root.hair + 3
            width: frame.width - 2 * root.hair
            height: root.listHeight
            clip: true

            Column {
                id: column
                y: -root.scroll
                width: viewport.width
                Repeater {
                    id: rowRepeater
                    // A count, not the array: new rows reuse the row items.
                    model: root.rows.length
                    delegate: FindRow {
                        required property int index
                        row: root.rows[index] || ({})
                        lit: index === root.current && FindModel.selectable(row)
                        width: column.width
                    }
                }
            }

            // The pointer: hover moves the highlight (once the pointer has
            // really moved, so a pointer resting where the menu opens does not
            // steal Super+P, Return), a click runs the row, the wheel scrolls.
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property real startX: -1
                property real startY: -1
                property bool armed: false
                function rowAt(y) {
                    const want = y + root.scroll;
                    let top = 0;
                    for (let i = 0; i < root.rows.length; i++) {
                        const h = FindModel.rowHeight(root.rows[i]);
                        if (want >= top && want < top + h) return i;
                        top += h;
                    }
                    return -1;
                }
                function track(y) {
                    const i = rowAt(y);
                    root.hoverRow(i);
                    if (i >= 0 && FindModel.selectable(root.rows[i]) && i !== root.current) {
                        root.current = i;
                        root.moved = true;
                    }
                }
                onEntered: { startX = mouseX; startY = mouseY; armed = false; }
                onPositionChanged: function (mouse) {
                    if (!armed && Math.abs(mouse.x - startX) + Math.abs(mouse.y - startY) > 3) armed = true;
                    if (armed) track(mouse.y);
                }
                onExited: root.hoverRow(-1)
                onClicked: function (mouse) {
                    root.popupOpen = false;
                    const i = rowAt(mouse.y);
                    if (i >= 0 && FindModel.selectable(root.rows[i])) { root.current = i; root.choose(i); }
                }
                onWheel: function (wheel) {
                    root.balloonIndex = -1;
                    root.scroll = Math.max(0, Math.min(root.maxScroll, root.scroll - wheel.angleDelta.y / 120 * 3 * FindModel.ROW));
                }
            }

            ScrollBand { up: true; visible: root.scroll > 0.5 }
            ScrollBand { up: false; visible: root.scroll < root.maxScroll - 0.5 }
        }
    }

    // The scope pop-up menu, over the rows.
    Item {
        id: popup
        visible: root.popupOpen
        z: 5
        x: header.x
        y: header.y + header.height + 2
        width: PlatinumMetrics.even(Math.max(200, 30 + PlatinumMetrics.width("Go to Address…") + 24 + PlatinumMetrics.smallWidth("Ctrl+L") + 12))
        height: popupColumn.height + 4 + 5 + 2 * root.hair

        Rectangle { x: 2 * root.hair; y: 2 * root.hair; width: parent.width; height: parent.height; color: PlatinumTokens.menuShadow }
        PlatinumBevel { anchors.fill: parent; color: PlatinumTokens.menuSurface }
        Column {
            id: popupColumn
            x: root.hair
            y: root.hair + 4
            width: popup.width - 2 * root.hair
            Repeater {
                model: root.popupRows
                delegate: Item {
                    id: popRow
                    required property var modelData
                    required property int index
                    readonly property bool lit: modelData.id !== "" && index === root.popupIndex
                    width: popupColumn.width
                    height: modelData.id === "" ? FindModel.SEP : FindModel.ROW
                    Rectangle { visible: popRow.modelData.id === ""; y: 3; width: parent.width; height: root.hair; color: PlatinumTokens.bevelDark }
                    Rectangle { visible: popRow.modelData.id === ""; y: 3 + root.hair; width: parent.width; height: root.hair; color: PlatinumTokens.bevelLight }
                    Rectangle { visible: popRow.lit; anchors.fill: parent; color: PlatinumTokens.highlight }
                    PlatinumIcon {
                        visible: popRow.modelData.id === root.scope
                        x: 9
                        anchors.verticalCenter: parent.verticalCenter
                        name: "check"
                        size: 12
                        color: popRow.lit ? PlatinumTokens.highlightText : PlatinumTokens.menuText
                    }
                    Text {
                        visible: popRow.modelData.id !== ""
                        x: 30
                        anchors.verticalCenter: parent.verticalCenter
                        text: popRow.modelData.label || ""
                        color: popRow.lit ? PlatinumTokens.highlightText : PlatinumTokens.menuText
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumText
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
                    Text {
                        visible: popRow.modelData.id !== ""
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: popRow.modelData.key || ""
                        color: popRow.lit ? PlatinumTokens.highlightText : PlatinumTokens.menuTextSecondary
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumSmall
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: if (popRow.modelData.id !== "") root.popupIndex = popRow.index
                        onClicked: root.choosePopup(popRow.index)
                    }
                }
            }
        }
    }

    // Balloon Help: the full title of the row the pointer rests on, when the
    // menu cut it off. Beside the menu where the screen has room, else over
    // the rows under it.
    Item {
        id: balloon
        readonly property var row: root.balloonIndex >= 0 ? root.rows[root.balloonIndex] : null
        readonly property real rowTop: viewport.y - root.scroll + FindModel.rowTop(root.rows, root.balloonIndex)
        readonly property real roomRight: root.areaWidth - root.originX - frame.width - 18
        readonly property bool beside: roomRight >= 180
        visible: row !== null && rowTop >= viewport.y - 1 && rowTop + FindModel.ROW <= viewport.y + viewport.height + 1
        z: 6
        x: beside ? frame.width + 12 : 16
        y: beside ? rowTop - 2 : rowTop + FindModel.ROW + 8
        width: beside ? Math.min(380, roomRight) : frame.width - 32
        height: balloonText.height + 14

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: PlatinumTokens.balloon
            border.width: root.hair
            border.color: PlatinumTokens.menuEdge
        }
        // The tail, pointing at the row.
        Canvas {
            id: tail
            width: 12
            height: 12
            x: balloon.beside ? -width + root.hair : 18
            y: balloon.beside ? 8 : -height + root.hair
            property color fill: PlatinumTokens.balloon
            property color edge: PlatinumTokens.menuEdge
            property bool beside: balloon.beside
            onFillChanged: requestPaint()
            onBesideChanged: requestPaint()
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.fillStyle = fill;
                c.strokeStyle = edge;
                c.lineWidth = root.hair;
                c.beginPath();
                if (beside) { c.moveTo(width, 0); c.lineTo(0, height / 2); c.lineTo(width, height); }
                else { c.moveTo(0, height); c.lineTo(width / 2, 0); c.lineTo(width, height); }
                c.fill();
                c.stroke();
            }
        }
        Column {
            id: balloonText
            x: 10
            y: 7
            width: balloon.width - 20
            spacing: 2
            Text {
                width: parent.width
                text: balloon.row ? balloon.row.label || "" : ""
                textFormat: Text.PlainText
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                color: PlatinumTokens.menuText
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
            Text {
                visible: text !== ""
                width: parent.width
                text: balloon.row ? balloon.row.hint || "" : ""
                textFormat: Text.PlainText
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                color: PlatinumTokens.menuTextSecondary
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumHint
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
        }
    }

    // ------------------------------------------------------------ parts
    // One row: a group label, an etched rule, or an item with its icon,
    // label and hint (where a Mac menu shows its Command key).
    component FindRow: Item {
        id: rowItem
        property var row: ({})
        property bool lit: false
        readonly property bool isItem: row.t === "item"
        readonly property bool cut: label.truncated
        readonly property color fg: row.t === "head" || row.dis ? PlatinumTokens.menuTextOff
            : lit ? PlatinumTokens.highlightText : PlatinumTokens.menuText
        height: FindModel.rowHeight(row)

        Rectangle { visible: rowItem.row.t === "sep"; y: 3; width: parent.width; height: root.hair; color: PlatinumTokens.bevelDark }
        Rectangle { visible: rowItem.row.t === "sep"; y: 3 + root.hair; width: parent.width; height: root.hair; color: PlatinumTokens.bevelLight }
        Rectangle { visible: rowItem.lit; anchors.fill: parent; color: PlatinumTokens.highlight }

        IconImage {
            visible: rowItem.isItem && !!rowItem.row.icon && (rowItem.row.k === "win" || rowItem.row.k === "app" || rowItem.row.k === "recent")
            x: 3 + root.hair
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 16
            source: visible ? Quickshell.iconPath(rowItem.row.icon, "application-x-executable") : ""
        }
        Text {
            id: label
            visible: rowItem.row.t !== "sep"
            x: 30 + root.hair
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, (hint.visible ? hint.x - PlatinumTokens.menuGap : rowItem.width - PlatinumTokens.menuRightInset) - x)
            text: rowItem.row.label || ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: rowItem.fg
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: rowItem.row.t === "head" ? PlatinumTokens.platinumSmall : PlatinumTokens.platinumText
            font.letterSpacing: PlatinumTokens.platinumTracking
        }
        // The hint is a readout: it keeps its share of the row and gives way
        // before the label does (find-plan.js); it still matches a search.
        Text {
            id: hint
            visible: rowItem.isItem && !!rowItem.row.hint && root.plan.hintShare > 0
            anchors.right: parent.right
            anchors.rightMargin: PlatinumTokens.menuRightInset + root.hair
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, rowItem.width * root.plan.hintShare)
            horizontalAlignment: Text.AlignRight
            text: rowItem.row.hint || ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: rowItem.row.dis ? PlatinumTokens.menuTextOff : rowItem.lit ? PlatinumTokens.highlightText : PlatinumTokens.menuTextSecondary
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumSmall
            font.letterSpacing: PlatinumTokens.platinumTracking
        }
    }

    // A Mac OS menu's scroll arrow at a cut edge. Resting the pointer on it
    // scrolls the rows under it, as Mac OS menus did.
    component ScrollBand: Item {
        id: bandItem
        property bool up: true
        z: 2
        width: viewport.width
        height: root.band
        y: up ? 0 : viewport.height - height
        Rectangle { anchors.fill: parent; color: PlatinumTokens.menuSurface }
        PlatinumIcon {
            anchors.centerIn: parent
            width: 11
            height: 6
            name: bandItem.up ? "band-up" : "band-down"
            color: PlatinumTokens.menuText
        }
        MouseArea {
            id: bandArea
            anchors.fill: parent
            hoverEnabled: true
            onWheel: function (wheel) { wheel.accepted = false; }
        }
        Timer {
            running: bandArea.containsMouse && bandItem.visible
            repeat: true
            interval: 40
            onTriggered: {
                root.balloonIndex = -1;
                root.scroll = Math.max(0, Math.min(root.maxScroll, root.scroll + (bandItem.up ? -8 : 8)));
            }
        }
    }
}
