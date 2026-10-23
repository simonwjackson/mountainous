import Quickshell
import QtQuick
import QtQuick.Layouts
import "themes/platinum/picker-plan.js" as PickerPlan

// The approved Mac OS 8.5 Appearance panel, using the menu's alignment grid.
// Only the theme collection scrolls. Close and Extra dark stay on the surface.
PanelWindow {
    id: win
    required property var model
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    color: "transparent"
    readonly property var plan: PickerPlan.plan(width, height)

    MouseArea { anchors.fill: parent; onClicked: win.model.close() }
    PlatinumBevel {
        id: panel
        anchors.centerIn: parent
        width: win.plan.width
        height: win.plan.height
        color: PlatinumTokens.menuSurface
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: win.plan.padding
            spacing: win.plan.gap

            RowLayout {
                Layout.fillWidth: true
                spacing: PlatinumTokens.menuGap
                PlatinumButton { icon: "close"; onClicked: win.model.close() }
                TitleStripes { Layout.fillWidth: true }
                Text {
                    text: "Appearance"
                    color: PlatinumTokens.menuText
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumText
                }
                TitleStripes { Layout.fillWidth: true }

            }

            PlatinumTabs {
                model: [{key: "themes", label: "Themes"}]
                current: "themes"
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 1
                PlatinumBevel { anchors.fill: parent; sunken: true; color: PlatinumTokens.well }
                Flickable {
                    id: choices
                    anchors.fill: parent
                    anchors.margins: PlatinumTokens.menuGutter
                    anchors.rightMargin: PlatinumTokens.menuScrollBar
                    clip: true
                    contentWidth: width
                    contentHeight: grid.implicitHeight + (errorLabel.visible ? errorLabel.implicitHeight + win.plan.gap : 0)
                    boundsBehavior: Flickable.StopAtBounds
                    Grid {
                        id: grid
                        width: choices.width
                        columns: Math.max(1, Math.floor(choices.width / PickerPlan.thumbnailWidth))
                        spacing: win.plan.gap
                        Repeater {
                            model: win.model.choices
                            delegate: FocusScope {
                                id: choice
                                required property var modelData
                                required property int index
                                readonly property bool selected: win.model.currentTheme === modelData.theme && win.model.currentMode === modelData.mode
                                width: (choices.width - (grid.columns - 1) * grid.spacing) / grid.columns
                                height: preview.height + label.implicitHeight + 12
                                activeFocusOnTab: true
                                Component.onCompleted: if (index === 0) forceActiveFocus()
                                function apply() { win.model.apply(modelData.theme, modelData.mode, win.model.extraDark); }
                                onActiveFocusChanged: if (activeFocus) choices.contentY = Math.max(0, Math.min(y, choices.contentHeight - choices.height))
                                Keys.onReturnPressed: apply()
                                Keys.onSpacePressed: apply()
                                Rectangle {
                                    id: preview
                                    x: 4
                                    y: 4
                                    width: parent.width - 8
                                    height: Math.min(112, width * 0.625)
                                    color: PlatinumTokens.menuEdge
                                    border.width: choice.selected || choice.activeFocus ? 3 : 1
                                    border.color: choice.selected || choice.activeFocus ? PlatinumTokens.highlight : PlatinumTokens.menuEdge
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        source: win.model.preview(choice.modelData.theme, choice.modelData.mode)
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }
                                Text {
                                    id: label
                                    y: preview.height + 8
                                    width: parent.width
                                    text: choice.modelData.label + "\n" + choice.modelData.appearance
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    color: choice.selected ? PlatinumTokens.highlightText : PlatinumTokens.menuText
                                    font.family: PlatinumTokens.platinumFont
                                    font.pixelSize: PlatinumTokens.platinumSmall
                                    Rectangle { anchors.fill: parent; color: PlatinumTokens.highlight; z: -1; visible: choice.selected }
                                }
                                MouseArea { anchors.fill: parent; onClicked: { choice.forceActiveFocus(); choice.apply(); } }
                            }
                        }
                    }
                    Text {
                        id: errorLabel
                        y: grid.implicitHeight + win.plan.gap
                        width: choices.width
                        visible: win.model.error !== "" || win.model.choices.length === 0
                        text: win.model.error || "No desktop themes are installed."
                        wrapMode: Text.Wrap
                        color: PlatinumTokens.menuDanger
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumSmall
                    }
                }
                PlatinumScrollBar { id: scroll; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; flickable: choices }
            }

            PlatinumMenuCheckRow {
                visible: !!ThemeCatalog.find(win.model.currentTheme) && ThemeCatalog.find(win.model.currentTheme).options.extraDark
                text: "Extra dark"
                checked: win.model.extraDark
                enabled: win.model.currentMode === "dark" && !win.model.applying
                onToggled: function (checked) { win.model.apply(win.model.currentTheme, win.model.currentMode, checked); }
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: PlatinumTokens.menuTextLeft
                Layout.rightMargin: PlatinumTokens.menuRightInset
                visible: win.plan.showNote
                text: "Click a theme to use it. Changes apply at once."
                wrapMode: Text.Wrap
                color: PlatinumTokens.menuTextSecondary
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
            }
        }
    }
    component TitleStripes: Item {
        Layout.preferredHeight: 14
        Column {
            anchors.fill: parent
            spacing: 1
            Repeater {
                model: 5
                Rectangle {
                    width: parent.width
                    height: 1
                    color: PlatinumTokens.bevelLight
                    Rectangle { y: 1; width: parent.width; height: 1; color: PlatinumTokens.bevelDark }
                }
            }
        }
    }
    Shortcut {
        sequence: "E"
        context: Qt.WindowShortcut
        enabled: win.model.currentMode === "dark" && !!ThemeCatalog.find(win.model.currentTheme)
            && ThemeCatalog.find(win.model.currentTheme).options.extraDark
        onActivated: win.model.apply(win.model.currentTheme, win.model.currentMode, !win.model.extraDark)
    }
    Shortcut { sequence: "Escape"; context: Qt.WindowShortcut; onActivated: win.model.close() }
}
