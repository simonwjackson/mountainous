import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

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
}
