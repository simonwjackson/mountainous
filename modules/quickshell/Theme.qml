pragma Singleton

import Quickshell
import Hensou as Kit
import Quickshell.Io
import QtQuick

// Appearance state and tokens for the unthemed omni bar card and overlays.
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
    readonly property string namePath: stateDir + "/mountainous/theme-name"
    readonly property string name: Kit.Theme.name

    readonly property string extraPath: stateDir + "/mountainous/theme-extra"

    readonly property string soundsPath: stateDir + "/mountainous/theme-sounds"
    property string soundsState: "on"
    readonly property bool soundsEnabled: soundsState !== "off"

    FileView {
        path: root.soundsPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.soundsState = text().trim() === "off" ? "off" : "on"
        onLoadFailed: root.soundsState = "on"
    }

    readonly property string mode: Kit.Theme.mode
    readonly property bool dark: Kit.Theme.dark

    // "Extra dark": the stored choice, on or off. Each theme and native
    // toolkit adapter decides how it applies in dark mode. A missing file
    // is off; Win98 keeps this preference but ignores it.
    readonly property string extraState: Kit.Theme.extraState
    readonly property bool extraDark: Kit.Theme.extraDark

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const value = text().trim();
            if (value === "dark" || value === "light") Kit.Theme.mode = value;
        }
    }

    FileView {
        path: root.extraPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: Kit.Theme.extraState = text().trim() === "on" ? "on" : "off"
        onLoadFailed: Kit.Theme.extraState = "off"
    }

    FileView {
        path: root.namePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.choose(ThemeCatalog.find(text().trim()) ? text().trim() : "platinum")
        onLoadFailed: root.choose("platinum")
    }

    // The theme's icons (themes.json "art.icons") become the process-wide
    // icon theme before the name changes, so the next Desktop's
    // Quickshell.iconPath() calls already resolve, and are cached, under
    // it. Quickshell.iconTheme comes from lib/patches/quickshell-icon-
    // theme.patch; an unpatched Quickshell keeps its startup icon theme.
    // Theme.qml also runs without the registry: the Win98 control gallery
    // and the dictation test stage it alone, and a reload of a half-linked
    // tree may lack a new file. Then there is no icon theme to choose.
    function choose(id) {
        const entry = typeof ThemeCatalog !== "undefined" ? ThemeCatalog.find(id) : null;
        if (entry && entry.art && ("iconTheme" in Quickshell)) Quickshell.iconTheme = entry.art.icons;
        Kit.Theme.name = id;
    }
    readonly property string iconTheme: ("iconTheme" in Quickshell) ? Quickshell.iconTheme : ""
    Component.onCompleted: root.choose(root.name)

    // The active Desktop may append diagnostic words, not shared tokens.
    property string chromeStatus: ""

    // Query the live palette without exposing a second write path.
    // The first three words are the old answer; the rest were added after.
    IpcHandler {
        target: "theme"
        function current(): string {
            return root.mode + " " + root.bgBase + " " + root.bgVeil
                + " extra=" + root.extraState + root.chromeStatus + " theme=" + root.name
                + " icons=" + root.iconTheme;
        }
    }

    readonly property string fontFamily: Kit.Theme.fontFamily
    readonly property int radiusSmall: Kit.Theme.radiusSmall
    readonly property int radiusMedium: Kit.Theme.radiusMedium
    readonly property int radiusLarge: Kit.Theme.radiusLarge
    readonly property color bgBase: Kit.Theme.bgBase
    readonly property color bgPanel: Kit.Theme.bgPanel
    readonly property color bgSelected: Kit.Theme.bgSelected
    readonly property color bgActive: Kit.Theme.bgActive
    readonly property color bgInput: Kit.Theme.bgInput
    readonly property color bgSeparator: Kit.Theme.bgSeparator
    readonly property color bgVeil: Kit.Theme.bgVeil
    readonly property color borderMuted: Kit.Theme.borderMuted
    readonly property color accent: Kit.Theme.accent
    readonly property color danger: Kit.Theme.danger
    readonly property color warning: Kit.Theme.warning
    readonly property color textPrimary: Kit.Theme.textPrimary
    readonly property color textInput: Kit.Theme.textInput
    readonly property color textSecondary: Kit.Theme.textSecondary
    readonly property color textPage: Kit.Theme.textPage
    readonly property color textMuted: Kit.Theme.textMuted
    readonly property color textHint: Kit.Theme.textHint
    readonly property color textDim: Kit.Theme.textDim
    readonly property color textDetail: Kit.Theme.textDetail
    readonly property color textOff: Kit.Theme.textOff
}
