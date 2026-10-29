import QtQuick
import QtQuick.Layouts
import "page-layout-model.js" as Model

// The Layout menu: how the page this screen shows arranges its windows,
// and what a new page on this screen starts with. Two tabs, as the
// contract has them: THIS PAGE edits the page, DEFAULT edits the screen's
// default. Every value comes from panel (panels/PageLayout.qml), and every
// change goes through it.
//
// The header and the tabs stay put; the rows under them scroll when the
// screen is too short for the menu, so every row stays reachable. The
// keys in the footer act from anywhere in the menu.
PlatinumMenuFrame {
    id: frame
    required property var panel

    preferredWidth: 344
    title: "Layout"
    detail: !panel.available ? "Layout is not available on this screen."
        : frame.onPage ? "This page · " + panel.title
        : "New pages on " + panel.title
    scrolls: scrollBar.needed

    readonly property bool onPage: panel.tab === "page"
    readonly property var shown: panel.shownValues
    readonly property bool floating: frame.shown.floating === true
    readonly property bool live: panel.available
    // Use Default shows on This page while a value differs from the
    // screen's default; a floating page greys both rows instead.
    readonly property bool capDiffers: frame.onPage && !frame.floating && panel.page.cap !== panel.def.cap
    readonly property bool gapDiffers: frame.onPage && !frame.floating && panel.shownGap !== panel.def.gap
    readonly property real defaultButtonW: PlatinumMetrics.buttonWidth(["Use Default", "Reset All"])
    // The narrowest a note may wrap to beside its button.
    readonly property real noteMin: 96

    function switchTab() { panel.tab = frame.onPage ? "default" : "page"; }
    function toggleArrange() {
        if (!frame.live) return;
        panel.setArrange(!frame.floating);
        frame.reveal(arrangeLabel);
    }
    function setCap(n) {
        if (!frame.live || frame.floating) return;
        panel.setCap(n);
        frame.reveal(caps);
    }
    function stepGap(direction) {
        if (!frame.live || frame.floating) return;
        panel.stepGap(direction);
        frame.reveal(gapSlider);
    }
    function toggleZen() {
        if (!frame.live || !frame.onPage) return;
        panel.toggleZen();
        frame.reveal(zenRow);
    }

    // A key acts on a row out of view: scroll it into view first.
    function reveal(item) {
        if (!scrollBar.needed || !item) return;
        const top = item.mapToItem(body, 0, 0).y;
        const bottom = top + item.height;
        if (top < flick.contentY) flick.contentY = top;
        else if (bottom > flick.contentY + flick.height) flick.contentY = bottom - flick.height;
    }

    // A drag held when the menu closes must not keep the gap pinned.
    Component.onDestruction: panel.dragging = false

    //----------------------------------------------------------------
    // Parts of this menu
    //----------------------------------------------------------------
    // A row's label on the text edge, its key on the right edge. The key
    // is a readout: it gives way before the label is cut.
    component LabelRow: Item {
        id: labelRow
        property string text: ""
        property string keys: ""
        property bool off: false
        readonly property real room: width - PlatinumTokens.menuTextLeft - frame.rightInset
        readonly property bool keyFits: keys !== ""
            && labelText.implicitWidth + PlatinumTokens.menuGap + keyText.implicitWidth <= room
        Layout.fillWidth: true
        implicitHeight: PlatinumTokens.menuLine

        Text {
            id: labelText
            x: PlatinumTokens.menuTextLeft
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, labelRow.room))
            elide: Text.ElideRight
            text: labelRow.text
            color: labelRow.off ? PlatinumTokens.menuTextOff : PlatinumTokens.menuText
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumText
            font.letterSpacing: PlatinumTokens.platinumTracking
        }

        Text {
            id: keyText
            visible: labelRow.keyFits
            anchors.right: parent.right
            anchors.rightMargin: frame.rightInset
            anchors.verticalCenter: parent.verticalCenter
            text: labelRow.keys
            color: labelRow.off ? PlatinumTokens.menuTextOff : PlatinumTokens.menuTextSecondary
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumHint
            font.letterSpacing: PlatinumTokens.platinumTracking
        }
    }

    // A note, and a button on the right edge (Use Default, Reset All).
    // The note wraps before the button shrinks; once the note would have
    // less than noteMin beside the button, the button moves under it.
    component NoteRow: Item {
        id: noteRow
        property string text: ""
        property string action: ""
        property bool showAction: true
        property color color: PlatinumTokens.menuTextSecondary
        signal clicked
        readonly property real room: width - PlatinumTokens.menuTextLeft - frame.rightInset
        readonly property bool stacked: noteButton.visible && room - noteButton.width - PlatinumTokens.menuGap < frame.noteMin
        Layout.fillWidth: true
        implicitHeight: stacked ? note.implicitHeight + 4 + noteButton.implicitHeight + 4
            : Math.max(22, note.implicitHeight + 4, noteButton.visible ? noteButton.implicitHeight + 4 : 0)

        Text {
            id: note
            x: PlatinumTokens.menuTextLeft
            y: noteRow.stacked ? 2 : (noteRow.height - height) / 2
            width: Math.max(0, noteRow.room
                - (noteButton.visible && !noteRow.stacked ? noteButton.width + PlatinumTokens.menuGap : 0))
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: noteRow.text
            color: noteRow.color
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumSmall
            font.letterSpacing: PlatinumTokens.platinumTracking
            lineHeight: 1.15
        }

        PlatinumButton {
            id: noteButton
            visible: noteRow.action !== "" && noteRow.showAction
            x: noteRow.width - frame.rightInset - width
            y: noteRow.stacked ? note.y + note.height + 2 : (noteRow.height - height) / 2
            text: noteRow.action
            fixedWidth: Math.min(frame.defaultButtonW, noteRow.room)
            onClicked: noteRow.clicked()
        }
    }

    // A capacity button: the screen with N tiles over its word. The chosen
    // one is pressed in, its tiles in the highlight; while the page floats
    // the row is greyed and capacity is not enforced.
    component CapButton: Item {
        id: capButton
        required property int count
        // In a column (a narrow menu) the picture stands left of the word.
        property bool inline: false
        readonly property bool chosen: frame.shown.cap === count
        readonly property bool down: chosen || capArea.pressed
        readonly property bool usable: capButton.enabled && !frame.floating

        PlatinumBevel {
            anchors.fill: parent
            sunken: capButton.down
            color: capButton.down ? PlatinumTokens.well : PlatinumTokens.raised
        }

        Grid {
            anchors.centerIn: parent
            columns: capButton.inline ? 2 : 1
            spacing: capButton.inline ? 8 : 5
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            PlatinumIcon {
                width: 30
                height: 20
                name: "layout-cap-" + capButton.count
                color: capButton.usable ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff
                knock: capButton.chosen && capButton.usable ? PlatinumTokens.highlight : PlatinumTokens.raised
            }

            Text {
                width: Math.min(implicitWidth, capButton.width - 6 - (capButton.inline ? 38 : 0))
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: panel.word(capButton.count)
                color: capButton.usable ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
        }

        MouseArea {
            id: capArea
            anchors.fill: parent
            enabled: capButton.usable
            onClicked: frame.setCap(capButton.count)
        }
    }

    //----------------------------------------------------------------
    // The menu
    //----------------------------------------------------------------
    PlatinumTabs {
        rightInset: frame.rightInset
        enabled: frame.live
        current: panel.tab
        model: [{ key: "page", label: "THIS PAGE" }, { key: "default", label: "DEFAULT" }]
        onSelected: function (key) { panel.tab = key; }
    }

    // The rows under the tabs. They scroll when the screen is short.
    Item {
        id: viewport
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: body.implicitHeight
        implicitHeight: body.implicitHeight

        Flickable {
            id: flick
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            ColumnLayout {
                id: body
                width: flick.width
                spacing: 0
                enabled: frame.live

                LabelRow {
                    id: arrangeLabel
                    text: frame.onPage ? "Arrange" : "Arrange new pages"
                    keys: frame.onPage ? "Super+F" : ""
                    off: !frame.live
                }

                PlatinumTabs {
                    rightInset: frame.rightInset
                    stripHeight: 24
                    current: frame.floating ? "floating" : "tiled"
                    model: [{ key: "tiled", label: "Tiled", icon: "layout-tile-2" },
                            { key: "floating", label: "Floating", icon: "layout-float" }]
                    onSelected: function (key) { if (frame.live) panel.setArrange(key === "floating"); }
                }

                PlatinumMenuParts.Separator {}

                LabelRow {
                    text: frame.onPage ? "Windows on this page" : "Windows per page"
                    keys: frame.onPage ? "Super+1 2 3" : ""
                    off: frame.floating || !frame.live
                }

                // Three equal buttons from the text edge to the right edge.
                // Once a button is narrower than its picture and word, the
                // three stack in a column, each as wide as the row.
                Item {
                    id: caps
                    Layout.fillWidth: true
                    readonly property real gap: 8
                    readonly property real room: width - PlatinumTokens.menuTextLeft - frame.rightInset
                    readonly property real cell: (room - 2 * gap) / 3
                    readonly property bool column: cell < PlatinumMetrics.smallWidest(["Three"]) + 12
                    implicitHeight: column ? 3 * 30 + 2 * 4 + 6 : 52 + 6

                    Repeater {
                        model: [1, 2, 3]

                        CapButton {
                            required property int modelData
                            count: modelData
                            inline: caps.column
                            x: PlatinumTokens.menuTextLeft + (caps.column ? 0 : (modelData - 1) * (caps.cell + caps.gap))
                            y: 2 + (caps.column ? (modelData - 1) * 34 : 0)
                            width: caps.column ? caps.room : caps.cell
                            height: caps.column ? 30 : 52
                        }
                    }
                }

                NoteRow {
                    text: frame.floating ? Model.capNote(frame.shown)
                        : frame.onPage ? panel.capNote()
                        : "Super+1 2 3 change only the current page."
                    color: frame.floating ? PlatinumTokens.menuTextOff : PlatinumTokens.menuTextSecondary
                }

                NoteRow {
                    visible: frame.capDiffers
                    text: "New pages start with " + panel.def.cap + "."
                    action: "Use Default"
                    onClicked: panel.useDefault("cap")
                }

                PlatinumMenuParts.Separator {}

                LabelRow {
                    text: "Outer gap"
                    keys: frame.onPage ? "Super+Shift+[ ]" : ""
                    off: frame.floating || !frame.live
                }

                PlatinumSlider {
                    id: gapSlider
                    rightInset: frame.rightInset
                    enabled: frame.live && !frame.floating
                    dimmed: frame.floating || !frame.live
                    valueWidth: PlatinumMetrics.widest([PlatinumMetrics.digits(2) + " px"])
                    ratio: panel.gapMax > 0 ? panel.shownGap / panel.gapMax : 0
                    valueText: panel.shownGap + " px"
                    onMoved: function (ratio) { panel.setGap(ratio * panel.gapMax); }
                    onDraggingChanged: panel.dragging = gapSlider.dragging
                }

                // The scale under the track: its ends. They are a readout,
                // so they go when the track is too short to hold both.
                Item {
                    visible: gapSlider.trackWidth >= 80
                    Layout.fillWidth: true
                    Layout.topMargin: -4
                    implicitHeight: 14

                    Text {
                        x: gapSlider.trackX
                        text: "None"
                        color: frame.floating ? PlatinumTokens.menuTextOff : PlatinumTokens.menuTextSecondary
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumHint
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
                    Text {
                        x: gapSlider.trackX + gapSlider.trackWidth - implicitWidth
                        text: String(panel.gapMax)
                        color: frame.floating ? PlatinumTokens.menuTextOff : PlatinumTokens.menuTextSecondary
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumHint
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
                }

                NoteRow {
                    visible: frame.floating
                    text: "Gaps apply to tiled windows."
                    color: PlatinumTokens.menuTextOff
                }

                NoteRow {
                    visible: frame.gapDiffers
                    text: "New pages use " + panel.def.gap + " px."
                    action: "Use Default"
                    onClicked: panel.useDefault("gap")
                }

                PlatinumMenuCheckRow {
                    id: zenRow
                    visible: frame.onPage
                    Layout.topMargin: 2
                    rightInset: frame.rightInset
                    text: "Zen margins"
                    checked: panel.page.zen === true
                    onToggled: frame.toggleZen()

                    Text {
                        // The key is a readout: it goes before the label is cut.
                        visible: zenRow.width - PlatinumTokens.menuTextLeft - frame.rightInset
                            - PlatinumMetrics.width("Zen margins") - PlatinumTokens.menuGap >= implicitWidth
                        text: "Super+Shift+M"
                        color: PlatinumTokens.menuTextSecondary
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumHint
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
                }

                PlatinumMenuParts.Separator { visible: !frame.onPage && panel.ownCount > 0 }

                NoteRow {
                    visible: !frame.onPage && panel.ownCount > 0
                    text: panel.ownCount === 1 ? "1 page differs from this." : panel.ownCount + " pages differ from this."
                    color: PlatinumTokens.menuText
                    action: "Reset All"
                    onClicked: panel.resetPages()
                }

                PlatinumMenuParts.Separator {}

                // Two lines, as the mock breaks them; each wraps by word
                // when the menu is narrower.
                PlatinumMenuParts.Hint {
                    rightInset: frame.rightInset
                    wordSpacing: 3
                    text: "Tab this page/default · F float · 1 2 3 windows"
                }
                PlatinumMenuParts.Hint {
                    Layout.topMargin: 0
                    rightInset: frame.rightInset
                    wordSpacing: 3
                    text: "←→ gap · Z zen · Esc close"
                }
            }
        }

        PlatinumScrollBar {
            id: scrollBar
            flickable: flick
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }
    }

    // Window scope, as the Sound menu has them: they work wherever focus is.
    Shortcut { sequence: "Tab"; context: Qt.WindowShortcut; onActivated: frame.switchTab() }
    Shortcut { sequence: "Backtab"; context: Qt.WindowShortcut; onActivated: frame.switchTab() }
    Shortcut { sequence: "F"; context: Qt.WindowShortcut; onActivated: frame.toggleArrange() }
    Shortcut { sequence: "1"; context: Qt.WindowShortcut; onActivated: frame.setCap(1) }
    Shortcut { sequence: "2"; context: Qt.WindowShortcut; onActivated: frame.setCap(2) }
    Shortcut { sequence: "3"; context: Qt.WindowShortcut; onActivated: frame.setCap(3) }
    Shortcut { sequence: "Left"; context: Qt.WindowShortcut; autoRepeat: true; onActivated: frame.stepGap(-1) }
    Shortcut { sequence: "Right"; context: Qt.WindowShortcut; autoRepeat: true; onActivated: frame.stepGap(1) }
    Shortcut { sequence: "Z"; context: Qt.WindowShortcut; onActivated: frame.toggleZen() }
}
