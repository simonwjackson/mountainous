pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia

// Short PCM samples stay decoded while enabled. Play does no file/process I/O.
ThemeSoundSink {
    id: root
    readonly property var sources: [...new Set(Object.values(root.sounds))]
    readonly property bool ready: voices.count === root.sources.length && root.sources.length > 0 && root.sources.every(function (_, index) {
        const voice = voices.itemAt(index) as Voice;
        return voice !== null && voice.effect.status === SoundEffect.Ready && !voice.warming;
    })
    function play(source: string): bool {
        const index = root.sources.indexOf(source);
        const voice = index >= 0 ? (voices.itemAt(index) as Voice) : null;
        if (!voice || voice.warming || voice.effect.status !== SoundEffect.Ready) return false;
        voice.effect.muted = false;
        voice.effect.stop();
        voice.effect.play();
        return true;
    }
    Repeater {
        id: voices
        model: root.sources
        delegate: Voice {}
    }
    component Voice: Item {
        id: voice
        required property string modelData
        property bool warming: true
        property SoundEffect effect: SoundEffect {
            source: Qt.resolvedUrl(voice.modelData)
            // The output sink already applies system volume. Multiplying
            // it here would apply volume twice. Never unmute the sink.
            volume: 1.0
            // Prime Qt's audio stream with silence after decode, not on the
            // first user event. The bank exists only while enabled/unmuted.
            onStatusChanged: if (status === SoundEffect.Ready) { voice.warming = true; muted = true; play(); }
            onPlayingChanged: if (!playing && status === SoundEffect.Ready) { voice.warming = false; muted = false; }
        }
    }
}
