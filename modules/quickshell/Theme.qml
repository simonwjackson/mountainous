pragma Singleton

import Quickshell
import QtQuick

// Shared visual tokens for Kamoi on desktop (bars, dock, omni bar).
Singleton {
    id: root

    readonly property string fontFamily: "monospace"

    // Corner radii
    readonly property int radiusSmall: 4
    readonly property int radiusMedium: 6
    readonly property int radiusLarge: 8

    // Background surfaces
    readonly property color bgBase: "#000000"
    readonly property color bgPanel: "#141414"
    readonly property color bgSelected: "#2a2a2a"
    readonly property color bgActive: "#303030"
    readonly property color bgSeparator: "#3a3a3a"
    readonly property color bgVeil: "#b4000000"

    // Borders and accents
    readonly property color borderMuted: "#2e2e2e"
    readonly property color accent: "#6a9fb5"

    // Text hierarchy
    readonly property color textPrimary: "#e0e0e0"
    readonly property color textInput: "#e8e8e8"
    readonly property color textSecondary: "#c0c0c0"
    readonly property color textPage: "#c8c8c8"
    readonly property color textMuted: "#808080"
    readonly property color textHint: "#707070"
    readonly property color textDim: "#606060"
    readonly property color textDetail: "#6a6a6a"
    readonly property color textOff: "#404040"
}
