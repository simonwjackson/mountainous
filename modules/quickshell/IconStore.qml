pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The SVG icons of the top bar and its menus, read once from icons/.
//
// ChicagoFLF has no ● ○ ✓ × arrows or lock, and the bar draws no glyph
// from another face, so every mark is an SVG file. A file draws in
// `currentColor` and, where a mark cuts into another, in #ff00ff for the
// knock-out. url() swaps both for real colours and returns a data URL, so
// one file serves every tone, the open title and both appearances.
Singleton {
    id: root

    readonly property var names: [
        "arrow", "battery", "bell", "bluetooth", "bolt", "brightness", "check",
        "close", "cloud", "disk", "dot", "grip", "lock", "mark", "more", "plug",
        "ring", "slash", "speaker", "volume-0", "volume-1", "volume-2",
        "volume-muted", "wifi-0", "wifi-1", "wifi-2", "wifi-3", "wifi-4"
    ]

    property var sources: ({})

    Instantiator {
        model: root.names

        FileView {
            required property string modelData
            path: Quickshell.shellPath("icons/" + modelData + ".svg")
            blockLoading: true
            printErrors: true
            onLoaded: {
                const next = Object.assign({}, root.sources);
                next[modelData] = text();
                root.sources = next;
            }
        }
    }

    function url(name, color, knock) {
        const svg = root.sources[name];
        if (!svg) return "";
        const filled = svg.replace(/currentColor/g, String(color))
            .replace(/#ff00ff/g, String(knock || "transparent"));
        return "data:image/svg+xml;utf8," + encodeURIComponent(filled);
    }
}
