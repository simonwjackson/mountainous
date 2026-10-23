pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Shared visual tokens for Kamoi on desktop (bars, dock, omni bar).
//
// Two palettes, one live value. The `desktop-theme` command owns the state
// file; this singleton only reads it, so the bar, the dock and the omni bar
// change with the rest of the desktop and nothing has to be told twice.
Singleton {
    id: root

    readonly property string stateDir: {
        const x = Quickshell.env("XDG_STATE_HOME");
        return (x && x !== "") ? x : Quickshell.env("HOME") + "/.local/state";
    }
    readonly property string statePath: stateDir + "/mountainous/theme"
    readonly property string extraPath: stateDir + "/mountainous/theme-extra"

    property string mode: "dark"
    readonly property bool dark: mode !== "light"

    // "Extra dark": the stored choice, on or off. It changes only the top
    // bar, and only in dark mode (see barBlack). A missing file is off.
    property string extraState: "off"
    readonly property bool extraDark: extraState === "on"

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const value = text().trim();
            if (value === "dark" || value === "light") root.mode = value;
        }
    }

    FileView {
        path: root.extraPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.extraState = text().trim() === "on" ? "on" : "off"
        onLoadFailed: root.extraState = "off"
    }

    // Query the live palette without exposing a second write path.
    // The first three words are the old answer; the rest were added after.
    IpcHandler {
        target: "theme"
        function current(): string {
            return root.mode + " " + root.bgBase + " " + root.bgVeil
                + " extra=" + root.extraState + " bar=" + root.barSurface
                + " rule=" + (root.barRuled ? root.barRule : "none");
        }
    }

    readonly property string fontFamily: "monospace"

    // Corner radii
    readonly property int radiusSmall: 4
    readonly property int radiusMedium: 6
    readonly property int radiusLarge: 8

    // Background surfaces. Dark keeps pure black so OLED pixels turn off.
    readonly property color bgBase: dark ? "#000000" : "#f5f5f5"
    readonly property color bgPanel: dark ? "#141414" : "#ffffff"
    readonly property color bgSelected: dark ? "#2a2a2a" : "#e4e4e4"
    readonly property color bgActive: dark ? "#303030" : "#dcdcdc"
    readonly property color bgInput: dark ? "#0d0d0d" : "#f8f8f8"
    readonly property color bgSeparator: dark ? "#3a3a3a" : "#c8c8c8"

    // The scrim behind the omni bar stays dark in both themes on purpose.
    // It sits over arbitrary windows, so a light scrim can land on a white
    // window and disappear, taking the modal signal with it. Dark also keeps
    // the white light-theme card separated from what is behind it.
    readonly property color bgVeil: "#b4000000"

    // Borders and accents
    readonly property color borderMuted: dark ? "#2e2e2e" : "#c0c0c0"
    readonly property color accent: dark ? "#6a9fb5" : "#3d7a94"
    readonly property color danger: dark ? "#d27d7d" : "#9f3333"
    readonly property color warning: dark ? "#d5a66f" : "#925b24"

    // Text hierarchy
    readonly property color textPrimary: dark ? "#e0e0e0" : "#1a1a1a"
    readonly property color textInput: dark ? "#e8e8e8" : "#101010"
    readonly property color textSecondary: dark ? "#c0c0c0" : "#303030"
    readonly property color textPage: dark ? "#c8c8c8" : "#383838"
    readonly property color textMuted: dark ? "#808080" : "#606060"
    readonly property color textHint: "#707070"
    readonly property color textDim: dark ? "#606060" : "#808080"
    readonly property color textDetail: dark ? "#6a6a6a" : "#787878"
    readonly property color textOff: dark ? "#404040" : "#b0b0b0"

    //----------------------------------------------------------------
    // PLATINUM: the top bar and the menus that open from it.
    //----------------------------------------------------------------
    // Mac OS 8.1, read in a modern way. Light takes the 8.1 values: bar
    // #DDDDDD, a black rule, bevels #FFFFFF/#999999, a #222222 hard
    // shadow and the #333399 highlight. Dark is dark grey Platinum: a
    // #363636 bar on the same black rule, over dark grey menus.
    // Extra dark (dark mode only) makes the bar black with no rule, which
    // keeps the OLED rule above; the menus stay dark grey, because menus
    // are transient and the OLED argument does not apply to them.
    // The dock, the omni bar and the popups keep the tokens above.

    // ChicagoFLF 2.1 is the only face in the bar and its menus. It lacks
    // ● ○ ✓ × the arrows and a lock; those are SVG files in icons/.
    readonly property string platinumFont: "ChicagoFLF"
    readonly property int platinumText: 14      // bar titles, menu rows
    readonly property int platinumSmall: 12     // details, buttons, tabs
    readonly property int platinumHint: 11      // key hints
    readonly property real platinumTracking: 0.3

    // One physical rule at every scale: 2 px at 1.5, 1 px at 1 and 2.
    // modules/hyprland sets the scale; TopBar keeps pixelRatio current.
    property real pixelRatio: 1.5
    readonly property real hair: Math.max(1, Math.round(pixelRatio)) / pixelRatio

    readonly property int barHeight: 28

    // The bar has three appearances: light, dark grey, and black (extra
    // dark, in dark mode only). Every bar token below picks from them.
    readonly property bool barBlack: dark && extraDark

    // The bar surface is one token.
    readonly property color barSurface: !dark ? "#dddddd" : barBlack ? "#000000" : "#363636"
    // The Mac OS 8 rule under the bar. On black there is no rule at all:
    // the bar meets the windows directly, so no lit line stays on screen.
    readonly property bool barRuled: !barBlack
    readonly property color barRule: "#000000"
    readonly property color barText: !dark ? "#000000" : barBlack ? "#e6e6e6" : "#ececec"
    readonly property color barTextSecondary: !dark ? "#3a3a3a" : barBlack ? "#a4a4a4" : "#b8b8b8"
    // About 3:1 on each surface, so a muted readout still reads.
    readonly property color barTextOff: !dark ? "#8a8a8a" : barBlack ? "#5c5c5c" : "#808080"
    readonly property color barHover: dark ? "#1fffffff" : "#1a000000"
    readonly property color barDanger: dark ? "#ef8f8f" : "#9e2525"
    readonly property color barWarning: dark ? "#d5a66f" : "#7a4d12"
    // Bar buttons (dictation Retry and Dismiss). Light and grey bars give
    // them the Platinum bevel. On black they lose it, which would read as
    // noise there.
    readonly property bool barBevelled: !barBlack
    readonly property color barButton: !dark ? "#e6e6e6" : barBlack ? "#262626" : "#444444"
    readonly property color barButtonEdge: barBlack ? "#8c8c8c" : "#000000"

    // The highlight: an open title, a pressed control, a selected row.
    readonly property color highlight: dark ? "#5858d0" : "#333399"
    readonly property color highlightText: "#ffffff"

    readonly property color menuSurface: dark ? "#3a3a3a" : "#dddddd"
    readonly property color menuText: dark ? "#ececec" : "#000000"
    readonly property color menuTextSecondary: dark ? "#b8b8b8" : "#3a3a3a"
    readonly property color menuTextOff: dark ? "#767676" : "#8a8a8a"
    readonly property color menuEdge: "#000000"
    readonly property color bevelLight: dark ? "#565656" : "#ffffff"
    readonly property color bevelDark: dark ? "#1e1e1e" : "#999999"
    readonly property color menuShadow: dark ? "#9e000000" : "#222222"
    readonly property color well: dark ? "#242424" : "#bdbdbd"
    readonly property color raised: dark ? "#444444" : "#e6e6e6"
    readonly property color menuDanger: dark ? "#ef8f8f" : "#9e2525"
    readonly property color menuWarning: dark ? "#d5a66f" : "#7a4d12"

    // The menu grid. Every menu has the same three columns:
    //   gutter  marks (● ○ ✓), checkbox boxes, icons; centred on one line
    //   text    every label, title, section, detail and hint starts here
    //   right   every value and the last button end here
    // A menu whose list scrolls moves its right edge in by the scroll bar,
    // for every row at once, so the column stays one line.
    readonly property int menuGutter: 6          // gutter's left edge
    readonly property int menuGutterWidth: 20
    readonly property int menuTextLeft: 30
    readonly property int menuRightInset: 12
    readonly property int menuScrollBar: 16
    readonly property int menuGap: 8             // between items in a row
    readonly property int menuButtonHeight: 22
    readonly property int menuLine: 26           // one-line row
    readonly property int menuRow: 40            // two-line row

    // A tone word from the models (battery.js, oci-model.js,
    // notification-model.js) as a colour. Unknown words read as normal.
    function barTone(tone) {
        if (tone === "danger") return root.barDanger;
        if (tone === "warning") return root.barWarning;
        if (tone === "muted" || tone === "off") return root.barTextOff;
        if (tone === "quiet") return root.barTextSecondary;
        return root.barText;
    }

    function menuTone(tone) {
        if (tone === "danger") return root.menuDanger;
        if (tone === "warning") return root.menuWarning;
        if (tone === "muted" || tone === "off") return root.menuTextSecondary;
        return root.menuText;
    }
}
