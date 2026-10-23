import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts


PlatinumMenuFrame {
    id: frame
    required property var panel

    preferredWidth: 380
    title: "Sound"
    // The volume number the bar gives up lives on the slider row.
    detail: frame.selected ? panel.nodeLabel(frame.selected) : "No device selected"
    scrolls: devices.scrolls

    // Read the selection out of the model, never out of
    // ListView.currentItem: a delegate outside the cache is not
    // built, so currentItem goes null in a long list.
    readonly property var selected: {
        const index = devices.currentIndex;
        if (index < 0 || index >= panel.currentNodes.length) return null;
        return panel.currentNodes[index];
    }
    readonly property bool selectedMuted: frame.selected !== null && frame.selected.audio
        ? frame.selected.audio.muted : false
    readonly property real levelWidth: PlatinumMetrics.smallWidest(["100%", "mute"])

    function switchSection() {
        panel.section = panel.section === "outputs" ? "inputs" : "outputs";
        frame.selectDefault();
    }

    // Land on the device the session is using, so Left and Right
    // change the volume that matters with no further keys.
    function selectDefault() {
        const index = panel.currentNodes.findIndex(function (node) { return panel.isDefault(node); });
        devices.currentIndex = index >= 0 ? index : (devices.count > 0 ? 0 : -1);
        if (devices.currentIndex >= 0) devices.view.positionViewAtIndex(devices.currentIndex, ListView.Contain);
    }

    PlatinumSlider {
        rightInset: frame.rightInset
        icon: "speaker"
        hasValue: frame.selected !== null
        enabled: frame.selected !== null
        dimmed: frame.selectedMuted || frame.selected === null
        ratio: frame.selected && frame.selected.audio ? frame.selected.audio.volume : 0
        valueText: !frame.selected || !frame.selected.audio || frame.selected.audio.muted ? "--"
            : Math.round(frame.selected.audio.volume * 100) + "%"
        onMoved: function (ratio) {
            if (frame.selected && frame.selected.audio) frame.selected.audio.volume = ratio;
        }
    }

    PlatinumMenuCheckRow {
        text: "Mute"
        rightInset: frame.rightInset
        checked: frame.selectedMuted
        enabled: frame.selected !== null
        onToggled: panel.toggleMute(frame.selected)
    }

    PlatinumMenuParts.Separator {}

    PlatinumTabs {
        rightInset: frame.rightInset
        current: panel.section
        model: [
            { key: "outputs", label: "OUTPUTS " + panel.outputs.length },
            { key: "inputs", label: "INPUTS " + panel.inputs.length }
        ]
        onSelected: function (key) {
            panel.section = key;
            frame.selectDefault();
        }
    }

    PlatinumMenuParts.Empty {
        visible: panel.currentNodes.length === 0
        rightInset: frame.rightInset
        text: {
            if (!panel.pipewireReady) return "PipeWire is not running.";
            return panel.section === "outputs"
                ? "No output devices are available."
                : "No input devices are available.";
        }
    }

    PlatinumMenuList {
        id: devices
        visible: panel.currentNodes.length > 0
        model: ScriptModel { values: panel.currentNodes }

        Component.onCompleted: {
            view.forceActiveFocus();
            frame.selectDefault();
        }
        onCountChanged: {
            if (count > 0 && currentIndex < 0) frame.selectDefault();
            if (count === 0) currentIndex = -1;
        }

        delegate: PlatinumMenuListRow {
            id: deviceRow

            required property var modelData
            required property int index

            readonly property real level: modelData.audio ? modelData.audio.volume : 0
            readonly property bool rowMuted: modelData.audio ? modelData.audio.muted : false

            width: ListView.view.width
            rightInset: frame.rightInset
            rowHeight: PlatinumTokens.menuRow
            selected: ListView.isCurrentItem
            mark: panel.isDefault(modelData) ? "dot" : "ring"
            markDim: !panel.isDefault(modelData)
            name: panel.nodeLabel(modelData)
            onEntered: devices.currentIndex = index
            onDoubleClicked: panel.makeDefault(modelData)

            below: Rectangle {
                width: parent.width
                height: 4
                color: deviceRow.selected ? Qt.darker(PlatinumTokens.highlight, 1.4) : PlatinumTokens.well
                Rectangle {
                    width: Math.round(parent.width * Math.min(1, Math.max(0, deviceRow.level)))
                    height: parent.height
                    color: deviceRow.selected ? PlatinumTokens.highlightText
                        : deviceRow.rowMuted ? PlatinumTokens.menuTextOff : PlatinumTokens.highlight
                }
            }

            Text {
                width: frame.levelWidth
                horizontalAlignment: Text.AlignRight
                text: deviceRow.rowMuted ? "mute" : Math.round(deviceRow.level * 100) + "%"
                color: deviceRow.fg2
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
        }
    }

    PlatinumMenuParts.Hint {
        rightInset: frame.rightInset
        text: "↑↓ select · ←→ volume · Enter default · M mute · Tab "
            + (panel.section === "outputs" ? "inputs" : "outputs")
    }

    // Window scope, not item scope: an item-scoped handler stops
    // working once focus moves to the slider or a tab, the bug
    // commit 5119faf6 fixed in the Bluetooth panel.
    Shortcut { sequence: "Up"; context: Qt.WindowShortcut; onActivated: devices.moveSelection(-1) }
    Shortcut { sequence: "Down"; context: Qt.WindowShortcut; onActivated: devices.moveSelection(1) }
    Shortcut { sequence: "Left"; context: Qt.WindowShortcut; onActivated: panel.adjustVolume(frame.selected, -0.05) }
    Shortcut { sequence: "Right"; context: Qt.WindowShortcut; onActivated: panel.adjustVolume(frame.selected, 0.05) }
    Shortcut { sequence: "Return"; context: Qt.WindowShortcut; onActivated: panel.makeDefault(frame.selected) }
    Shortcut { sequence: "Enter"; context: Qt.WindowShortcut; onActivated: panel.makeDefault(frame.selected) }
    Shortcut { sequence: "Space"; context: Qt.WindowShortcut; onActivated: panel.makeDefault(frame.selected) }
    Shortcut { sequence: "M"; context: Qt.WindowShortcut; onActivated: panel.toggleMute(frame.selected) }
    Shortcut { sequence: "Tab"; context: Qt.WindowShortcut; onActivated: frame.switchSection() }
    Shortcut { sequence: "Backtab"; context: Qt.WindowShortcut; onActivated: frame.switchSection() }
}