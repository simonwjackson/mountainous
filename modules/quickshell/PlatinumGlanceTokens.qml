pragma Singleton

import Quickshell
import QtQuick

// The Fleet views' and the glance space's own tokens, beside PlatinumTokens
// (which they reuse for the window frame, text, bevels and the highlight).
// Values are the approved mocks' (/tmp/hud-mock, /tmp/glance-mock
// DIRECTION.md). The windoids are dark grey in Extra dark, as the menus
// are: they are transient.
Singleton {
    id: root
    readonly property bool dark: Theme.dark
    readonly property bool extraDark: Theme.dark && Theme.extraDark

    // Finder list view: the list surface and the sorted column's tint.
    readonly property color listSurface: dark ? "#2c2c2c" : "#ffffff"
    readonly property color listSorted: dark ? "#333333" : "#eeeeee"

    // Mac OS 8 progress bar: a black frame, a sunken empty part, a fill
    // with a light top line. The fill takes the tone when the value has one.
    readonly property color barEmpty: dark ? "#242424" : "#eeeeee"
    readonly property color barFill: dark ? "#5858d0" : "#333399"
    readonly property color barFillHi: dark ? "#8686e6" : "#6666cc"
    readonly property color barWarning: dark ? "#c08a3e" : "#b8781a"
    readonly property color barWarningHi: dark ? "#e2b878" : "#e0a84a"
    readonly property color barDanger: dark ? "#c44848" : "#9e2525"
    readonly property color barDangerHi: dark ? "#ec8a8a" : "#cf5a5a"

    // Status lights: [base, highlight, rim]. Lights, so one set for every
    // appearance. Shape says the status, colour says the tone.
    readonly property var lamp: ({
        normal: ["#3c9a45", "#a8e6ad", "#1d5523"],
        warning: ["#d9951c", "#ffe39a", "#7a4d12"],
        danger: ["#cc2f2b", "#ff9e94", "#6a1212"],
        muted: ["#8c8c8c", "#d6d6d6", "#4a4a4a"]
    })

    // Windoid geometry (Mac OS 8 utility windows are thinner than document
    // windows).
    readonly property int titleHeight: 16
    readonly property int boxSize: 11

    // ---------------------------------------------------------- glance
    // The background: black ink on alternate cells of a checker drawn on
    // exact device pixels, the rest clear, so the work recedes under it.
    // ditherCell is in device pixels: 3 is about one 72-dpi Mac pixel on
    // Myoko's panel; 1 is the finest the panel can show.
    readonly property int ditherCell: 3
    readonly property color ditherInk: "#000000"
    readonly property color ditherGround: "transparent"
    // Extra dark: plain black, so nothing of the work stays lit (OLED).
    readonly property bool ditherSolid: extraDark
    readonly property color solidGround: "#000000"

    // Zoom rects: a hair outline in both inks, so it shows over the dither,
    // a white window and a black one alike.
    readonly property color zoomOuter: "#ffffff"
    readonly property color zoomInner: "#000000"
    readonly property int zoomTrail: 4
}
