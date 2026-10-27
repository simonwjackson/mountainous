pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// The Win98 icon set, read once from themes/win98/icons/. The files are
// the approved mock's icons (dev/make-icons.sh), in the 16-colour palette
// on a 16-u grid (24 u for the Start menu's large icons).
//
// Placeholders that url() swaps for real colours:
//   #000001       outline (Win98Tokens.ink)
//   currentColor  the surface's text colour
//   #00ff01       battery level colour; width="7.77" its length (0 to 8 u)
Singleton {
    id: root

    readonly property var names: [
        "arrow-down", "arrow-left", "arrow-right", "arrow-up", "bad", "battery-bolt", "battery-plug",
        "battery", "bell-muted", "bell", "bluetooth-off", "bluetooth-on", "brightness", "builder-grey",
        "builder-off-grey", "builder-off", "builder", "builder-unknown", "builder-wait", "builder-warn",
        "check", "chevron", "chromium", "close", "commands", "disk-bad", "disk-muted", "disk-ok",
        "disk-warn", "display", "doc", "dot", "firefox", "folder", "glance", "help", "host", "hourglass", "lock",
        "logoff", "mark", "mic-failed",
        "minimize", "mic-recording", "mic-working", "obs", "oci-danger", "oci-muted",
        "oci-normal", "oci-warning", "ok", "programs", "ring", "run", "scale", "settings", "shutdown",
        "signal", "sun", "sync", "term", "tx", "volume-0", "volume-1", "volume-2", "volume-muted", "warn",
        "wifi-0", "wifi-1", "wifi-2", "wifi-3", "wifi-4", "wifi-off", "windows", "zed",
        // Find (Super+P) and Internet Explorer's Open (Ctrl+L)
        "find", "find-large", "globe", "globe-large",
        // The taskbar and session pieces (dev/make-parity-icons.sh).
        "favorites", "documents", "lock-computer", "computer", "system", "maximize", "restore"
    ]

    property var sources: ({})

    Instantiator {
        model: root.names

        FileView {
            required property string modelData
            path: Quickshell.shellPath("themes/win98/icons/" + modelData + ".svg")
            blockLoading: true
            printErrors: true
            onLoaded: {
                const next = Object.assign({}, root.sources);
                next[modelData] = text();
                root.sources = next;
            }
        }
    }

    function has(name) { return root.sources[name] !== undefined; }

    // The intrinsic size of an icon, in units: [width, height].
    function size(name) {
        const svg = root.sources[name];
        if (!svg) return [16, 16];
        const w = /width="([0-9.]+)"/.exec(svg), h = /height="([0-9.]+)"/.exec(svg);
        return [w ? Number(w[1]) : 16, h ? Number(h[1]) : 16];
    }

    // level: 0..1 for the battery; tone: its colour.
    function url(name, color, level, tone) {
        const svg = root.sources[name];
        if (!svg) return "";
        let out = svg.replace(/#000001/g, String(Win98Tokens.ink))
            .replace(/currentColor/g, String(color));
        if (level !== undefined && level !== null) {
            const w = Math.max(0, Math.min(8, Math.round(8 * level)));
            out = out.replace('width="7.77"', 'width="' + w + '"')
                .replace(/#00ff01/g, String(tone || "#00a000"));
        }
        return "data:image/svg+xml;utf8," + encodeURIComponent(out);
    }
}
