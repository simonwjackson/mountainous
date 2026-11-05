pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Selection is the saved state, not a draft. Themes choose only their view.
Singleton {
    id: root
    property bool visible: false
    property var screen: null
    readonly property var themes: ThemeCatalog.themes
    readonly property string currentTheme: Theme.name
    readonly property string currentAppearance: Theme.appearance
    readonly property string currentMode: Theme.mode
    readonly property bool soundsEnabled: Theme.soundsEnabled
    readonly property bool extraDark: Theme.extraDark
    readonly property bool applying: applyProcess.running
    property string error: ""
    readonly property var choices: {
        const choices = [];
        for (const theme of themes) {
            for (const appearance of theme.appearances) {
                choices.push({theme: theme.id, label: theme.label, mode: appearance.mode,
                    appearanceId: appearance.id, appearance: appearance.label, thumbnail: appearance.thumbnail});
            }
        }
        return choices;
    }
    function open(onScreen) { MenuState.close(); screen = onScreen || Quickshell.screens[0]; visible = true; }
    function close() { visible = false; }
    function preview(theme, appearanceId) {
        const appearance = ThemeCatalog.appearance(theme, appearanceId);
        return appearance ? Qt.resolvedUrl(appearance.thumbnail) : "";
    }
    function setSounds(enabled) {
        if (applying) return;
        root.error = "";
        applyProcess.command = ["desktop-theme", "sounds", enabled ? "on" : "off"];
        applyProcess.running = true;
    }
    function apply(theme, appearanceId, extra) {
        const appearance = ThemeCatalog.appearance(theme, appearanceId);
        if (!appearance || applying) return;
        root.error = "";
        applyProcess.command = ["desktop-theme", "apply", theme, appearance.id, extra ? "on" : "off"];
        applyProcess.running = true;
    }
    Process {
        id: applyProcess
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") root.error = text.trim() }
        onExited: function (code) {
            if (code !== 0 && root.error === "") root.error = "The desktop appearance could not be changed.";
        }
    }
}
