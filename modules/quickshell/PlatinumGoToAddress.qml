import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Window
import "find-model.js" as FindModel
import "themes/platinum/find-plan.js" as FindPlan

// Go to Address: Ctrl+L on a browser window, or the Find menu's "Go to
// address" rows. A Platinum movable modal dialog with no close box, under
// the bar with its left edge on the front window's title (the window it
// acts on; the bar underlines that title while the dialog is open), not
// centred. The field holds the current URL, all selected, so typing
// replaces it as in a browser. Go navigates the window the menu was
// summoned over through CdpBrowser (Page.navigate over CDP), or opens a new
// web-app window when that window has no page. Esc and Cancel close.
FocusScope {
    id: root
    focus: true

    required property var omni
    property var owner: null
    // Where the front window's title starts on the bar.
    property real titleX: 42
    // PlatinumMenuHost's frame interface: the dialog places itself.
    property real preferredWidth: root.plan.width
    property real menuWidth: 0
    property real maxHeight: 600
    readonly property real placeX: root.plan.x
    readonly property real topGap: root.plan.y - (PlatinumTokens.barHeight - PlatinumTokens.hair)
    signal closeRequested
    // "go" with the address, or "find" (Backspace on an empty field).
    signal action(string kind, var arg)

    readonly property real hair: PlatinumTokens.hair
    readonly property real areaWidth: root.Window.width > 0 ? root.Window.width : 1920
    readonly property real areaHeight: root.Window.height > 0 ? root.Window.height : 1200
    readonly property var plan: FindPlan.addrPlan(root.areaWidth, root.areaHeight, root.titleX)

    readonly property var caller: root.omni.caller || null
    readonly property var target: CdpBrowser.targetFor(root.caller)
    readonly property string callerApp: root.caller && root.caller.wayland ? (root.caller.wayland.appId || "") : ""
    readonly property var dest: FindModel.destination(root.caller ? {
        title: root.caller.title || "",
        isBrowser: CdpBrowser.isBrowserWindow(root.caller),
        appName: root.owner && typeof root.owner.appName === "function" ? root.owner.appName(root.callerApp) : root.callerApp
    } : null, root.target)
    readonly property string base: root.target ? root.target.url : ""
    readonly property var pages: FindModel.addressPages(CdpBrowser.pages, field.text, root.base)
    // -1: the field has the keyboard; else the chosen open page.
    property int pageIndex: -1
    // The field starts with the current URL, all selected, until Simon types.
    property bool edited: false

    function iconOf(appId) {
        return root.owner && typeof root.owner.appIcon === "function" ? root.owner.appIcon(appId) : appId;
    }
    function pageIcon(p) { return root.iconOf("chrome-" + (p.host || "") + "__-Default"); }

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
    // Later, not inside the read that changed it (base is read by pages).
    onBaseChanged: Qt.callLater(root.prefill)

    readonly property string address: root.pageIndex >= 0 && root.pages[root.pageIndex] ? root.pages[root.pageIndex].url : field.text.trim()
    function go() {
        if (root.address === "" || root.dest.blocked) return;
        root.action("go", root.address);
    }
    // Esc: the host closes the dialog.
    function cancel() { return false; }

    function key(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (ctrl && event.key === Qt.Key_Period) { root.closeRequested(); event.accepted = true; return; }
        switch (event.key) {
        case Qt.Key_Return: case Qt.Key_Enter: root.go(); event.accepted = true; return;
        case Qt.Key_Escape: root.closeRequested(); event.accepted = true; return;
        case Qt.Key_Down:
            if (root.pages.length > 0 && root.plan.listRows > 0) root.pageIndex = Math.min(root.pages.length - 1, root.pageIndex + 1);
            root.revealPage();
            event.accepted = true; return;
        case Qt.Key_Up:
            root.pageIndex = Math.max(-1, root.pageIndex - 1);
            root.revealPage();
            event.accepted = true; return;
        case Qt.Key_Backspace:
            // An empty field goes back to the Find menu (a new press, not a held one).
            if (field.text === "") {
                if (!event.isAutoRepeat) root.action("find", "");
                event.accepted = true;
            }
            return;
        }
        // Typing goes to the field, and the page choice lets go.
        if (event.text !== "") root.pageIndex = -1;
    }
    function revealPage() {
        if (root.pageIndex < 0) return;
        const top = root.pageIndex * 20;
        if (top < pageList.contentY) pageList.contentY = top;
        else if (top + 20 > pageList.contentY + pageList.height) pageList.contentY = top + 20 - pageList.height;
    }

    width: root.plan.width
    height: Math.min(frame.implicitHeight, Math.max(120, root.plan.maxHeight))
    implicitHeight: height

    PlatinumDialogFrame {
        id: frame
        anchors.fill: parent
        title: "Go to Address"
        closable: false
        padding: 0
        implicitHeight: titleHeight + body.implicitHeight + 2 * PlatinumTokens.hair

        Column {
            id: body
            x: 0
            width: root.width - 2 * root.hair
            topPadding: 12
            bottomPadding: 13
            spacing: 8

            // Address: [ field ]
            Item {
                x: 14
                width: parent.width - 28
                height: 24
                Text {
                    id: addrLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Address:"
                    color: PlatinumTokens.menuText
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: 13
                    font.letterSpacing: PlatinumTokens.platinumTracking
                }
                PlatinumTextField {
                    id: field
                    focus: true
                    x: addrLabel.implicitWidth + 8
                    width: parent.width - x
                    height: 24
                    ringed: input.activeFocus && root.pageIndex < 0
                    onEdited: { root.edited = true; root.pageIndex = -1; }
                    onKeyPressed: function (event) { root.key(event); }
                }
            }

            // Opens in this window: [icon] <title>. The title moves to its own
            // line when the two do not fit side by side, and wraps to a second.
            Flow {
                x: 14
                width: parent.width - 28
                spacing: 6
                Text {
                    id: destText
                    width: Math.min(implicitWidth, parent.width)
                    height: 18
                    verticalAlignment: Text.AlignVCenter
                    text: root.dest.text
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    color: PlatinumTokens.menuTextSecondary
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumSmall
                    font.letterSpacing: PlatinumTokens.platinumTracking
                }
                Row {
                    visible: root.dest.here
                    spacing: 6
                    IconImage {
                        id: destIcon
                        visible: root.callerApp !== ""
                        y: 1
                        implicitSize: 16
                        // A browser window: Chromium's icon when its site has no entry.
                        source: visible ? Quickshell.iconPath(root.iconOf(root.callerApp), "chromium") : ""
                    }
                    Text {
                        readonly property real room: body.width - 28 - (destIcon.visible ? 22 : 0)
                        width: Math.min(implicitWidth, room)
                        height: Math.max(18, implicitHeight)
                        verticalAlignment: Text.AlignVCenter
                        text: root.dest.title
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: PlatinumTokens.menuText
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumSmall
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
                }
            }

            // A bare word is a search, and the dialog says so before Go.
            Text {
                visible: FindModel.isBareWords(field.text) && root.pageIndex < 0
                x: 14
                width: parent.width - 28
                text: "“" + field.text.trim() + "” is not an address: Go searches DuckDuckGo for it."
                textFormat: Text.PlainText
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
                color: PlatinumTokens.menuTextSecondary
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }

            Text {
                visible: root.plan.listRows > 0
                x: 14
                text: CdpBrowser.pages.length === 0 ? "Open pages: none" : root.pages.length === 0 ? "Open pages: none match" : "Open pages"
                color: PlatinumTokens.menuTextSecondary
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }

            // The open pages: a Platinum list box.
            Item {
                id: listBox
                visible: root.plan.listRows > 0
                x: 14
                width: parent.width - 28
                height: visible ? root.plan.listRows * 20 + 2 * root.hair : 0
                readonly property bool scrolls: root.pages.length > root.plan.listRows

                Rectangle {
                    anchors.fill: parent
                    color: PlatinumTokens.list
                    border.width: root.hair
                    border.color: PlatinumTokens.menuEdge
                }
                Flickable {
                    id: pageList
                    x: root.hair
                    y: root.hair
                    width: parent.width - 2 * root.hair - (listBox.scrolls ? PlatinumTokens.menuScrollBar : 0)
                    height: parent.height - 2 * root.hair
                    contentHeight: root.pages.length * 20
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        width: pageList.width
                        Repeater {
                            model: root.pages
                            delegate: Item {
                                id: pageRow
                                required property var modelData
                                required property int index
                                readonly property bool lit: index === root.pageIndex
                                width: pageList.width
                                height: 20
                                Rectangle { visible: pageRow.lit; anchors.fill: parent; color: PlatinumTokens.highlight }
                                IconImage {
                                    x: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 16
                                    source: Quickshell.iconPath(root.pageIcon(pageRow.modelData), "chromium")
                                }
                                Text {
                                    x: 28
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: (root.plan.hostColumn ? hostText.x - 8 : pageRow.width - 6) - x
                                    text: pageRow.modelData.title || pageRow.modelData.url
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: pageRow.lit ? PlatinumTokens.highlightText : PlatinumTokens.menuText
                                    font.family: PlatinumTokens.platinumFont
                                    font.pixelSize: PlatinumTokens.platinumSmall
                                    font.letterSpacing: PlatinumTokens.platinumTracking
                                }
                                Text {
                                    id: hostText
                                    visible: root.plan.hostColumn
                                    x: pageRow.width - 150
                                    width: 144
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: pageRow.modelData.host || ""
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: pageRow.lit ? PlatinumTokens.highlightText : PlatinumTokens.menuTextSecondary
                                    font.family: PlatinumTokens.platinumFont
                                    font.pixelSize: PlatinumTokens.platinumSmall
                                    font.letterSpacing: PlatinumTokens.platinumTracking
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { root.pageIndex = pageRow.index; field.forceActiveFocus(); }
                                    onDoubleClicked: { root.pageIndex = pageRow.index; root.go(); }
                                }
                            }
                        }
                    }
                }
                PlatinumScrollBar {
                    visible: listBox.scrolls
                    flickable: pageList
                    anchors.right: parent.right
                    anchors.rightMargin: root.hair
                    y: root.hair
                    height: parent.height - 2 * root.hair
                }
            }

            // Cancel and Go, Go the default.
            Item {
                x: 14
                width: parent.width - 28
                height: goButton.height
                readonly property real buttonW: PlatinumMetrics.buttonWidth(["Cancel", "Go"]) + 12
                PlatinumButton {
                    id: goButton
                    anchors.right: parent.right
                    isDefault: true
                    enabled: root.address !== "" && !root.dest.blocked
                    text: "Go"
                    fixedWidth: parent.buttonW
                    onClicked: root.go()
                }
                PlatinumButton {
                    anchors.right: goButton.left
                    anchors.rightMargin: 14
                    anchors.verticalCenter: goButton.verticalCenter
                    text: "Cancel"
                    fixedWidth: parent.buttonW
                    onClicked: root.closeRequested()
                }
            }
        }
    }
}
