pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

// The desktop theme picker in Windows 98's words: Display Properties, the
// Appearance tab. Theme and Scheme drop-down lists over a preview that
// follows the selection; OK and Apply commit through the shared
// ThemePicker model, Cancel closes without a change. The draft lives only
// here; the saved choice is the state files'.
//
// A Win98 scheme preview is drawn live in that scheme's palette. Another
// theme's preview is its registered thumbnail (themes.json), so this view
// never loads that theme's QML. Win98 has no Extra dark: the option is not
// shown and the stored value passes through unchanged.
//
// The Scale tab holds the interface scale commands the omni bar runs.
//
// Keys: Tab moves; Alt+T and Alt+S open the lists' focus, Alt+A applies;
// Enter runs the default button; Esc cancels. Ctrl+Tab changes the tab.
PanelWindow {
    id: win

    required property var model

    readonly property real u: Win98Tokens.unitFor(win)
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "mountainous-picker"
    focusable: true
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property real barHeight: 28 * u
    readonly property real area: height - barHeight
    // The taskbar stays usable under the picker.
    mask: Region { x: 0; y: 0; width: win.width; height: Math.max(0, win.area) }


    // ---- the draft
    // This theme first, then the others in registry order.
    readonly property var themes: model.themes.filter(function (t) { return t.id === "win98"; })
        .concat(model.themes.filter(function (t) { return t.id !== "win98"; }))
    property int themeIndex: Math.max(0, themes.findIndex(function (t) { return t.id === win.model.currentTheme; }))
    readonly property var theme: themes[themeIndex] || null
    readonly property var schemes: theme ? theme.appearances : []
    property int schemeIndex: Math.max(0, schemes.findIndex(function (a) { return a.mode === win.model.currentMode; }))
    readonly property var scheme: schemes[schemeIndex] || null
    readonly property bool changed: !!theme && !!scheme && (theme.id !== model.currentTheme || scheme.mode !== model.currentMode)
    property int tab: 0

    function pickTheme(i) {
        const mode = win.scheme ? win.scheme.mode : win.model.currentMode;
        win.themeIndex = i;
        const next = win.themes[i].appearances.findIndex(function (a) { return a.mode === mode; });
        win.schemeIndex = Math.max(0, next);
    }
    function apply() {
        if (win.changed) win.model.apply(win.theme.id, win.scheme.mode, win.model.extraDark);
    }
    function ok() {
        const go = win.changed;
        const id = win.theme ? win.theme.id : "", mode = win.scheme ? win.scheme.mode : "";
        win.model.close();
        if (go) win.model.apply(id, mode, win.model.extraDark);
    }

    MouseArea {
        anchors.fill: parent
        onPressed: win.model.close()
    }

    // Small screens. Narrow: labels go above their lists and the buttons
    // stack. Short: the preview gives way first, then the note; only then
    // does the dialog scroll, and the focused control scrolls into view.
    readonly property real buttonRow: 3 * 75 * win.u + 12 * win.u
    readonly property bool stackLabels: sheet.width < 62 * win.u + 100 * win.u
    readonly property real previewNatural: 150 * win.u
    // Measured after layout settles, not bound: the list's height feeds
    // the window's own height, so a binding would loop. The sum is a fixed
    // point (what the list gives up, it adds back).
    property real natural: 0
    function measureNatural() { win.natural = dialog.implicitHeight + (previewNatural - preview.height)
        + (note.visible ? 0 : note.height + 8 * win.u); }
    Connections {
        target: dialog
        function onImplicitHeightChanged() { Qt.callLater(win.measureNatural); }
    }
    Component.onCompleted: Qt.callLater(win.measureNatural)
    readonly property real squeeze: Math.max(0, natural - win.area)
    readonly property real previewHeight: {
        const h = Math.floor((previewNatural - squeeze) / win.u) * win.u;
        return h >= 40 * win.u ? h : 0;
    }
    readonly property bool dropNote: squeeze > previewNatural + 0.5
    Connections {
        target: dialog.Window.window
        ignoreUnknownSignals: true
        function onActiveFocusItemChanged() { Qt.callLater(win.revealFocus); }
    }
    function revealFocus() {
        const item = dialog.Window.activeFocusItem;
        if (!item || !bar.visible) return;
        const top = item.mapToItem(scroller.contentItem, 0, 0).y;
        let y = scroller.contentY;
        if (top < y) y = top - 4 * win.u;
        else if (top + item.height > y + scroller.height) y = top + item.height - scroller.height + 4 * win.u;
        scroller.contentY = Math.max(0, Math.min(scroller.contentHeight - scroller.height, y));
    }

    // A screen shorter than the dialog scrolls it, so OK, Cancel and Apply
    // stay reachable by the pointer too (the keys reach them anyway).
    Flickable {
        id: scroller
        width: win.width - (bar.visible ? 18 * win.u : 0)
        height: Math.max(0, win.area)
        contentWidth: width
        contentHeight: Math.max(height, dialog.height)
        interactive: false
        clip: true
        WheelHandler {
            onWheel: event => {
                const max = Math.max(0, scroller.contentHeight - scroller.height);
                scroller.contentY = Math.max(0, Math.min(max, scroller.contentY - event.angleDelta.y / 120 * 40 * win.u));
            }
        }

    Win98Window {
        id: dialog
        objectName: "pickerDialog"
        width: Math.min(410 * win.u, win.width - 4 * win.u)
        x: Win98Tokens.half((win.width - width) / 2, win.u)
        y: Math.max(0, Win98Tokens.snap(win.area / 2 - height / 2, win.u))
        title: "Display Properties"
        showHelp: true
        margins: false
        focus: true
        onCloseClicked: win.model.close()

        Item {
            id: dp
            x: 6 * win.u; y: 4 * win.u
            width: dialog.width - 18 * win.u
            implicitWidth: width
            implicitHeight: column.height + 10 * win.u

            Column {
                id: column
                width: parent.width
                spacing: 6 * win.u

                Win98Tabs {
                    id: tabs
                    width: parent.width
                    height: tabs.strip - 2 * win.u + sheet.height + 20 * win.u
                    tabs: ["Appearance", "Scale"]
                    currentIndex: win.tab
                    padUnits: 0
                    onSelected: function (i) { win.tab = i; }

                    Item {
                        id: sheet
                        x: 8 * win.u; y: 10 * win.u
                        width: dp.width - 16 * win.u
                        height: appearance.height

                        Column {
                            id: appearance
                            visible: win.tab === 0
                            width: parent.width
                            spacing: 8 * win.u

                            Win98Bevel {
                                id: preview
                                objectName: "pickerPreview"
                                visible: height > 0
                                width: parent.width
                                height: win.previewHeight
                                variant: "field"
                                clip: true
                                color: win.theme && win.theme.id === "win98" ? Win98Tokens.palette(win.scheme && win.scheme.mode === "dark").desktop : "#000000"

                                Win98Preview {
                                    visible: !!win.theme && win.theme.id === "win98"
                                    x: 2 * win.u; y: 2 * win.u
                                    width: parent.width - 4 * win.u
                                    height: parent.height - 4 * win.u
                                    scheme: Win98Tokens.palette(!!win.scheme && win.scheme.mode === "dark")
                                }
                                Image {
                                    visible: !!win.theme && win.theme.id !== "win98"
                                    x: 2 * win.u; y: 2 * win.u
                                    width: parent.width - 4 * win.u
                                    height: parent.height - 4 * win.u
                                    fillMode: Image.PreserveAspectFit
                                    horizontalAlignment: Image.AlignHCenter
                                    verticalAlignment: Image.AlignVCenter
                                    smooth: true
                                    source: visible && win.scheme ? win.model.preview(win.theme.id, win.scheme.mode) : ""
                                }
                            }
                            Grid {
                                columns: win.stackLabels ? 1 : 2
                                columnSpacing: 6 * win.u
                                rowSpacing: 2 * win.u
                                Item { width: win.stackLabels ? sheet.width : 56 * win.u; height: win.stackLabels ? 13 * win.u : 21 * win.u; Win98Text { y: win.stackLabels ? 0 : 4 * win.u; text: "&Theme:" } }
                                Win98ComboBox {
                                    id: themeBox
                                    objectName: "pickerTheme"
                                    width: win.stackLabels ? sheet.width : sheet.width - 62 * win.u
                                    model: win.themes.map(function (t) { return t.label; })
                                    currentIndex: win.themeIndex
                                    focus: true
                                    onActivated: function (i) { win.pickTheme(i); }
                                }
                            }
                            Grid {
                                columns: win.stackLabels ? 1 : 2
                                columnSpacing: 6 * win.u
                                rowSpacing: 2 * win.u
                                Item { width: win.stackLabels ? sheet.width : 56 * win.u; height: win.stackLabels ? 13 * win.u : 21 * win.u; Win98Text { y: win.stackLabels ? 0 : 4 * win.u; text: "&Scheme:" } }
                                Win98ComboBox {
                                    id: schemeBox
                                    objectName: "pickerScheme"
                                    width: win.stackLabels ? sheet.width : sheet.width - 62 * win.u
                                    model: win.schemes.map(function (a) { return a.label; })
                                    currentIndex: win.schemeIndex
                                    onActivated: function (i) { win.schemeIndex = i; }
                                }
                            }
                            Win98Text {
                                id: note
                                visible: !win.dropNote || win.model.error !== ""
                                width: parent.width
                                wrap: true
                                accessMarks: false
                                color: win.model.error !== "" ? Win98Tokens.danger : Win98Tokens.gray
                                text: win.model.error !== "" ? win.model.error
                                    : "A theme sets the bars, the menus and the font. A scheme sets the colours. Each theme has its own schemes."
                            }
                        }

                        Column {
                            visible: win.tab === 1
                            width: parent.width
                            spacing: 8 * win.u
                            Win98Text {
                                width: parent.width
                                wrap: true
                                accessMarks: false
                                text: "Make everything on the screen larger or smaller. The keys do the same: Super+= and Super+-."
                            }
                            Flow {
                                width: parent.width
                                spacing: 6 * win.u
                                Win98Button { text: "Scale &up"; onClicked: Quickshell.execDetached(["hypr-scale", "up"]) }
                                Win98Button { text: "Scale &down"; onClicked: Quickshell.execDetached(["hypr-scale", "down"]) }
                                Win98Button { text: "&100%"; onClicked: Quickshell.execDetached(["hypr-scale", "reset"]) }
                            }
                        }
                    }
                }

                // One row while it fits; stacked, right-aligned, when not.
                Grid {
                    x: parent.width - width
                    topPadding: 6 * win.u
                    columns: dp.width >= win.buttonRow ? 3 : 1
                    spacing: 6 * win.u
                    Win98Button {
                        id: okButton
                        widthUnits: dp.width < 75 * win.u ? Math.floor(dp.width / win.u) : 0
                        objectName: "pickerOk"
                        text: "OK"
                        isDefault: !applyButton.activeFocus && !cancelButton.activeFocus
                        onClicked: win.ok()
                    }
                    Win98Button {
                        id: cancelButton
                        widthUnits: okButton.widthUnits
                        objectName: "pickerCancel"
                        text: "Cancel"
                        isDefault: activeFocus
                        onClicked: win.model.close()
                    }
                    Win98Button {
                        id: applyButton
                        widthUnits: okButton.widthUnits
                        objectName: "pickerApply"
                        text: "&Apply"
                        enabled: win.changed && !win.model.applying
                        isDefault: activeFocus
                        onClicked: win.apply()
                    }
                }
            }
        }
    }

    // A press on the dialog stays in the dialog.
    MouseArea {
        x: dialog.x; y: dialog.y; width: dialog.width; height: dialog.height
        z: -1
        onPressed: function (mouse) { mouse.accepted = true; }
    }
    }
    Win98ScrollBar {
        id: bar
        objectName: "pickerScroll"
        visible: dialog.height > win.area + 0.5
        x: win.width - width
        height: Math.max(0, win.area)
        flickable: scroller
        step: 20 * win.u
    }

    // A state drawn without the pointer (state sheets and the harness):
    // { theme, scheme, drop: "theme"|"scheme", applyFocus }.
    function show(state) {
        if (state.theme !== undefined) win.pickTheme(Math.max(0, win.themes.findIndex(function (t) { return t.id === state.theme; })));
        if (state.scheme !== undefined) win.schemeIndex = Math.max(0, win.schemes.findIndex(function (a) { return a.mode === state.scheme; }));
        themeBox.open = state.drop === "theme";
        schemeBox.open = state.drop === "scheme";
        if (state.drop === "theme") themeBox.forceActiveFocus();
        else if (state.drop === "scheme") schemeBox.forceActiveFocus();
        else if (state.applyFocus) applyButton.forceActiveFocus();
    }

    Shortcut { sequence: "Escape"; context: Qt.WindowShortcut; enabled: !themeBox.open && !schemeBox.open; onActivated: win.model.close() }
    Shortcut {
        sequences: ["Return", "Enter"]
        context: Qt.WindowShortcut
        enabled: !themeBox.open && !schemeBox.open
        onActivated: {
            if (applyButton.activeFocus) win.apply();
            else if (cancelButton.activeFocus) win.model.close();
            else win.ok();
        }
    }
    Shortcut { sequence: "Alt+T"; context: Qt.WindowShortcut; onActivated: { win.tab = 0; themeBox.forceActiveFocus(); } }
    Shortcut { sequence: "Alt+S"; context: Qt.WindowShortcut; onActivated: { win.tab = 0; schemeBox.forceActiveFocus(); } }
    Shortcut { sequence: "Alt+A"; context: Qt.WindowShortcut; enabled: applyButton.enabled; onActivated: win.apply() }
    Shortcut { sequence: "Ctrl+Tab"; context: Qt.WindowShortcut; onActivated: win.tab = (win.tab + 1) % 2 }
}
