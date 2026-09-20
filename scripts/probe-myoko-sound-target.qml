// Runs on Myoko under the real Quickshell. Prints what SoundPanel.qml would
// see, then quits. No windows, so it needs no compositor surface.
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

ShellRoot {
    id: root

    // Same filter the panel uses. If `audio` is not populated before the
    // tracker binds the node, this list is empty and the panel's device
    // lists would be empty too.
    readonly property var audioNodes: {
        if (!Pipewire.nodes) return [];
        return [...Pipewire.nodes.values].filter(function (node) {
            return node.audio && !node.isStream;
        });
    }

    PwObjectTracker {
        objects: root.audioNodes
    }

    function describe(label) {
        console.log("=== " + label + " ===");
        console.log("ready=" + Pipewire.ready
            + " totalNodes=" + (Pipewire.nodes ? Pipewire.nodes.values.length : -1)
            + " audioNodes=" + root.audioNodes.length);

        const sink = Pipewire.defaultAudioSink;
        const source = Pipewire.defaultAudioSource;
        console.log("defaultSink=" + (sink ? sink.name : "null")
            + " audio=" + (sink && sink.audio ? "yes" : "no")
            + " volume=" + (sink && sink.audio ? sink.audio.volume : "n/a")
            + " muted=" + (sink && sink.audio ? sink.audio.muted : "n/a"));
        console.log("defaultSource=" + (source ? source.name : "null"));

        if (!Pipewire.nodes) return;
        for (const node of Pipewire.nodes.values) {
            console.log("NODE"
                + " id=" + node.id
                + " isSink=" + node.isSink
                + " isStream=" + node.isStream
                + " hasAudio=" + (node.audio !== null)
                + " vol=" + (node.audio ? Math.round(node.audio.volume * 100) : "-")
                + " name=" + node.name
                + " desc=" + JSON.stringify(node.description));
        }
    }

    // Before any binding has had time to settle.
    Component.onCompleted: root.describe("IMMEDIATE (pre-bind)")

    // After the tracker has bound every node and PipeWire has answered.
    Timer {
        interval: 2500
        running: true
        onTriggered: {
            root.describe("SETTLED (post-bind)");
            Qt.exit(0);
        }
    }
}
