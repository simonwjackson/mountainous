// Runs on Myoko under the real Quickshell. Exercises exactly the PipeWire
// API SoundPanel.qml uses, then quits. No windows, so it needs no surface.
//
// Two jobs. First, report what the panel's device filter would see. Second,
// write volume and mute through PwNodeAudio the way the panel's Left, Right
// and M keys do, so the write path is proved rather than assumed; the caller
// reads the result back with wpctl.
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

ShellRoot {
    id: root

    // Same filter as the panel. isSink, isStream and audio are constant on a
    // PwNode and arrive with the registry, so this works before binding.
    readonly property var audioNodes: {
        if (!Pipewire.nodes) return [];
        return [...Pipewire.nodes.values].filter(function (node) {
            return node.audio && !node.isStream;
        });
    }
    readonly property var outputs: root.audioNodes.filter(function (n) { return n.isSink; })
    readonly property var inputs: root.audioNodes.filter(function (n) { return !n.isSink; })

    PwObjectTracker {
        objects: root.audioNodes
    }

    function report(label) {
        console.log("=== " + label + " ===");
        console.log("ready=" + Pipewire.ready
            + " totalNodes=" + (Pipewire.nodes ? Pipewire.nodes.values.length : -1)
            + " audioNodes=" + root.audioNodes.length
            + " outputs=" + root.outputs.length
            + " inputs=" + root.inputs.length);

        const sink = Pipewire.defaultAudioSink;
        console.log("defaultSink=" + (sink ? sink.name : "null")
            + " audio=" + (sink && sink.audio ? "yes" : "no")
            + " volume=" + (sink && sink.audio ? sink.audio.volume.toFixed(2) : "n/a")
            + " muted=" + (sink && sink.audio ? sink.audio.muted : "n/a"));

        if (!Pipewire.nodes) return;
        for (const node of Pipewire.nodes.values) {
            console.log("NODE id=" + node.id
                + " isSink=" + node.isSink
                + " isStream=" + node.isStream
                + " hasAudio=" + (node.audio !== null)
                + " vol=" + (node.audio ? Math.round(node.audio.volume * 100) : "-")
                + " name=" + node.name
                + " desc=" + JSON.stringify(node.description));
        }
    }

    Component.onCompleted: root.report("IMMEDIATE (pre-bind)")

    Timer {
        interval: 2500
        running: true
        onTriggered: {
            root.report("SETTLED (post-bind)");

            const sink = Pipewire.defaultAudioSink;
            if (!sink || !sink.audio) {
                console.log("WRITE_TEST: no default sink, skipped");
                Qt.exit(0);
                return;
            }

            // Exactly what the panel's Right key does, five times.
            const original = sink.audio.volume;
            console.log("WRITE_TEST: original volume " + original.toFixed(2));
            for (let i = 0; i < 5; i++)
                sink.audio.volume = Math.min(1.0, Math.max(0.0, sink.audio.volume - 0.05));
            console.log("WRITE_TEST: after five 5% steps down "
                + sink.audio.volume.toFixed(2));

            // Exactly what the panel's M key does.
            sink.audio.muted = !sink.audio.muted;
            console.log("WRITE_TEST: muted now " + sink.audio.muted);

            console.log("WRITE_TEST_APPLIED original=" + original.toFixed(2));
            writeSettle.start();
        }
    }

    // Give PipeWire a moment to accept the writes before the process exits,
    // then leave the machine as it was found.
    Timer {
        id: writeSettle
        interval: 1500
        onTriggered: {
            const sink = Pipewire.defaultAudioSink;
            if (sink && sink.audio) {
                console.log("WRITE_TEST: readback volume "
                    + sink.audio.volume.toFixed(2)
                    + " muted " + sink.audio.muted);
            }
            Qt.exit(0);
        }
    }
}
