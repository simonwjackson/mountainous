pragma Singleton

import Quickshell
import QtQuick
import qs

// The Windows 98 theme's tokens: the unit, the two appearances, the font
// and the metrics every Win98 control shares.
//
// The unit. One Win98 pixel ("u") is two physical pixels, so every bevel
// line is exactly 1 u and lands on whole physical pixels. At Myoko's scale
// 1.5, 1 u = 4/3 logical px. All geometry is whole units: never centre
// with anchors.centerIn on an odd remainder, use snap(). It rounds a half
// unit down the screen and to the right, as the mock's browser snapped
// every box and every text baseline to its CSS pixel (1 u), so the Qt
// controls land on the same pixels as the approved mock.
//
// The appearance follows Theme.dark: light is Windows Standard (sampled
// from Win98 screenshots), dark is the dark grey ramp from the approved
// mock. Both keep the same order of light and dark edges.
Singleton {
    id: root

    // The window's device pixel ratio. The surface that hosts the theme
    // keeps it current, as TopBar does for Theme.pixelRatio. One value for
    // the process: two screens at different scales would need per-window
    // tokens.
    property real pixelRatio: 1.5
    readonly property real u: 2 / pixelRatio

    // No roll-out when true. The host sets it; nothing in the session
    // publishes a reduced-motion preference yet.
    property bool reducedMotion: false
    readonly property int rollDuration: reducedMotion ? 0 : 120

    function px(n) { return n * root.u; }
    // To the whole unit; a half goes up (down the screen, to the right).
    function snap(v) { return Math.floor(v / root.u + 0.5 + 1e-6) * root.u; }
    // Up to a whole unit, for sizes measured from text.
    function ceilU(v) { return Math.ceil(v / root.u - 1e-6) * root.u; }

    readonly property bool dark: Theme.dark

    // ---- colours. hi/li: outer/inner light edge; sh/dk: inner/outer dark edge.
    readonly property color face: dark ? "#3c3c3c" : "#c0c0c0"
    readonly property color hi: dark ? "#7a7a7a" : "#ffffff"
    readonly property color li: dark ? "#565656" : "#dfdfdf"
    readonly property color sh: dark ? "#222222" : "#808080"
    readonly property color dk: "#000000"
    readonly property color text: dark ? "#ececec" : "#000000"
    // Disabled and secondary text.
    readonly property color gray: dark ? "#8e8e8e" : "#808080"
    // The 1-u shadow under disabled text. Dark grey has none.
    readonly property color emboss: dark ? "transparent" : "#ffffff"
    // Fields and lists.
    readonly property color win: dark ? "#1d1d1d" : "#ffffff"
    readonly property color winText: dark ? "#e8e8e8" : "#000000"
    readonly property color selection: dark ? "#2f4fc7" : "#000080"
    readonly property color selectionText: "#ffffff"
    // Captions: a gradient from the left.
    readonly property color caption1: "#000080"
    readonly property color caption2: "#1084d0"
    readonly property color inactiveCaption1: dark ? "#2a2a2a" : "#808080"
    readonly property color inactiveCaption2: dark ? "#4a4a4a" : "#c0c0c0"
    readonly property color captionText: "#ffffff"
    readonly property color inactiveCaptionText: dark ? "#9a9a9a" : "#c0c0c0"
    readonly property color tip: dark ? "#3a3a2a" : "#ffffe1"
    readonly property color tipText: dark ? "#f0f0d8" : "#000000"
    readonly property color tipEdge: dark ? "#8a8a7a" : "#000000"
    readonly property color desktop: dark ? "#000000" : "#008080"
    // The checkerboard of a scroll track and a latched button.
    readonly property color dither: dark ? "#565656" : "#ffffff"
    readonly property color danger: dark ? "#ff8a80" : "#800000"
    readonly property color warning: dark ? "#e0b060" : "#5c4400"
    readonly property color ok: dark ? "#7fd07f" : "#008000"
    readonly property color badge: dark ? "#d03030" : "#c00000"
    readonly property color focus: dark ? "#ececec" : "#000000"
    // Icon outlines. Black on #C0C0C0; on #3C3C3C black has 1.9:1 and the
    // outlines vanish (mock tray, dark grey), so dark grey draws them in a
    // grey that stays darker than the icons' white and yellow fills and
    // lighter than the face.
    readonly property color ink: dark ? "#9a9a9a" : "#000000"

    function tone(name) {
        if (name === "danger") return root.danger;
        if (name === "warning") return root.warning;
        if (name === "ok") return root.ok;
        if (name === "muted" || name === "off") return root.gray;
        return root.text;
    }

    // ---- the font. W95FA Grid: one font pixel is 1 u at 12.5 u. Qt rounds
    // font sizes to whole logical pixels, so Win98Text draws at 25 px (two
    // text pixels per font pixel, exact) and scales by u / 2.
    readonly property string fontFamily: "W95FA Grid"
    readonly property int fontRaster: 25
    readonly property real textScale: u / 2
    readonly property int lineUnits: 13       // ascent 10 + descent 3
    readonly property int ascentUnits: 10
    readonly property real line: lineUnits * u

    FontMetrics {
        id: metrics
        font.family: root.fontFamily
        font.pixelSize: root.fontRaster
        font.hintingPreference: Font.PreferNoHinting
        font.kerning: false
    }

    // A string's width in logical px. Drawn bold adds 1 u per letter.
    function textWidth(s, bold) {
        const str = String(s);
        return metrics.advanceWidth(str) * root.textScale + (bold ? str.length * root.u : 0);
    }
    function widest(strings, bold) {
        let w = 0;
        for (const s of strings) w = Math.max(w, root.textWidth(s, bold));
        return w;
    }

    // "&Programs" -> "Programs" with access index 0; "&&" is a literal &.
    function plainText(s) {
        return String(s).replace(/&(&?)/g, (m, lit) => lit ? "&" : "");
    }
    function accessIndex(s) {
        const str = String(s);
        let out = 0;
        for (let i = 0; i < str.length; i++) {
            if (str[i] === "&") {
                if (str[i + 1] === "&") { out++; i++; continue; }
                return i + 1 < str.length ? out : -1;
            }
            out++;
        }
        return -1;
    }
    // The key a letter press matches: the marked letter, or the first.
    function accessKey(s) {
        const plain = root.plainText(s);
        const i = root.accessIndex(s);
        return (i >= 0 ? plain.charAt(i) : plain.charAt(0)).toLowerCase();
    }

    // ---- metrics, in units (multiply by u). From the mock's CSS.
    readonly property int buttonHeight: 23
    readonly property int buttonSmallHeight: 21
    readonly property int buttonMinWidth: 75
    readonly property int fieldHeight: 21
    readonly property int captionHeight: 18
    readonly property int captionButtonWidth: 16
    readonly property int captionButtonHeight: 14
    readonly property int frame: 3                 // window and menu padding
    readonly property int menuItemHeight: 18
    readonly property int menuBigItemHeight: 32
    readonly property int menuBand: 26
    readonly property int scrollBar: 16
    readonly property int listRow: 16
    readonly property int listRowTwo: 34
    readonly property int tabStrip: 22
    readonly property int toolButton: 22
    readonly property int trayButton: 20
    readonly property int statusPane: 18
    readonly property int checkBox: 13
    readonly property int radio: 12
}
