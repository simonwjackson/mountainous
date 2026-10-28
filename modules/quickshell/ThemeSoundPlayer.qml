import QtQuick

// The injectable sink is also the audio resource boundary. Disabled, muted or
// missing output means no sink object at all, including during startup.
Item {
    id: root
    required property var soundSet
    required property bool available
    required property bool muted
    property Component sinkComponent: Component { ThemeSoundBank {} }
    readonly property bool sinkActive: sinkLoader.item !== null
    visible: false

    function play(event) {
        if (!root.enabled || !root.available || root.muted) return false;
        const source = root.soundSet[event];
        const sink = sinkLoader.item as ThemeSoundSink;
        return typeof source === "string" && source !== "" && sink
            ? sink.play(source) : false;
    }
    Loader {
        id: sinkLoader
        active: root.enabled && root.available && !root.muted
        sourceComponent: root.sinkComponent
        onLoaded: item.sounds = Qt.binding(function () { return root.soundSet; })
    }
}
