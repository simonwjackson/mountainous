pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The same registry is read by modules/theme.nix. No second list of IDs.
Singleton {
    readonly property var themes: parseRegistry(registry.text())
    function parseRegistry(text) {
        const entries = JSON.parse(text);
        if (!Array.isArray(entries))
            throw new Error("Theme registry must be an array");
        for (let index = 0; index < entries.length; ++index) {
            const entry = entries[index];
            if (entry.pyxampFace !== "platinum" && entry.pyxampFace !== "winamp")
                throw new Error("Invalid pyxampFace for theme " + entry.id);
        }
        return entries;
    }
    function find(id) { return themes.find(function (theme) { return theme.id === id; }) || null; }
    FileView {
        id: registry
        path: Quickshell.shellPath("themes.json")
        blockLoading: true
    }
}
