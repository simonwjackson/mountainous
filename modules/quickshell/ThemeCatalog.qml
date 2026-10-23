pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The same registry is read by modules/theme.nix. No second list of IDs.
Singleton {
    readonly property var themes: JSON.parse(registry.text())
    function find(id) { return themes.find(function (theme) { return theme.id === id; }) || null; }
    FileView {
        id: registry
        path: Quickshell.shellPath("themes.json")
        blockLoading: true
    }
}
