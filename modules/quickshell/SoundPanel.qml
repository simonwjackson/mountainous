import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// The sound panel, reached from the top bar's mnemonic namespace with
// SUPER+O then S. Built to the same shape as BluetoothPanel: a Scope that
// owns the state, a LazyLoader that only builds the window while it is
// shown, a full-screen transparent veil with a Hyprland focus grab, and one
// card anchored under the bar.
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
// holds every candidate node, and it lives in the Scope rather than inside
// the LazyLoader so the top bar's volume readout keeps working while the
// panel is closed.
Scope {
    id: root

    required property var screen
    property bool shown: false
    signal closeRequested

    // "outputs" or "inputs". Tab moves between them; both are always
    // reachable, so no device is ever hidden by the panel's size.
    property string section: "outputs"

    readonly property var defaultSink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property var defaultSource: Pipewire.ready ? Pipewire.defaultAudioSource : null

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
    readonly property var outputs: root.sorted(root.audioNodes.filter(function (node) {
        return node.isSink;
    }))
    readonly property var inputs: root.sorted(root.audioNodes.filter(function (node) {
        return !node.isSink;
    }))
    readonly property var currentNodes: root.section === "outputs" ? root.outputs : root.inputs

    // What the top bar reads. The default sink is the one the hardware keys
    // in hyprland.lua drive through wpctl, so the bar and the keys agree.
    readonly property bool available: Pipewire.ready && root.defaultSink !== null
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

    // Layout is a pure function of the space the veil actually has. Height
    // decides structure, width decides content. Nothing on the capability
    // ladder is ever dropped: the volume row and the section tabs are
    // controls and always render, while the hint line and the per-row detail
    // are readouts and yield first.
    function layoutPlan(width, height) {
        const cardWidth = Math.min(360, Math.max(0, width - 12));
        const cardHeight = Math.min(520, Math.max(190, height - 44));
        const showVolumeLabel = cardHeight >= 300 && cardWidth >= 260;
        return {
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            rowHeight: cardHeight < 320 ? 48 : 56,
            showDetail: cardWidth >= 300,
            showHint: cardHeight >= 250,
            showVolumeLabel: showVolumeLabel,
            volumeHeight: showVolumeLabel ? 46 : 34,
            showTabs: true,
            showVolume: true
        };
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

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: veil

            screen: root.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            color: "transparent"

            HyprlandFocusGrab {
                active: root.shown
                windows: [ veil ]
                onCleared: root.closeRequested()
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeRequested()
            }

            Rectangle {
                id: card

                readonly property var plan: root.layoutPlan(veil.width, veil.height)

                // Read the selection out of the model, never out of
                // ListView.currentItem. A delegate outside the view's cache
                // is not instantiated, so currentItem goes null as soon as
                // the list is long enough to scroll, and the volume row
                // would empty itself while a device was plainly selected.
                readonly property var selected: {
                    const index = deviceList.currentIndex;
                    if (index < 0 || index >= root.currentNodes.length) return null;
                    return root.currentNodes[index];
                }

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 32
                anchors.rightMargin: 6
                width: plan.cardWidth
                height: plan.cardHeight
                radius: Theme.radiusLarge
                color: Theme.bgPanel
                border.width: 1
                border.color: Theme.borderMuted

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: "Sound"
                            color: Theme.textPrimary
                            font.pixelSize: 14
                            font.family: Theme.fontFamily
                            font.bold: true
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: Theme.radiusSmall
                            color: closeArea.containsMouse ? Theme.bgSelected : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: Theme.textSecondary
                                font.pixelSize: 16
                                font.family: Theme.fontFamily
                            }

                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.closeRequested()
                            }
                        }
                    }

                    // The volume of whichever device is selected. Opening the
                    // panel selects the default device, so the common path is
                    // SUPER+O, S, then Left or Right.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: card.plan.volumeHeight
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            visible: card.plan.showVolumeLabel
                            text: card.selected
                                ? root.nodeLabel(card.selected)
                                : "No device selected"
                            elide: Text.ElideRight
                            color: Theme.textDetail
                            font.pixelSize: 10
                            font.family: Theme.fontFamily
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            Text {
                                Layout.preferredWidth: 38
                                horizontalAlignment: Text.AlignRight
                                text: {
                                    if (!card.selected || !card.selected.audio) return "--";
                                    if (card.selected.audio.muted) return "--";
                                    return Math.round(card.selected.audio.volume * 100) + "%";
                                }
                                color: card.selected && card.selected.audio
                                    && !card.selected.audio.muted
                                    ? Theme.textPrimary : Theme.textOff
                                font.pixelSize: 12
                                font.family: Theme.fontFamily
                            }

                            // A drag across the full track means the full
                            // range, whatever width the track is given.
                            Rectangle {
                                id: volumeTrack

                                Layout.fillWidth: true
                                Layout.preferredHeight: 6
                                radius: 3
                                color: Theme.bgSeparator

                                readonly property real level: card.selected && card.selected.audio
                                    ? card.selected.audio.volume : 0

                                Rectangle {
                                    width: Math.round(parent.width * Math.min(1, Math.max(0, volumeTrack.level)))
                                    height: parent.height
                                    radius: parent.radius
                                    color: card.selected && card.selected.audio
                                        && card.selected.audio.muted
                                        ? Theme.textOff : Theme.accent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.topMargin: -12
                                    anchors.bottomMargin: -12
                                    enabled: card.selected !== null

                                    function setFromX(x) {
                                        if (!card.selected || !card.selected.audio) return;
                                        const ratio = Math.min(1, Math.max(0, x / volumeTrack.width));
                                        card.selected.audio.volume = ratio;
                                    }

                                    onPressed: function (mouse) { setFromX(mouse.x); }
                                    onPositionChanged: function (mouse) {
                                        if (pressed) setFromX(mouse.x);
                                    }
                                }
                            }

                            TogglePill {
                                checked: !(card.selected && card.selected.audio
                                    && card.selected.audio.muted)
                                enabled: card.selected !== null
                                onToggled: root.toggleMute(card.selected)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.bgSeparator
                    }

                    // Both device kinds stay one key apart. Tab is the
                    // keyboard route; the two labels are the pointer route.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        spacing: 6

                        Repeater {
                            model: [
                                { key: "outputs", label: "OUTPUTS" },
                                { key: "inputs", label: "INPUTS" }
                            ]

                            Rectangle {
                                required property var modelData

                                readonly property bool active: root.section === modelData.key
                                readonly property int deviceCount: modelData.key === "outputs"
                                    ? root.outputs.length : root.inputs.length

                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                radius: Theme.radiusSmall
                                color: active
                                    ? Theme.bgActive
                                    : tabArea.containsMouse ? Theme.bgSelected : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.label + " " + parent.deviceCount
                                    color: parent.active ? Theme.accent : Theme.textDim
                                    font.pixelSize: 10
                                    font.family: Theme.fontFamily
                                }

                                MouseArea {
                                    id: tabArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        root.section = parent.modelData.key;
                                        deviceList.selectDefault();
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        id: deviceList

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        focus: true
                        keyNavigationWraps: true
                        highlightMoveDuration: 80
                        model: ScriptModel { values: root.currentNodes }

                        Component.onCompleted: forceActiveFocus()
                        onCountChanged: {
                            if (count > 0 && currentIndex < 0) selectDefault();
                            if (count === 0) currentIndex = -1;
                        }

                        // Land on the device the session is actually using, so
                        // Left and Right change the volume that matters
                        // without any further keys.
                        function selectDefault() {
                            const index = root.currentNodes.findIndex(function (node) {
                                return root.isDefault(node);
                            });
                            currentIndex = index >= 0 ? index : (count > 0 ? 0 : -1);
                            if (currentIndex >= 0)
                                positionViewAtIndex(currentIndex, ListView.Contain);
                        }

                        function moveSelection(offset) {
                            if (count === 0) return;
                            currentIndex = (currentIndex + offset + count) % count;
                            positionViewAtIndex(currentIndex, ListView.Contain);
                        }

                        delegate: Rectangle {
                            id: deviceRow

                            required property var modelData
                            required property int index

                            readonly property bool isDefaultDevice: root.isDefault(modelData)
                            readonly property real level: modelData.audio ? modelData.audio.volume : 0
                            readonly property bool rowMuted: modelData.audio
                                ? modelData.audio.muted : false

                            width: deviceList.width
                            height: card.plan.rowHeight
                            radius: Theme.radiusSmall
                            color: deviceRow.ListView.isCurrentItem
                                ? Theme.bgActive
                                : rowArea.containsMouse ? Theme.bgSelected : "transparent"

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    deviceList.currentIndex = deviceRow.index;
                                    deviceList.forceActiveFocus();
                                }
                                onDoubleClicked: root.makeDefault(deviceRow.modelData)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Text {
                                    Layout.preferredWidth: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    text: deviceRow.isDefaultDevice ? "●" : "○"
                                    color: deviceRow.isDefaultDevice ? Theme.accent : Theme.textDim
                                    font.pixelSize: 11
                                    font.family: Theme.fontFamily
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.nodeLabel(deviceRow.modelData)
                                        elide: Text.ElideRight
                                        color: Theme.textPrimary
                                        font.pixelSize: 12
                                        font.family: Theme.fontFamily
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 3
                                        radius: 1
                                        color: Theme.bgSeparator

                                        Rectangle {
                                            width: Math.round(parent.width
                                                * Math.min(1, Math.max(0, deviceRow.level)))
                                            height: parent.height
                                            radius: parent.radius
                                            color: deviceRow.rowMuted ? Theme.textOff : Theme.accent
                                        }
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 34
                                    horizontalAlignment: Text.AlignRight
                                    visible: card.plan.showDetail
                                    text: deviceRow.rowMuted
                                        ? "mute"
                                        : Math.round(deviceRow.level * 100) + "%"
                                    color: deviceRow.rowMuted ? Theme.textOff : Theme.textDetail
                                    font.pixelSize: 10
                                    font.family: Theme.fontFamily
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            width: Math.max(0, parent.width - 24)
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            visible: root.currentNodes.length === 0
                            text: {
                                if (!Pipewire.ready) return "PipeWire is not running.";
                                return root.section === "outputs"
                                    ? "No output devices are available."
                                    : "No input devices are available.";
                            }
                            color: Theme.textMuted
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        visible: card.plan.showHint
                        text: "↑↓ select · ←→ volume · Enter default · M mute · Tab "
                            + (root.section === "outputs" ? "inputs" : "outputs")
                        elide: Text.ElideRight
                        color: Theme.textDetail
                        font.pixelSize: 9
                        font.family: Theme.fontFamily
                    }
                }
            }

            // Window scope, not item scope. An item-scoped key handler stops
            // working the moment focus moves to the slider or a tab, which is
            // the bug commit 5119faf6 fixed in the Bluetooth panel.
            Shortcut {
                sequence: "Up"
                context: Qt.WindowShortcut
                onActivated: deviceList.moveSelection(-1)
            }

            Shortcut {
                sequence: "Down"
                context: Qt.WindowShortcut
                onActivated: deviceList.moveSelection(1)
            }

            Shortcut {
                sequence: "Left"
                context: Qt.WindowShortcut
                onActivated: root.adjustVolume(card.selected, -0.05)
            }

            Shortcut {
                sequence: "Right"
                context: Qt.WindowShortcut
                onActivated: root.adjustVolume(card.selected, 0.05)
            }

            Shortcut {
                sequence: "Return"
                context: Qt.WindowShortcut
                onActivated: root.makeDefault(card.selected)
            }

            Shortcut {
                sequence: "Enter"
                context: Qt.WindowShortcut
                onActivated: root.makeDefault(card.selected)
            }

            Shortcut {
                sequence: "Space"
                context: Qt.WindowShortcut
                onActivated: root.makeDefault(card.selected)
            }

            Shortcut {
                sequence: "M"
                context: Qt.WindowShortcut
                onActivated: root.toggleMute(card.selected)
            }

            Shortcut {
                sequence: "Tab"
                context: Qt.WindowShortcut
                onActivated: {
                    root.section = root.section === "outputs" ? "inputs" : "outputs";
                    deviceList.selectDefault();
                }
            }

            Shortcut {
                sequence: "Backtab"
                context: Qt.WindowShortcut
                onActivated: {
                    root.section = root.section === "outputs" ? "inputs" : "outputs";
                    deviceList.selectDefault();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                onActivated: root.closeRequested()
            }
        }
    }
}
