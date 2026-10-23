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
    readonly property string currentMode: Theme.mode
    readonly property bool extraDark: Theme.extraDark
    readonly property bool applying: applyProcess.running
    property string error: ""
    readonly property var choices: {
        const choices = [];
        for (const theme of themes) {
            for (const appearance of theme.appearances) {
                choices.push({theme: theme.id, label: theme.label, mode: appearance.mode,
                    appearance: appearance.label, thumbnail: appearance.thumbnail});
            }
        }
        return choices;
    }
    function open(onScreen) { MenuState.close(); screen = onScreen || Quickshell.screens[0]; visible = true; }
    function close() { visible = false; }
    function preview(theme, mode) {
        const entry = ThemeCatalog.find(theme);
        const appearance = entry ? entry.appearances.find(function (a) { return a.mode === mode; }) : null;
        return appearance ? Qt.resolvedUrl(appearance.thumbnail) : "";
    }
    function apply(theme, mode, extra) {
        const entry = ThemeCatalog.find(theme);
        if (!entry || !entry.appearances.some(function (a) { return a.mode === mode; }) || applying) return;
        root.error = "";
        applyProcess.command = ["desktop-theme", "apply", theme, mode, extra ? "on" : "off"];
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
