pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root
    readonly property var sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property var entry: ThemeCatalog.find(Theme.name)
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    ThemeSoundPlayer {
        id: player
        soundSet: root.entry && root.entry.sounds ? root.entry.sounds : ({})
        enabled: Theme.soundsEnabled
        available: !!root.sink && root.sink.ready && !!root.sink.audio
        // Unknown state is silent. This also tears down an in-flight sound.
        muted: !root.sink || !root.sink.audio || root.sink.audio.muted
    }
    Connections {
        target: SoundEvents
        function onRequested(event) { player.play(event); }
    }
    Connections {
        target: MenuState
        function onOpened(name) {
            SoundEvents.requested(name === "shutdown" || name === "logoff" ? "alert" : "menuOpen");
        }
    }
    // Referenced once by shell.qml, rather than once per screen/Desktop.
    readonly property bool active: player.sinkActive
}
