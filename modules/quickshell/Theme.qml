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

    property string mode: "dark"
    readonly property bool dark: mode !== "light"

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

    // Query the live palette without exposing a second write path.
    IpcHandler {
        target: "theme"
        function current(): string { return root.mode + " " + root.bgBase + " " + root.bgVeil; }
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
}
