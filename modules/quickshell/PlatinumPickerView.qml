import Quickshell
import QtQuick
import "themes/platinum/picker-plan.js" as PickerPlan

// Appearance uses thumbnails only when a complete labelled choice fits.
// Short windows use a text list. At the shortest heights the whole body,
// including Close and Extra dark, scrolls; no fixed rows can starve it.
PanelWindow {
    id: win
    required property var model
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    color: "transparent"
    readonly property var plan: PickerPlan.plan(width, height)
    property var focusedControl: null
    readonly property real labelLeft: win.plan.stackedOption ? PlatinumTokens.menuGutter : Math.min(PlatinumTokens.menuTextLeft, body.width / 3)
    readonly property real rightInset: Math.min(PlatinumTokens.menuRightInset, body.width / 6)

    function rememberFocus(item) {
        focusedControl = item;
        Qt.callLater(revealFocused);
    }
    function revealFocused() {
        // A theme swap can destroy the view before this delayed call runs.
        if (typeof win.reveal !== "function")
            return;
        const item = focusedControl;
        if (item && item.visible && item.activeFocus)
            reveal(item);
    }
    function reveal(item) {
        const top = item.mapToItem(body.contentItem, 0, 0).y;
        let y = body.contentY;
        if (item.height > body.height || top < y)
            y = top;
        else if (top + item.height > y + body.height)
            y = top + item.height - body.height;
        body.contentY = Math.max(0, Math.min(y, Math.max(0, body.contentHeight - body.height)));
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.model.close()
    }
    PlatinumBevel {
        id: panel
        objectName: "pickerPanel"
        anchors.centerIn: parent
        width: win.plan.width
        height: win.plan.height
        color: PlatinumTokens.menuSurface
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: header
            x: win.plan.padding
            y: win.plan.padding
            width: Math.max(1, panel.width - 2 * win.plan.padding)
            height: win.plan.headerHeight
            visible: !win.plan.closeInBody
            CloseControl {
                objectName: "pickerClose"
                model: win.model
            }
            Text {
                id: title
                visible: win.plan.thumbnails
                anchors.centerIn: parent
                text: "Appearance"
                color: PlatinumTokens.menuText
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumText
            }
            TitleStripes {
                visible: title.visible
                x: PickerPlan.toolbarHeight + win.plan.gap
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, title.x - x - win.plan.gap)
            }
            TitleStripes {
                visible: title.visible
                x: title.x + title.width + win.plan.gap
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, header.width - x - win.plan.gap)
            }
        }

        PlatinumTabs {
            id: tabs
            x: win.plan.padding
            y: header.y + header.height + win.plan.gap
            width: header.width
            height: win.plan.tabsHeight
            visible: win.plan.thumbnails
            model: [
                {
                    key: "themes",
                    label: "Themes"
                }
            ]
            current: "themes"
        }

        Item {
            id: well
            x: win.plan.padding
            y: win.plan.padding + (header.visible ? header.height + win.plan.gap : 0) + (tabs.visible ? tabs.height + win.plan.gap : 0)
            width: header.width
            height: Math.max(1, panel.height - y - win.plan.padding)
            readonly property real barWidth: Math.min(PlatinumTokens.menuScrollBar, Math.max(0, width - 1))
            readonly property real inset: Math.min(PlatinumTokens.menuGutter, (width - barWidth) / 4, height / 6)
            PlatinumBevel {
                anchors.fill: parent
                sunken: true
                color: PlatinumTokens.well
            }

            Flickable {
                id: body
                objectName: "pickerBody"
                x: well.inset
                y: well.inset
                width: Math.max(1, well.width - well.barWidth - 2 * well.inset)
                height: Math.max(1, well.height - 2 * well.inset)
                clip: true
                contentWidth: width
                contentHeight: contents.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                onHeightChanged: Qt.callLater(win.revealFocused)
                onWidthChanged: Qt.callLater(win.revealFocused)
                onContentHeightChanged: Qt.callLater(win.revealFocused)

                Column {
                    id: contents
                    width: body.width
                    spacing: win.plan.gap

                    CloseControl {
                        id: bodyClose
                        objectName: "pickerClose"
                        model: win.model
                        visible: win.plan.closeInBody
                        onRevealRequested: win.rememberFocus(bodyClose)
                    }
                    Grid {
                        id: grid
                        width: body.width
                        columns: win.plan.thumbnails ? Math.max(1, Math.floor((body.width + spacing) / (PickerPlan.thumbnailWidth + spacing))) : 1
                        spacing: win.plan.gap
                        Repeater {
                            model: win.model.choices
                            delegate: FocusScope {
                                id: choice
                                objectName: "pickerChoice-" + index
                                required property var modelData
                                required property int index
                                readonly property bool selected: win.model.currentTheme === modelData.theme && win.model.currentMode === modelData.mode
                                width: (body.width - (grid.columns - 1) * grid.spacing) / grid.columns
                                height: Math.max(PlatinumTokens.menuRow, label.y + label.implicitHeight + win.plan.gap)
                                activeFocusOnTab: true
                                Component.onCompleted: if (index === 0)
                                    forceActiveFocus()
                                function apply() {
                                    win.model.apply(modelData.theme, modelData.mode, win.model.extraDark);
                                }
                                onActiveFocusChanged: if (activeFocus)
                                    win.rememberFocus(choice)
                                Keys.onReturnPressed: apply()
                                Keys.onSpacePressed: apply()
                                Rectangle {
                                    anchors.fill: parent
                                    visible: !win.plan.thumbnails
                                    color: choice.selected ? PlatinumTokens.highlight : "transparent"
                                    border.width: choice.activeFocus ? PlatinumTokens.hair : 0
                                    border.color: PlatinumTokens.highlightText
                                }
                                Rectangle {
                                    id: preview
                                    objectName: "pickerChoicePreview-" + choice.index
                                    visible: win.plan.thumbnails
                                    x: win.plan.gap
                                    y: win.plan.gap
                                    width: Math.max(1, parent.width - 2 * win.plan.gap)
                                    height: visible ? Math.min(112, width * 0.625) : 0
                                    color: PlatinumTokens.menuEdge
                                    border.width: choice.selected || choice.activeFocus ? 3 : 1
                                    border.color: choice.selected || choice.activeFocus ? PlatinumTokens.highlight : PlatinumTokens.menuEdge
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        source: preview.visible ? win.model.preview(choice.modelData.theme, choice.modelData.mode) : ""
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }
                                Text {
                                    id: label
                                    objectName: "pickerChoiceLabel-" + choice.index
                                    x: win.plan.thumbnails ? 0 : win.labelLeft
                                    y: preview.visible ? preview.y + preview.height + win.plan.gap : win.plan.gap
                                    width: Math.max(1, parent.width - x - (win.plan.thumbnails ? 0 : win.rightInset))
                                    text: choice.modelData.label + "\n" + choice.modelData.appearance
                                    horizontalAlignment: win.plan.thumbnails ? Text.AlignHCenter : Text.AlignLeft
                                    wrapMode: Text.Wrap
                                    color: choice.selected ? PlatinumTokens.highlightText : PlatinumTokens.menuText
                                    font.family: PlatinumTokens.platinumFont
                                    font.pixelSize: PlatinumTokens.platinumSmall
                                    Rectangle {
                                        anchors.fill: parent
                                        color: PlatinumTokens.highlight
                                        z: -1
                                        visible: choice.selected && win.plan.thumbnails
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        choice.forceActiveFocus();
                                        choice.apply();
                                    }
                                }
                            }
                        }
                    }
                    FocusScope {
                        id: extra
                        objectName: "pickerOption"
                        visible: !!ThemeCatalog.find(win.model.currentTheme) && ThemeCatalog.find(win.model.currentTheme).options.extraDark
                        enabled: win.model.currentMode === "dark" && !win.model.applying
                        width: body.width
                        height: Math.max(PlatinumTokens.menuLine + 4, win.plan.stackedOption ? extraLabel.implicitHeight + extraMark.height + 3 * win.plan.gap : extraLabel.implicitHeight + 2 * win.plan.gap)
                        activeFocusOnTab: enabled
                        function toggle() {
                            win.model.apply(win.model.currentTheme, win.model.currentMode, !win.model.extraDark);
                        }
                        onActiveFocusChanged: if (activeFocus)
                            win.rememberFocus(extra)
                        Keys.onReturnPressed: toggle()
                        Keys.onSpacePressed: toggle()
                        Rectangle {
                            anchors.fill: parent
                            visible: extra.activeFocus
                            color: "transparent"
                            border.width: PlatinumTokens.hair
                            border.color: PlatinumTokens.highlight
                        }
                        PlatinumCheckBox {
                            id: extraMark
                            objectName: "pickerOptionMark"
                            x: win.plan.stackedOption ? win.labelLeft : Math.max(0, win.labelLeft - width - PlatinumTokens.menuGutter / 2)
                            y: win.plan.stackedOption ? extraLabel.y + extraLabel.height + win.plan.gap : (extra.height - height) / 2
                            checked: win.model.extraDark
                        }
                        Text {
                            id: extraLabel
                            objectName: "pickerOptionLabel"
                            x: win.labelLeft
                            width: Math.max(1, parent.width - x - win.rightInset)
                            y: win.plan.stackedOption ? win.plan.gap : (extra.height - height) / 2
                            text: "Extra dark"
                            wrapMode: Text.Wrap
                            color: extra.enabled ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff
                            font.family: PlatinumTokens.platinumFont
                            font.pixelSize: PlatinumTokens.platinumText
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                extra.forceActiveFocus();
                                extra.toggle();
                            }
                        }
                    }
                    Text {
                        objectName: "pickerError"
                        x: win.labelLeft
                        width: Math.max(1, body.width - x - win.rightInset)
                        visible: win.model.error !== "" || win.model.choices.length === 0
                        text: win.model.error || "No desktop themes are installed."
                        wrapMode: Text.Wrap
                        color: PlatinumTokens.menuDanger
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumSmall
                    }
                    Text {
                        x: win.labelLeft
                        width: Math.max(1, body.width - x - win.rightInset)
                        visible: win.plan.showNote
                        text: "Click a theme to use it. Changes apply at once."
                        wrapMode: Text.Wrap
                        color: PlatinumTokens.menuTextSecondary
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumSmall
                    }
                }
            }
            PlatinumScrollBar {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: well.barWidth
                flickable: body
            }
        }
    }
    component CloseControl: FocusScope {
        id: control
        required property var model
        signal revealRequested
        width: PickerPlan.toolbarHeight
        height: PickerPlan.toolbarHeight
        activeFocusOnTab: true
        onActiveFocusChanged: if (activeFocus)
            revealRequested()
        Keys.onReturnPressed: model.close()
        Keys.onSpacePressed: model.close()
        PlatinumButton {
            anchors.centerIn: parent
            icon: "close"
            focused: control.activeFocus
            onClicked: control.model.close()
        }
    }
    component TitleStripes: Item {
        height: 14
        Column {
            anchors.fill: parent
            spacing: 1
            Repeater {
                model: 5
                Rectangle {
                    width: parent.width
                    height: 1
                    color: PlatinumTokens.bevelLight
                    Rectangle {
                        y: 1
                        width: parent.width
                        height: 1
                        color: PlatinumTokens.bevelDark
                    }
                }
            }
        }
    }
    Shortcut {
        sequence: "E"
        context: Qt.WindowShortcut
        enabled: win.model.currentMode === "dark" && !!ThemeCatalog.find(win.model.currentTheme) && ThemeCatalog.find(win.model.currentTheme).options.extraDark
        onActivated: win.model.apply(win.model.currentTheme, win.model.currentMode, !win.model.extraDark)
    }
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: win.model.close()
    }
}
