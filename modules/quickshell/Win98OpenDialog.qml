pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "find-model.js" as FindModel
import "themes/win98/find-plan.js" as Plan

// Internet Explorer's "Open" dialog: Ctrl+L on a browser window, Look in ▸
// Go to Address…, Start ▸ Find ▸ Address… and the Find window's "Go to"
// rows. Win98's IE opened exactly this on Ctrl+L and Ctrl+O. It is the
// Win98 view of the omni service's address mode, as Go to Address is
// Platinum's: centred on the window it acts on (the caller), the current
// address in the field, all selected, so typing replaces it; the open
// pages in its drop-down, filtered as you type (find-model.js
// addressPages); a line that says where OK opens it (destination). OK
// goes through the service's navigateTo (CdpBrowser).
//
// Keys: Enter is OK; Down or F4 opens the list, Up/Down move in it; Esc
// closes the list, then the dialog; Backspace on an empty field (a new
// press, not a held one) goes back to the Find window.
//
// Layout: themes/win98/find-plan.js openPlan(), in units.
FocusScope {
    id: root
    focus: true

    required property var omni
    // This screen (ShellScreen): its place in the layout, for the caller's rectangle.
    property var screen: null
    // The room above the taskbar, logical px (the menu host's window).
    property real areaWidth: 1920
    property real areaHeight: 1160
    // "go" with the address, "find" (Backspace on an empty field), "close".
    signal action(string kind, var arg)

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)

    readonly property var caller: root.omni.caller || null
    // The caller's rectangle on this screen, in units, from Hyprland's last
    // report of where it sits (at, size), or null.
    readonly property var callerRect: {
        const c = root.caller, o = c ? c.lastIpcObject : null;
        if (!o || !o.at || !o.size) return null;
        const sx = root.screen ? root.screen.x : 0, sy = root.screen ? root.screen.y : 0;
        return { x: (o.at[0] - sx) / root.u, y: (o.at[1] - sy) / root.u, w: o.size[0] / root.u, h: o.size[1] / root.u };
    }
    readonly property var plan: Plan.openPlan(Math.floor(root.areaWidth / root.u + 1e-6), Math.floor(root.areaHeight / root.u + 1e-6), root.callerRect)
    readonly property real placeX: root.plan.x * root.u
    readonly property real placeY: root.plan.y * root.u

    // The caller's page, when it is a browser window.
    property var pages: CdpBrowser.pages
    readonly property var target: CdpBrowser.targetFor(root.caller)
    readonly property string callerApp: root.caller && root.caller.wayland ? (root.caller.wayland.appId || "") : ""
    readonly property var dest: FindModel.destination(root.caller ? {
        title: root.caller.title || "",
        isBrowser: CdpBrowser.isBrowserWindow(root.caller),
        appName: root.appName(root.callerApp)
    } : null, root.target)
    // An app id's name from its desktop entry ("Ghostty has no address").
    function appName(appId) {
        DesktopEntries.applications.values;
        const e = appId ? DesktopEntries.heuristicLookup(appId) : null;
        return e && e.name ? e.name : appId;
    }
    readonly property string base: root.target ? root.target.url : ""
    readonly property var shownPages: FindModel.addressPages(root.pages, field.text, root.base)

    // The field starts with the current address, all selected, until typed in.
    property bool edited: false
    function prefill() {
        if (root.edited) return;
        if (root.omni.query !== "") {
            field.text = root.omni.query;
            field.input.cursorPosition = field.text.length;
        } else {
            field.text = root.base;
            field.input.selectAll();
        }
    }
    Component.onCompleted: prefill()
    Timer {
        id: addressPrefill
        interval: 0
        onTriggered: root.prefill()
    }
    onBaseChanged: addressPrefill.restart()
    Connections {
        target: field.input
        function onTextEdited() {
            root.edited = true;
            root.pick = -1;
            // Typing opens the list of matching pages, as IE's AutoComplete did.
            root.listOpen = field.text !== "" && root.shownPages.length > 0;
        }
    }

    // The drop-down: open or not, and the page the keys chose (-1: none).
    property bool listOpen: false
    property int pick: -1
    readonly property string address: root.listOpen && root.pick >= 0 && root.shownPages[root.pick]
        ? root.shownPages[root.pick].url : field.text.trim()
    function go() {
        if (root.address === "" || root.dest.blocked) return;
        root.action("go", root.address);
    }
    function movePick(d) {
        const n = root.shownPages.length;
        if (!root.listOpen) { root.listOpen = true; root.pick = -1; return; }
        if (n === 0) return;
        root.pick = root.pick < 0 ? (d > 0 ? 0 : n - 1) : (root.pick + d + n) % n;
        root.revealPick();
    }
    function revealPick() {
        if (root.pick < 0) return;
        const top = root.pick * 16 * root.u;
        if (top < pageList.contentY) pageList.contentY = top;
        else if (top + 16 * root.u > pageList.contentY + pageList.height) pageList.contentY = top + 16 * root.u - pageList.height;
    }

    function key(event) {
        switch (event.key) {
        case Qt.Key_Return: case Qt.Key_Enter: root.go(); event.accepted = true; return;
        case Qt.Key_Escape:
            if (root.listOpen) root.listOpen = false; else root.action("close", null);
            event.accepted = true; return;
        case Qt.Key_Down: root.movePick(1); event.accepted = true; return;
        case Qt.Key_Up: if (root.listOpen) root.movePick(-1); event.accepted = true; return;
        case Qt.Key_F4: root.listOpen = !root.listOpen; root.pick = -1; event.accepted = true; return;
        case Qt.Key_Backspace:
            if (field.text === "") {
                if (!event.isAutoRepeat) root.action("find", "");
                event.accepted = true;
            }
            return;
        }
    }
    Keys.onPressed: event => root.key(event)
    Shortcut { sequence: "Alt+O"; context: Qt.WindowShortcut; onActivated: field.forceActiveFocus() }

    // Where an item stands in this dialog. The other arguments are what the
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
    onListOpenChanged: root.settle()
    onPlanChanged: root.settle()
    onHeightChanged: root.settle()

    width: root.plan.width * root.u
    height: frame.height
    implicitHeight: height

    // Units inside the body: 8 u of padding.
    readonly property real bodyW: root.plan.width - 2 * Win98Tokens.frame - 16
    readonly property real labelW: Win98Tokens.ceilU(Win98Tokens.textWidth("Open:", false, root.u), root.u) / root.u
    readonly property real fieldX: root.plan.labelAbove ? 0 : root.labelW + 6
    readonly property real introH: root.plan.intro ? 34 + 8 : 0
    readonly property real fieldY: 8 + root.introH + (root.plan.labelAbove ? 15 : 0)
    readonly property real destY: root.fieldY + Win98Tokens.fieldHeight + 6
    readonly property real buttonsY: root.destY + 28 + 8

    Win98Window {
        id: frame
        focus: true
        width: root.width
        title: "Open"
        margins: false
        // Half a unit over, so the window's whole-unit floor keeps every unit.
        availableHeight: (root.plan.height + 0.5) * root.u
        onCloseClicked: root.action("close", null)

        Item {
            id: body
            width: frame.bodyWidth
            implicitHeight: (root.buttonsY + Win98Tokens.buttonHeight + 8) * root.u

            // The globe and what the dialog is for.
            Item {
                visible: root.plan.intro
                x: 8 * root.u; y: 8 * root.u
                width: root.bodyW * root.u
                height: 34 * root.u
                Win98Icon { name: "globe-large" }
                Win98Text {
                    x: 42 * root.u
                    width: parent.width - x
                    wrap: true
                    lineUnits: 13
                    text: "Type the address of a page or a search, and Myoko will open it for you."
                    accessMarks: false
                }
            }

            Win98Text {
                id: openLabel
                x: 8 * root.u
                y: (root.plan.labelAbove ? root.fieldY - 15 : root.fieldY + 4) * root.u
                text: "&Open:"
            }
            // An editable combo box: the field and the drop button in one well.
            Win98TextField {
                id: field
                focus: true
                objectName: "openField"
                x: (8 + root.fieldX) * root.u
                y: root.fieldY * root.u
                width: (root.bodyW - root.fieldX) * root.u
                rightInsetUnits: 18
                onKeyPressed: function (event) { root.key(event); }
                Item {
                    id: dropButton
                    objectName: "openDrop"
                    x: field.width - 2 * root.u - width
                    y: 2 * root.u
                    width: 16 * root.u
                    height: 17 * root.u
                    Win98Bevel { anchors.fill: parent; variant: root.listOpen ? "flatPressed" : "button" }
                    Win98Icon {
                        name: "arrow-down"
                        x: Win98Tokens.snap((dropButton.width - width) / 2, root.u) + (root.listOpen ? root.u : 0)
                        y: Win98Tokens.snap((dropButton.height - height) / 2, root.u) + (root.listOpen ? root.u : 0)
                    }
                    MouseArea {
                        anchors.fill: parent
                        onPressed: { field.forceActiveFocus(); root.listOpen = !root.listOpen; root.pick = -1; }
                    }
                }
            }

            // Where OK opens the address.
            Column {
                objectName: "openDestination"
                x: (8 + (root.plan.labelAbove ? 0 : root.fieldX)) * root.u
                y: root.destY * root.u
                width: (root.bodyW - (root.plan.labelAbove ? 0 : root.fieldX)) * root.u
                // With no title under it, the line may take both lines.
                Win98Text {
                    width: parent.width
                    wrap: root.dest.title === ""
                    lineUnits: 14
                    maximumLineCount: root.dest.title === "" ? 2 : 1
                    text: root.dest.text
                    accessMarks: false
                }
                Win98Text {
                    visible: root.dest.title !== ""
                    width: Math.min(implicitWidth, parent.width)
                    height: 14 * root.u
                    text: root.dest.title
                    accessMarks: false
                    bold: true
                }
            }

            Row {
                x: (8 + root.bodyW) * root.u - width
                y: root.buttonsY * root.u
                spacing: 6 * root.u
                Win98Button { objectName: "openOk"; text: "OK"; isDefault: true; enabled: root.address !== "" && !root.dest.blocked; onClicked: root.go() }
                Win98Button { objectName: "openCancel"; text: "Cancel"; onClicked: root.action("close", null) }
            }
        }
    }

    // The open pages, under the field (or over it with no room below).
    Item {
        id: drop
        objectName: "openList"
        visible: root.listOpen
        z: 10
        readonly property point at: root.origin(field, root.layoutTick, root.listOpen, root.plan, field.x, field.y, root.u, frame.height)
        readonly property int rows: Math.max(1, Math.min(root.plan.listRows, root.shownPages.length))
        readonly property var place: Plan.dropPlan(root.areaWidth / root.u, root.areaHeight / root.u,
            { x: (root.placeX + at.x) / root.u, y: (root.placeY + at.y) / root.u, w: field.width / root.u, h: field.height / root.u },
            drop.rows, 300)
        x: drop.place.x * root.u - root.placeX
        y: drop.place.y * root.u - root.placeY
        width: drop.place.width * root.u
        height: drop.place.height * root.u
        readonly property bool scrolls: root.shownPages.length * 16 * root.u > pageList.height + 0.5
        Rectangle { anchors.fill: parent; color: Win98Tokens.win; border.width: root.u; border.color: Win98Tokens.dk }
        Win98Text {
            visible: root.shownPages.length === 0
            x: 4 * root.u; y: 2 * root.u
            width: drop.width - 8 * root.u
            text: root.pages.length === 0 ? "No open pages" : "No open page matches"
            accessMarks: false
            color: Win98Tokens.gray
        }
        Flickable {
            id: pageList
            x: 2 * root.u; y: 2 * root.u
            width: drop.width - 4 * root.u - (drop.scrolls ? Win98Tokens.scrollBar * root.u : 0)
            height: drop.height - 4 * root.u
            contentHeight: root.shownPages.length * 16 * root.u
            interactive: false
            clip: true
            Column {
                width: pageList.width
                Repeater {
                    model: root.shownPages
                    delegate: Item {
                        id: pageRow
                        required property var modelData
                        required property int index
                        readonly property bool lit: index === root.pick
                        width: pageList.width
                        height: 16 * root.u
                        Rectangle { visible: pageRow.lit; anchors.fill: parent; color: Win98Tokens.selection }
                        Win98Text {
                            id: urlText
                            x: 3 * root.u; y: root.u
                            width: Math.min(implicitWidth, pageRow.width * 0.6)
                            text: String(pageRow.modelData.url || "").replace(/^https:\/\//, "")
                            accessMarks: false
                            color: pageRow.lit ? Win98Tokens.selectionText : Win98Tokens.winText
                        }
                        Win98Text {
                            x: urlText.x + urlText.width + 6 * root.u; y: root.u
                            width: Math.max(0, pageRow.width - x - 3 * root.u)
                            text: pageRow.modelData.title || ""
                            accessMarks: false
                            color: pageRow.lit ? Win98Tokens.selectionText : Win98Tokens.gray
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.pick = pageRow.index
                            onClicked: { root.pick = pageRow.index; root.go(); }
                        }
                    }
                }
            }
            WheelHandler {
                onWheel: event => pageList.contentY = Math.max(0, Math.min(pageList.contentHeight - pageList.height,
                    pageList.contentY - Math.sign(event.angleDelta.y) * 16 * root.u))
            }
        }
        Win98ScrollBar {
            visible: drop.scrolls
            x: drop.width - 2 * root.u - width
            y: 2 * root.u
            height: drop.height - 4 * root.u
            flickable: pageList
            step: 16 * root.u
        }
    }
}
