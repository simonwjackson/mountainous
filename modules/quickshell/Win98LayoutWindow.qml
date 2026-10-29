pragma ComponentBehavior: Bound

import Hensou as Kit
import QtQuick
import "themes/win98/session-model.js" as Session
import "themes/win98/tray-model.js" as Tray

// Layout, as a Win98 property sheet over the page this screen shows: This
// Page and Default tabs, then Arrange (Tiled or Floating), Windows on this
// page (three toggle buttons with a picture of the tiles, the selected one
// pressed over the dither), and Outer gap (a trackbar with a tick every
// 4 px, its value in a sunken box, and Zen margins). The shared PageLayout
// (panels/PageLayout.qml) owns every value and every change; this view
// keeps nothing of its own. Approved mock: /tmp/layout-mock (theme=w98);
// behaviour and wording: docs/plans/page-layout-control.md.
//
// A Floating page greys out the capacity and gap groups: capacity is not
// enforced there and gaps apply only to tiled windows.
//
// Keys, as the Sound window's: Tab, Shift+Tab and Ctrl+Tab switch the tab
// (Alt+T, Alt+D pick one); T and F arrange; 1, 2, 3 set the windows per
// page; Left/Right (or [ and ]) step the gap by 4 px, Home and End go to
// its ends; D runs the next Use Default; Z toggles Zen margins; R runs
// Reset All; Esc closes (the host). The underlined letters are these keys.
// The status bar names the session's keys, which work without the window:
// Win+F, Win+1 2 3 and Win+Shift+[ ] (Win+[ ] cycle windows). A narrow
// window says them shorter; a short one drops the line, and ? brings it
// back (the body scrolls then), so the hint is never out of reach.
//
// Size: themes/win98/session-model.js layoutPlan decides. A narrow screen
// drops the buttons' pictures, then stands the buttons in one column; a
// short one tightens the gaps, flattens the buttons, moves the sheet's
// first line into the caption and drops the key hints, and only then
// scrolls the body.
Win98Window {
    id: root

    required property var layout

    readonly property bool pageTab: layout.tab === "page"
    readonly property var shown: layout.shownValues
    readonly property bool floating: shown.floating
    readonly property var page: layout.page
    readonly property var def: layout.def

    // What yields, from the window's width (the host keeps it 2 u inside
    // the screen) and the room above the taskbar.
    readonly property var plan: Session.layoutPlan(Math.round(width / u) + 4, Math.floor(availableHeight / u + 1e-6), natural, saves)
    readonly property real gapSheet: (plan.tight ? 4 : 10) * u
    readonly property real gapGroup: (plan.tight ? 4 : 7) * u

    title: plan.intro ? "Layout" : "Layout - " + layout.title
    iconName: Tray.layoutIcon(floating ? "float" : "tile-" + shown.cap)
    showHelp: true
    margins: false
    onCloseClicked: MenuState.close()
    // ?: the key hints, even where the room dropped them.
    property bool hintsAsked: false
    onHelpClicked: root.hintsAsked = !root.hintsAsked
    readonly property bool hintsShown: plan.status || hintsAsked
    // The session's keys, in full while they fit one line of the status
    // bar, then shorter (the bar wraps either to two lines before it elides).
    readonly property string hintsFull: "Win+F float \u00b7 Win+1, 2, 3 windows \u00b7 Win+Shift+[ ] gap"
    readonly property string hintsShort: "Win+F \u00b7 Win+1 2 3 \u00b7 Win+Shift+[ ]"
    readonly property string hints: Kit.Win98Tokens.textWidth(hintsFull, false, u) + 8 * u <= width - 24 * u ? hintsFull : hintsShort

    // The natural height (units) with nothing yielded. Measured after
    // layout settles, not bound, as the Sound window does: what the steps
    // take away is added back, so the sum is a fixed point.
    property real natural: 0
    // From the data, never from what the plan shows (that would loop):
    // tight takes 6 u from each gap between the sheet's rows (the intro
    // line, three groups, Reset All's row), 3 u from each gap inside the
    // groups, 3 u from each group's top and the sheet's 2-u top padding.
    readonly property bool resetShown: !pageTab && layout.ownCount > 0
    readonly property int sheetGaps: 3 + (resetShown ? 1 : 0)
    readonly property int groupGaps: (capDiffers ? 1 : 0) + (floating ? 1 : 0) + (gapDiffers ? 1 : 0) + (pageTab ? 1 : 0) + 1
    readonly property var saves: ({
        tight: 6 * sheetGaps + 3 * groupGaps + 3 * 3 + 2,
        flat: 22,
        intro: 13 + 4,
        status: Math.round(status.height / u) + 5
    })
    function saved() {
        let n = 0;
        for (const s of root.plan.steps)
            n += (s === "flat" && root.plan.columns === 1) || (s === "status" && root.hintsAsked) ? 0 : root.saves[s];
        return n;
    }
    Timer {
        id: naturalMeasure
        interval: 0
        onTriggered: root.natural = Math.round(root.implicitHeight / root.u) + root.saved()
    }
    Connections {
        target: root
        function onImplicitHeightChanged() { naturalMeasure.restart(); }
    }
    Component.onCompleted: naturalMeasure.restart()

    // A gap drag sends one value at a time (PageLayout coalesces it).
    Binding {
        target: root.layout
        property: "dragging"
        value: slider.held
    }

    function setTab(i) { root.layout.tab = i === 0 ? "page" : "default"; }
    function otherTab() { root.setTab(root.pageTab ? 1 : 0); }
    // Use Default, in the order the buttons stand: the capacity's, then
    // the gap's. Each one disappears once its value is the default.
    readonly property bool capDiffers: pageTab && !floating && page.cap !== def.cap
    readonly property bool gapDiffers: pageTab && !floating && page.gap !== def.gap
    function useNextDefault() {
        if (root.capDiffers) root.layout.useDefault("cap");
        else if (root.gapDiffers) root.layout.useDefault("gap");
    }
    function pagesDiffer(n) { return n === 1 ? "1 page differs from this." : n + " pages differ from this."; }
    // A group's title keeps its key while it fits.
    function titled(full, short, width) {
        return Kit.Win98Tokens.textWidth(Kit.Win98Tokens.plainText(full), false, root.u) + 16 * root.u <= width ? full : short;
    }

    Item {
        x: 6 * root.u; y: 6 * root.u
        width: root.bodyWidth - 12 * root.u
        implicitHeight: body.height + 9 * root.u

        Column {
            id: body
            width: parent.width

            Win98Tabs {
                id: tabs
                width: parent.width
                height: implicitHeight
                tabs: ["&This Page", "&Default"]
                currentIndex: root.pageTab ? 0 : 1
                padUnits: 8
                // The sheet has the keyboard: its tab shows the focus.
                showFocus: true
                onSelected: function (i) { root.setTab(i); }

                Column {
                    id: sheet
                    width: tabs.width - 16 * root.u
                    topPadding: root.plan.tight ? 0 : 2 * root.u
                    spacing: root.gapSheet

                    Win98Text {
                        visible: root.plan.intro
                        width: Math.min(implicitWidth, parent.width)
                        text: root.pageTab ? "This page on " + root.layout.title + "." : "New pages on " + root.layout.title + " start like this."
                        accessMarks: false
                    }

                    Win98GroupBox {
                        id: arrange
                        width: parent.width
                        title: root.pageTab ? root.titled("Arrange (Win+F)", "Arrange", width) : "Arrange new pages"
                        padUnits: 9
                        topUnits: root.plan.tight ? 11 : 14
                        Grid {
                            id: radios
                            readonly property bool fits: tiled.implicitWidth + floatingRadio.implicitWidth + 22 * root.u <= arrange.width - 18 * root.u
                            columns: fits ? 2 : 1
                            columnSpacing: 22 * root.u
                            rowSpacing: root.gapGroup
                            Win98RadioButton {
                                id: tiled
                                objectName: "layoutTiled"
                                text: "&Tiled"
                                checked: !root.floating
                                onClicked: root.layout.setArrange(false)
                            }
                            Win98RadioButton {
                                id: floatingRadio
                                objectName: "layoutFloating"
                                text: "&Floating"
                                checked: root.floating
                                onClicked: root.layout.setArrange(true)
                            }
                        }
                    }

                    Win98GroupBox {
                        id: capacity
                        width: parent.width
                        title: root.pageTab ? root.titled("Windows on this page (Win+1 2 3)", "Windows on this page", width) : "Windows per page"
                        titleDisabled: root.floating
                        padUnits: 9
                        topUnits: root.plan.tight ? 11 : 14
                        Column {
                            id: capBody
                            width: capacity.width - 18 * root.u
                            spacing: root.gapGroup

                            Grid {
                                id: caps
                                columns: root.plan.columns
                                columnSpacing: 6 * root.u
                                rowSpacing: 4 * root.u
                                // Three across share the row; the last takes
                                // what rounding leaves, so the row ends on the
                                // group's edge.
                                readonly property real each: Math.floor((capBody.width - 12 * root.u) / 3 / root.u) * root.u
                                Repeater {
                                    model: [1, 2, 3]
                                    CapButton {
                                        required property int modelData
                                        n: modelData
                                        width: root.plan.columns === 1 ? capBody.width
                                            : modelData < 3 ? caps.each : capBody.width - 2 * caps.each - 12 * root.u
                                    }
                                }
                            }
                            Win98Text {
                                width: parent.width
                                wrap: true
                                lineUnits: 15
                                accessMarks: false
                                disabledLook: root.floating
                                text: root.pageTab ? root.layout.capNote() : "Win+1 2 3 change only the current page."
                            }
                            NoteRow {
                                visible: root.capDiffers
                                text: "New pages start with " + root.def.cap + "."
                                button: "Use &Default"
                                buttonName: "layoutCapDefault"
                                onClicked: root.layout.useDefault("cap")
                            }
                        }
                    }

                    Win98GroupBox {
                        id: gap
                        width: parent.width
                        title: root.pageTab ? root.titled("Outer gap (Win+Shift+[ ])", "Outer gap", width) : "Outer gap"
                        titleDisabled: root.floating
                        padUnits: 9
                        topUnits: root.plan.tight ? 11 : 14
                        Column {
                            id: gapBody
                            width: gap.width - 18 * root.u
                            spacing: root.gapGroup

                            // The trackbar and its value; None and 48 under
                            // its ends, 6 u into the row's gap (the mock).
                            Item {
                                width: parent.width
                                height: 42 * root.u
                                Win98Slider {
                                    id: slider
                                    objectName: "layoutGap"
                                    width: Math.max(40 * root.u, parent.width - valueBox.width - 6 * root.u)
                                    enabled: !root.floating
                                    ticks: root.layout.gapMax / root.layout.gapStep + 1
                                    majorEvery: 2
                                    stepSize: root.layout.gapStep / root.layout.gapMax
                                    value: root.layout.shownGap / root.layout.gapMax
                                    onMoved: function (v) { root.layout.setGap(v * root.layout.gapMax); }
                                }
                                Win98Bevel {
                                    id: valueBox
                                    x: parent.width - width
                                    width: Math.max(44 * root.u, Kit.Win98Tokens.ceilU(valueText.implicitWidth, root.u) + 8 * root.u)
                                    height: Kit.Win98Tokens.fieldHeight * root.u
                                    variant: "field"
                                    color: root.floating ? Kit.Win98Tokens.face : Kit.Win98Tokens.win
                                    Win98Text {
                                        id: valueText
                                        objectName: "layoutGapValue"
                                        x: parent.width - width - 4 * root.u
                                        y: 4 * root.u
                                        text: root.layout.shownGap + " px"
                                        accessMarks: false
                                        color: Kit.Win98Tokens.winText
                                        disabledLook: root.floating
                                    }
                                }
                                Win98Text {
                                    y: 29 * root.u
                                    text: "None"
                                    accessMarks: false
                                    disabledLook: root.floating
                                }
                                Win98Text {
                                    x: slider.width - width
                                    y: 29 * root.u
                                    text: String(root.layout.gapMax)
                                    accessMarks: false
                                    disabledLook: root.floating
                                }
                            }
                            Win98Text {
                                visible: root.floating
                                width: parent.width
                                wrap: true
                                lineUnits: 15
                                accessMarks: false
                                disabledLook: true
                                text: "Gaps apply to tiled windows."
                            }
                            NoteRow {
                                visible: root.gapDiffers
                                text: "New pages use " + root.def.gap + " px."
                                button: "Use &Default"
                                buttonName: "layoutGapDefault"
                                onClicked: root.layout.useDefault("gap")
                            }
                            Win98CheckBox {
                                visible: root.pageTab
                                objectName: "layoutZen"
                                width: Math.min(implicitWidth, parent.width)
                                text: zenFits ? "&Zen margins (Win+Shift+M)" : "&Zen margins"
                                readonly property bool zenFits: Kit.Win98Tokens.textWidth("Zen margins (Win+Shift+M)", false, root.u) + 18 * root.u <= parent.width
                                checked: root.page.zen
                                enabled: !root.floating
                                onToggled: root.layout.toggleZen()
                            }
                        }
                    }

                    NoteRow {
                        visible: root.resetShown
                        width: parent.width
                        text: root.pagesDiffer(root.layout.ownCount)
                        button: "&Reset All"
                        buttonName: "layoutResetAll"
                        onClicked: root.layout.resetPages()
                    }
                }
            }

            Item {
                visible: root.hintsShown
                width: parent.width
                height: status.height + 5 * root.u
                Win98StatusBar {
                    id: status
                    y: 5 * root.u
                    width: parent.width
                    objectName: "layoutHints"
                    panes: [root.hints]
                }
            }
        }
    }

    // One "Windows on this page" button: the picture of its tiles over the
    // label (beside it when flat), raised, or pressed over the dither when
    // it is the page's capacity. A Floating page greys it.
    component CapButton: Item {
        id: cap
        property int n: 1
        readonly property bool selected: root.shown.cap === n
        readonly property bool live: !root.floating
        readonly property bool down: selected || (area.pressed && area.containsMouse && live)
        objectName: "layoutCap" + n
        height: (root.plan.flat ? 24 : 46) * root.u

        Rectangle { anchors.fill: parent; color: Kit.Win98Tokens.face }
        Win98Dither {
            visible: cap.selected
            x: 2 * root.u; y: 2 * root.u
            width: cap.width - 4 * root.u
            height: cap.height - 4 * root.u
        }
        Win98Bevel {
            anchors.fill: parent
            filled: false
            variant: cap.down ? "pressed" : "button"
        }
        Grid {
            id: face
            columns: root.plan.flat ? 2 : 1
            spacing: (root.plan.flat ? 4 : 5) * root.u
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            x: Kit.Win98Tokens.snap((cap.width - width) / 2, root.u) + (cap.down ? root.u : 0)
            y: Kit.Win98Tokens.snap((cap.height - height) / 2, root.u) + (cap.down ? root.u : 0)
            Win98Icon {
                visible: root.plan.picto
                name: "layout-picto-" + cap.n + (cap.live ? "" : "-off")
                opacity: cap.live ? 1 : 0.5
            }
            Win98Text {
                text: root.layout.word(cap.n)
                accessMarks: false
                disabledLook: !cap.live
                width: Math.min(implicitWidth, cap.width - (root.plan.flat && root.plan.picto ? 42 : 8) * root.u)
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            enabled: cap.live
            onClicked: root.layout.setCap(cap.n)
        }
    }

    // A line of text with its button at the right end; the text wraps
    // beside the button.
    component NoteRow: Item {
        id: row
        property string text: ""
        property string button: ""
        property string buttonName: ""
        signal clicked
        width: parent ? parent.width : 0
        height: Math.max(Kit.Win98Tokens.buttonHeight * root.u, Kit.Win98Tokens.ceilU(note.implicitHeight, root.u))
        Win98Text {
            id: note
            y: Kit.Win98Tokens.snap((row.height - Kit.Win98Tokens.ceilU(implicitHeight, root.u)) / 2, root.u)
            width: Math.max(0, row.width - push.width - 6 * root.u)
            wrap: true
            lineUnits: 15
            accessMarks: false
            text: row.text
        }
        Win98Button {
            id: push
            objectName: row.buttonName
            x: row.width - width
            y: Kit.Win98Tokens.snap((row.height - height) / 2, root.u)
            text: row.button
            onClicked: row.clicked()
        }
    }

    Shortcut { sequences: ["Tab", "Backtab", "Ctrl+Tab", "Ctrl+Backtab", "Ctrl+Shift+Tab"]; context: Qt.WindowShortcut; onActivated: root.otherTab() }
    Shortcut { sequence: "Alt+T"; context: Qt.WindowShortcut; onActivated: root.setTab(0) }
    Shortcut { sequence: "Alt+D"; context: Qt.WindowShortcut; onActivated: root.setTab(1) }
    Shortcut { sequence: "T"; context: Qt.WindowShortcut; onActivated: root.layout.setArrange(false) }
    Shortcut { sequences: ["F", "Alt+F"]; context: Qt.WindowShortcut; onActivated: root.layout.setArrange(true) }
    Shortcut { sequence: "1"; context: Qt.WindowShortcut; enabled: !root.floating; onActivated: root.layout.setCap(1) }
    Shortcut { sequence: "2"; context: Qt.WindowShortcut; enabled: !root.floating; onActivated: root.layout.setCap(2) }
    Shortcut { sequence: "3"; context: Qt.WindowShortcut; enabled: !root.floating; onActivated: root.layout.setCap(3) }
    Shortcut { sequences: ["Left", "Down", "["]; context: Qt.WindowShortcut; enabled: !root.floating; onActivated: root.layout.stepGap(-1) }
    Shortcut { sequences: ["Right", "Up", "]"]; context: Qt.WindowShortcut; enabled: !root.floating; onActivated: root.layout.stepGap(1) }
    Shortcut { sequence: "Home"; context: Qt.WindowShortcut; enabled: !root.floating; onActivated: root.layout.setGap(0) }
    Shortcut { sequence: "End"; context: Qt.WindowShortcut; enabled: !root.floating; onActivated: root.layout.setGap(root.layout.gapMax) }
    Shortcut { sequence: "D"; context: Qt.WindowShortcut; enabled: root.capDiffers || root.gapDiffers; onActivated: root.useNextDefault() }
    Shortcut { sequences: ["Z", "Alt+Z"]; context: Qt.WindowShortcut; enabled: root.pageTab && !root.floating; onActivated: root.layout.toggleZen() }
    Shortcut { sequences: ["R", "Alt+R"]; context: Qt.WindowShortcut; enabled: !root.pageTab && root.layout.ownCount > 0; onActivated: root.layout.resetPages() }
}
