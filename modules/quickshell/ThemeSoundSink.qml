import QtQuick

// Playback port. Production decodes PCM; checks record requests without audio.
Item {
    property var sounds: ({})
    function play(source: string): bool { return false; }
}
