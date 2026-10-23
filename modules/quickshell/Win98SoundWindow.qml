pragma ComponentBehavior: Bound

import QtQuick

// Sound, read as the Win98 tray volume popup beside a property sheet: a
// vertical trackbar with a Mute check box for the selected device, then
// Outputs and Inputs tabs over the device list. The shared SoundPanel owns
// every value; this view keeps only which row is selected.
//
// Keys: Up/Down select, Left/Right change the volume (wpctl's 0 to 100),
// Enter or Space make the selection the default, M mutes, Tab switches
// between outputs and inputs.
Win98Window {
    id: root

    required property var panel

    title: "Sound"
    iconName: "volume-1"
    margins: false
    onCloseClicked: MenuState.close()

    // A short screen: the device list and the trackbar give up height
    // first (50 u, keeping two rows), then the key hint goes; the body
    // scrolls only after that.
    // Measured after layout settles, not bound: the list's height feeds
    // the window's own height, so a binding would loop. The sum is a fixed
    // point (what the list gives up, it adds back).
    property real natural: 0
    function measureNatural() { root.natural = implicitHeight + shrink + (statusArea.visible ? 0 : status.height + 8 * u); }
    Connections {
        target: root
        function onImplicitHeightChanged() { Qt.callLater(root.measureNatural); }
    }
    Component.onCompleted: { selectDefault(); Qt.callLater(root.measureNatural); }
    readonly property real squeeze: availableHeight > 0 ? Math.max(0, natural - availableHeight) : 0
    readonly property real shrink: Math.min(50 * u, Math.ceil(squeeze / u - 1e-6) * u)
    readonly property bool dropStatus: squeeze > 50 * u + 0.5

    readonly property var nodes: panel.currentNodes
    property int cursor: -1
    readonly property var selected: cursor >= 0 && cursor < nodes.length ? nodes[cursor] : null
    readonly property bool hasAudio: !!(selected && selected.audio)
    readonly property real volume: hasAudio ? selected.audio.volume : 0
    readonly property bool muted: hasAudio && selected.audio.muted

    function selectDefault() {
        const i = root.nodes.findIndex(function (n) { return root.panel.isDefault(n); });
        root.cursor = root.nodes.length ? Math.max(0, i) : -1;
        list.currentIndex = root.cursor;
    }
    function move(d) {
        if (!root.nodes.length) return;
        root.cursor = Math.max(0, Math.min(root.nodes.length - 1, root.cursor + d));
        list.currentIndex = root.cursor;
        list.reveal(root.cursor);
    }
    function switchSection() {
        root.panel.section = root.panel.section === "outputs" ? "inputs" : "outputs";
        root.selectDefault();
    }
    onNodesChanged: if (cursor < 0 || cursor >= nodes.length) selectDefault()


    Item {
        x: 8 * root.u; y: 6 * root.u
        width: root.bodyWidth - 16 * root.u
        implicitHeight: body.height + 10 * root.u

        Column {
            id: body
            width: parent.width
            spacing: 6 * root.u

            Row {
                spacing: 8 * root.u
                height: 161 * root.u - root.shrink

                Win98GroupBox {
                    y: -root.u
                    width: 86 * root.u
                    height: 162 * root.u - root.shrink
                    title: "Volume"
                    topUnits: 12
                    Column {
                        width: 72 * root.u
                        spacing: 5 * root.u
                        Win98Slider {
                            x: 21 * root.u
                            orientation: Qt.Vertical
                            height: 100 * root.u - root.shrink
                            enabled: root.hasAudio
                            value: root.volume
                            onMoved: function (v) { if (root.hasAudio) root.selected.audio.volume = v; }
                        }
                        Item {
                            width: 72 * root.u
                            height: 13 * root.u
                            Win98Text {
                                x: Win98Tokens.half((72 * root.u - width) / 2, root.u)
                                text: !root.hasAudio || root.muted ? "--" : Math.round(root.volume * 100) + "%"
                                accessMarks: false
                            }
                        }
                        Win98CheckBox {
                            x: Win98Tokens.half((72 * root.u - width) / 2, root.u)
                            text: "&Mute"
                            enabled: root.hasAudio
                            checked: root.muted
                            onToggled: root.panel.toggleMute(root.selected)
                        }
                    }
                }

                Column {
                    id: rightCol
                    width: body.width - 94 * root.u
                    spacing: 3 * root.u
                    Item {
                        width: parent.width
                        height: 13 * root.u
                        Win98Text {
                            width: Math.min(implicitWidth, parent.width)
                            text: root.selected ? root.panel.nodeLabel(root.selected) : "No device selected"
                            accessMarks: false
                            bold: true
                        }
                    }
                    Win98Tabs {
                        width: parent.width
                        height: 145 * root.u - root.shrink
                        tabs: ["&Outputs " + root.panel.outputs.length, "&Inputs " + root.panel.inputs.length]
                        currentIndex: root.panel.section === "outputs" ? 0 : 1
                        padUnits: 6
                        onSelected: function (i) { if (i !== currentIndex) root.switchSection(); }
                        Win98ListView {
                            id: list
                            width: rightCol.width - 12 * root.u
                            height: 108 * root.u - root.shrink
                            model: root.nodes
                            showFocus: true
                            emptyText: !root.panel.pipewireReady ? "PipeWire is not running."
                                : root.panel.section === "outputs" ? "No output devices are available."
                                : "No input devices are available."
                            onCurrentIndexChanged: if (currentIndex !== root.cursor && currentIndex >= 0) root.cursor = currentIndex
                            onActivated: function (i) { root.panel.makeDefault(root.nodes[i]); }
                            delegate: Win98ListRow {
                                required property var modelData
                                readonly property bool isDefault: root.panel.isDefault(modelData)
                                title: root.panel.nodeLabel(modelData)
                                bold: isDefault
                                mark: isDefault ? "dot" : "ring"
                                level: modelData.audio ? modelData.audio.volume : 0
                                muted: !!(modelData.audio && modelData.audio.muted)
                                value: !modelData.audio ? "" : modelData.audio.muted ? "mute" : Math.round(modelData.audio.volume * 100) + "%"
                            }
                        }
                    }
                }
            }

            Item {
                id: statusArea
                visible: !root.dropStatus
                width: parent.width
                height: status.height + 2 * root.u
                Win98StatusBar {
                    id: status
                    y: 2 * root.u
                    width: parent.width
                    panes: ["\u2191\u2193 select \u00b7 \u2190\u2192 volume \u00b7 Enter default \u00b7 M mute \u00b7 Tab "
                        + (root.panel.section === "outputs" ? "inputs" : "outputs")]
                }
            }
        }
    }

    Shortcut { sequence: "Up"; context: Qt.WindowShortcut; onActivated: root.move(-1) }
    Shortcut { sequence: "Down"; context: Qt.WindowShortcut; onActivated: root.move(1) }
    Shortcut { sequence: "Left"; context: Qt.WindowShortcut; onActivated: root.panel.adjustVolume(root.selected, -0.05) }
    Shortcut { sequence: "Right"; context: Qt.WindowShortcut; onActivated: root.panel.adjustVolume(root.selected, 0.05) }
    Shortcut { sequences: ["Return", "Enter", "Space"]; context: Qt.WindowShortcut; onActivated: root.panel.makeDefault(root.selected) }
    Shortcut { sequence: "M"; context: Qt.WindowShortcut; onActivated: root.panel.toggleMute(root.selected) }
    Shortcut { sequences: ["Tab", "Backtab"]; context: Qt.WindowShortcut; onActivated: root.switchSection() }
}
