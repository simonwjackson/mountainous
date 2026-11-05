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
        for (const theme of entries) {
            const ids = new Set();
            for (const appearance of theme.appearances) {
                if (!/^[a-z][a-z0-9-]*$/.test(appearance.id) || ids.has(appearance.id)
                    || (appearance.mode !== "light" && appearance.mode !== "dark"))
                    throw new Error("Invalid appearance for " + theme.id);
                ids.add(appearance.id);
            }
        }
        return entries;
    }
    function find(id) { return themes.find(function (theme) { return theme.id === id; }) || null; }
    function defaultAppearance(theme, mode) { return mode === "light" ? (theme === "memphis" ? "standard" : "light") : "dark-grey"; }
    function appearance(theme, id) {
        const entry = find(theme);
        if (!entry) return null;
        // Compatibility for mode-only clients, not a second choice list.
        const key = id === "light" || id === "dark" ? defaultAppearance(theme, id) : id;
        return entry.appearances.find(function (a) { return a.id === key; }) || null;
    }
    FileView {
        id: registry
        path: Quickshell.shellPath("themes.json")
        blockLoading: true
    }
}
