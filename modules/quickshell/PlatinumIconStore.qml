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

    // The top bar's quiet glyphs carry a value in the icon: speaker-0..3
    // (lit waves; muted adds the slash), brightness-1..8 (lit rays) and
    // cloud-meter (the cloud with the worst profile's meter; the bar
    // draws the fill). Straight edges sit on whole device pixels at 1.5.
    readonly property var names: [
        "appearance", "arrow", "band-down", "band-up", "battery", "bell", "bluetooth", "bolt", "builder", "brightness",
        "brightness-1", "brightness-2", "brightness-3", "brightness-4", "brightness-5", "brightness-6", "brightness-7",
        "brightness-8", "check", "close", "cloud", "cloud-meter", "desktop", "disk", "dot", "folder", "grip", "lock",
        "mark", "more", "plug", "pop", "popup", "ring", "scroll-left", "scroll-right", "slash", "speaker",
        "speaker-0", "speaker-1", "speaker-2", "speaker-3", "submenu",
        "volume-0", "volume-1", "volume-2",
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
