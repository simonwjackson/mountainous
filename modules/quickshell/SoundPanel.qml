import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// Sound: the bar control's state and its menu, reached from the bar or
// with SUPER+O then S. This Scope owns the state; MenuHost shows the menu.
//
// Written against Quickshell 0.3.1's quickshell-service-pipewire.qmltypes:
//   Pipewire     singleton, nodes UntypedObjectModel, defaultAudioSink
//                and defaultAudioSource readonly PwNode,
//                preferredDefaultAudioSink and preferredDefaultAudioSource
//                writable PwNode, ready bool
//   PwNode       id, name, description, nickname, isSink, isStream,
//                properties, audio PwNodeAudio, ready
//   PwNodeAudio  muted bool rw, volume float rw (average, 0.0 to 1.0),
//                channels, volumes
//
// PipeWire does not send a node's data until something binds the node, and
// PwNode.audio carries no change notification. A PwObjectTracker therefore
// holds every candidate node, and it lives in the Scope rather than in the
// menu, so the top bar's volume readout keeps working while the menu is
// closed.
Scope {
    id: root

    property bool shown: false
    property bool pipewireReady: Pipewire.ready

    // "outputs" or "inputs". Tab moves between them; both are always
    // reachable, so no device is ever hidden by the panel's size.
    property string section: "outputs"

    property var defaultSink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    property var defaultSource: Pipewire.ready ? Pipewire.defaultAudioSource : null

    // isSink, isStream and audio are constant on a PwNode, so they are safe
    // to filter on before the node is bound. description and nickname are
    // not, which is why the sort reads them only after the tracker holds
    // the node.
    readonly property var audioNodes: {
        if (!Pipewire.nodes) return [];
        return [...Pipewire.nodes.values].filter(function (node) {
            return node.audio && !node.isStream;
        });
    }
    property var outputs: root.sorted(root.audioNodes.filter(function (node) {
        return node.isSink;
    }))
    property var inputs: root.sorted(root.audioNodes.filter(function (node) {
        return !node.isSink;
    }))
    readonly property var currentNodes: root.section === "outputs" ? root.outputs : root.inputs

    // What the top bar reads. The default sink is the one the hardware keys
    // in hyprland.lua drive through wpctl, so the bar and the keys agree.
    readonly property bool available: root.pipewireReady && root.defaultSink !== null
    readonly property bool muted: root.defaultSink && root.defaultSink.audio
        ? root.defaultSink.audio.muted : false
    readonly property int volumePercent: root.defaultSink && root.defaultSink.audio
        ? Math.round(root.defaultSink.audio.volume * 100) : 0

    function sorted(nodes) {
        const list = [...nodes];
        list.sort(function (a, b) {
            return root.nodeLabel(a).localeCompare(root.nodeLabel(b));
        });
        return list;
    }

    function nodeLabel(node) {
        if (!node) return "";
        return node.description || node.nickname || node.name || "Unnamed device";
    }

    function isDefault(node) {
        return node === (root.section === "outputs" ? root.defaultSink : root.defaultSource);
    }

    // wpctl caps a raise at 1.0 in hyprland.lua. Match it, so the key and
    // the panel cannot disagree about the top of the scale.
    function adjustVolume(node, delta) {
        if (!node || !node.audio) return;
        node.audio.volume = Math.min(1.0, Math.max(0.0, node.audio.volume + delta));
    }

    function toggleMute(node) {
        if (!node || !node.audio) return;
        node.audio.muted = !node.audio.muted;
    }

    function makeDefault(node) {
        if (!node) return;
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node;
        else Pipewire.preferredDefaultAudioSource = node;
    }

    onShownChanged: {
        if (root.shown) root.section = "outputs";
    }

    PwObjectTracker {
        objects: root.audioNodes
    }

    property Component menu: Component {
        MenuFrame {
            id: frame

            preferredWidth: 380
            title: "Sound"
            // The volume number the bar gives up lives on the slider row.
            detail: frame.selected ? root.nodeLabel(frame.selected) : "No device selected"
            scrolls: devices.scrolls

            // Read the selection out of the model, never out of
            // ListView.currentItem: a delegate outside the cache is not
            // built, so currentItem goes null in a long list.
            readonly property var selected: {
                const index = devices.currentIndex;
                if (index < 0 || index >= root.currentNodes.length) return null;
                return root.currentNodes[index];
            }
            readonly property bool selectedMuted: frame.selected !== null && frame.selected.audio
                ? frame.selected.audio.muted : false
            readonly property real levelWidth: PlatinumMetrics.smallWidest(["100%", "mute"])

            function switchSection() {
                root.section = root.section === "outputs" ? "inputs" : "outputs";
                frame.selectDefault();
            }

            // Land on the device the session is using, so Left and Right
            // change the volume that matters with no further keys.
            function selectDefault() {
                const index = root.currentNodes.findIndex(function (node) { return root.isDefault(node); });
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

            MenuCheckRow {
                text: "Mute"
                rightInset: frame.rightInset
                checked: frame.selectedMuted
                enabled: frame.selected !== null
                onToggled: root.toggleMute(frame.selected)
            }

            MenuParts.Separator {}

            PlatinumTabs {
                rightInset: frame.rightInset
                current: root.section
                model: [
                    { key: "outputs", label: "OUTPUTS " + root.outputs.length },
                    { key: "inputs", label: "INPUTS " + root.inputs.length }
                ]
                onSelected: function (key) {
                    root.section = key;
                    frame.selectDefault();
                }
            }

            MenuParts.Empty {
                visible: root.currentNodes.length === 0
                rightInset: frame.rightInset
                text: {
                    if (!root.pipewireReady) return "PipeWire is not running.";
                    return root.section === "outputs"
                        ? "No output devices are available."
                        : "No input devices are available.";
                }
            }

            MenuList {
                id: devices
                visible: root.currentNodes.length > 0
                model: ScriptModel { values: root.currentNodes }

                Component.onCompleted: {
                    view.forceActiveFocus();
                    frame.selectDefault();
                }
                onCountChanged: {
                    if (count > 0 && currentIndex < 0) frame.selectDefault();
                    if (count === 0) currentIndex = -1;
                }

                delegate: MenuListRow {
                    id: deviceRow

                    required property var modelData
                    required property int index

                    readonly property real level: modelData.audio ? modelData.audio.volume : 0
                    readonly property bool rowMuted: modelData.audio ? modelData.audio.muted : false

                    width: ListView.view.width
                    rightInset: frame.rightInset
                    rowHeight: Theme.menuRow
                    selected: ListView.isCurrentItem
                    mark: root.isDefault(modelData) ? "dot" : "ring"
                    markDim: !root.isDefault(modelData)
                    name: root.nodeLabel(modelData)
                    onEntered: devices.currentIndex = index
                    onDoubleClicked: root.makeDefault(modelData)

                    below: Rectangle {
                        width: parent.width
                        height: 4
                        color: deviceRow.selected ? Qt.darker(Theme.highlight, 1.4) : Theme.well
                        Rectangle {
                            width: Math.round(parent.width * Math.min(1, Math.max(0, deviceRow.level)))
                            height: parent.height
                            color: deviceRow.selected ? Theme.highlightText
                                : deviceRow.rowMuted ? Theme.menuTextOff : Theme.highlight
                        }
                    }

                    Text {
                        width: frame.levelWidth
                        horizontalAlignment: Text.AlignRight
                        text: deviceRow.rowMuted ? "mute" : Math.round(deviceRow.level * 100) + "%"
                        color: deviceRow.fg2
                        font.family: Theme.platinumFont
                        font.pixelSize: Theme.platinumSmall
                        font.letterSpacing: Theme.platinumTracking
                    }
                }
            }

            MenuParts.Hint {
                rightInset: frame.rightInset
                text: "↑↓ select · ←→ volume · Enter default · M mute · Tab "
                    + (root.section === "outputs" ? "inputs" : "outputs")
            }

            // Window scope, not item scope: an item-scoped handler stops
            // working once focus moves to the slider or a tab, the bug
            // commit 5119faf6 fixed in the Bluetooth panel.
            Shortcut { sequence: "Up"; context: Qt.WindowShortcut; onActivated: devices.moveSelection(-1) }
            Shortcut { sequence: "Down"; context: Qt.WindowShortcut; onActivated: devices.moveSelection(1) }
            Shortcut { sequence: "Left"; context: Qt.WindowShortcut; onActivated: root.adjustVolume(frame.selected, -0.05) }
            Shortcut { sequence: "Right"; context: Qt.WindowShortcut; onActivated: root.adjustVolume(frame.selected, 0.05) }
            Shortcut { sequence: "Return"; context: Qt.WindowShortcut; onActivated: root.makeDefault(frame.selected) }
            Shortcut { sequence: "Enter"; context: Qt.WindowShortcut; onActivated: root.makeDefault(frame.selected) }
            Shortcut { sequence: "Space"; context: Qt.WindowShortcut; onActivated: root.makeDefault(frame.selected) }
            Shortcut { sequence: "M"; context: Qt.WindowShortcut; onActivated: root.toggleMute(frame.selected) }
            Shortcut { sequence: "Tab"; context: Qt.WindowShortcut; onActivated: frame.switchSection() }
            Shortcut { sequence: "Backtab"; context: Qt.WindowShortcut; onActivated: frame.switchSection() }
        }
    }
}
