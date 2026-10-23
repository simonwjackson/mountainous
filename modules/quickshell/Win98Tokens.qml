pragma Singleton

import Quickshell
import QtQuick

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

    // The unit belongs to each window: 2 physical px at that window's own
    // device pixel ratio. Every control reads it through unitFor(QsWindow
    // .window), so a taskbar on a scale-1 screen and one on a scale-1.5
    // screen each draw 2-px bevels. pixelRatio and u are only the fallback
    // for an object outside a window (a Scope).
    property real pixelRatio: 1.5
    readonly property real u: 2 / pixelRatio
    function unitFor(w) {
        return w && w.devicePixelRatio > 0 ? 2 / w.devicePixelRatio : root.u;
    }

    // No roll-out when true. The host sets it; nothing in the session
    // publishes a reduced-motion preference yet.
    property bool reducedMotion: false
    readonly property int rollDuration: reducedMotion ? 0 : 120

    function px(n, unit) { return n * (unit || root.u); }
    // To the whole unit; a half goes up (down the screen, to the right).
    function snap(v, unit) { const k = unit || root.u; return Math.floor(v / k + 0.5 + 1e-6) * k; }
    // To the half unit: one physical pixel. The mock's browser centred boxes
    // and text runs across (horizontally) without snapping them to a unit;
    // a half unit still lands on whole physical pixels.
    function half(v, unit) { const k = (unit || root.u) / 2; return Math.round(v / k + 1e-6) * k; }
    // Up to a whole unit, for sizes measured from text.
    function ceilU(v, unit) { const k = unit || root.u; return Math.ceil(v / k - 1e-6) * k; }

    readonly property bool dark: Theme.dark

    // ---- colours. hi/li: outer/inner light edge; sh/dk: inner/outer dark edge.
    // palette(dark) is the one source: the properties below read the current
    // appearance, and a preview of the other scheme (Display Properties)
    // passes palette(true or false) to the controls that draw it.
    // ink is the icons' outline: black on #C0C0C0, but on #3C3C3C black has
    // 1.9:1 and the outlines vanish, so dark grey draws them in a grey that
    // stays darker than the icons' white and yellow fills.
    function palette(dark) {
        return {
            face: dark ? "#3c3c3c" : "#c0c0c0",
            hi: dark ? "#7a7a7a" : "#ffffff",
            li: dark ? "#565656" : "#dfdfdf",
            sh: dark ? "#222222" : "#808080",
            dk: "#000000",
            text: dark ? "#ececec" : "#000000",
            gray: dark ? "#8e8e8e" : "#808080",
            emboss: dark ? "transparent" : "#ffffff",
            win: dark ? "#1d1d1d" : "#ffffff",
            winText: dark ? "#e8e8e8" : "#000000",
            selection: dark ? "#2f4fc7" : "#000080",
            selectionText: "#ffffff",
            caption1: "#000080",
            caption2: "#1084d0",
            inactiveCaption1: dark ? "#2a2a2a" : "#808080",
            inactiveCaption2: dark ? "#4a4a4a" : "#c0c0c0",
            captionText: "#ffffff",
            inactiveCaptionText: dark ? "#9a9a9a" : "#c0c0c0",
            tip: dark ? "#3a3a2a" : "#ffffe1",
            tipText: dark ? "#f0f0d8" : "#000000",
            tipEdge: dark ? "#8a8a7a" : "#000000",
            desktop: dark ? "#000000" : "#008080",
            dither: dark ? "#565656" : "#ffffff",
            danger: dark ? "#ff8a80" : "#800000",
            warning: dark ? "#e0b060" : "#5c4400",
            ok: dark ? "#7fd07f" : "#008000",
            badge: dark ? "#d03030" : "#c00000",
            focus: dark ? "#ececec" : "#000000",
            ink: dark ? "#9a9a9a" : "#000000"
        };
    }
    readonly property var current: palette(dark)
    readonly property color face: current.face
    readonly property color hi: current.hi
    readonly property color li: current.li
    readonly property color sh: current.sh
    readonly property color dk: current.dk
    readonly property color text: current.text
    readonly property color gray: current.gray
    readonly property color emboss: current.emboss
    readonly property color win: current.win
    readonly property color winText: current.winText
    readonly property color selection: current.selection
    readonly property color selectionText: current.selectionText
    readonly property color caption1: current.caption1
    readonly property color caption2: current.caption2
    readonly property color inactiveCaption1: current.inactiveCaption1
    readonly property color inactiveCaption2: current.inactiveCaption2
    readonly property color captionText: current.captionText
    readonly property color inactiveCaptionText: current.inactiveCaptionText
    readonly property color tip: current.tip
    readonly property color tipText: current.tipText
    readonly property color tipEdge: current.tipEdge
    readonly property color desktop: current.desktop
    readonly property color dither: current.dither
    readonly property color danger: current.danger
    readonly property color warning: current.warning
    readonly property color ok: current.ok
    readonly property color badge: current.badge
    readonly property color focus: current.focus
    readonly property color ink: current.ink

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
    function textWidth(s, bold, unit) {
        const str = String(s), k = unit || root.u;
        return metrics.advanceWidth(str) * k / 2 + (bold ? str.length * k : 0);
    }
    function widest(strings, bold, unit) {
        let w = 0;
        for (const s of strings) w = Math.max(w, root.textWidth(s, bold, unit));
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
