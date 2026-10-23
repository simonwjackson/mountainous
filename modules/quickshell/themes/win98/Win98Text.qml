pragma ComponentBehavior: Bound

import QtQuick

// Text on the Win98 grid, in W95FA Grid.
//
// Qt rounds a font's size to whole logical pixels, and 12.5 u is 16.67 px
// at scale 1.5, so the font would land between physical pixels. Instead
// the text draws at 25 px, where one font pixel is two text pixels, and is
// scaled by u / 2: one font pixel is then exactly 1 u, two physical pixels,
// and every edge is a whole pixel (no blended colours). Place the item on
// whole or half units.
//
// Bold is drawn, as Win98's bold bitmaps were: a second strike 1 u to the
// right and 1 u more advance per letter. size 2 doubles everything (the
// Start menu's side band).
//
// An "&" marks the access key ("&Programs"); "&&" is a literal "&". The
// marked letter is underlined while showAccess is true. Write three dots,
// never "…" from another face; elision uses W95FA Grid's own U+2026, which
// it draws as three one-pixel dots.
Item {
    id: root

    property string text: ""
    property color color: Win98Tokens.text
    property bool bold: false
    property int size: 1
    property bool showAccess: true
    // false: "&" is literal text (data such as names and titles).
    property bool accessMarks: true
    // Disabled text: grey, with a 1-u emboss in light.
    property bool disabledLook: false
    property bool wrap: false
    property int maximumLineCount: 1000
    property int elide: Text.ElideRight
    property int horizontalAlignment: Text.AlignLeft
    // Line pitch of wrapped text, in units (13 = the font's own line).
    property int lineUnits: Win98Tokens.lineUnits

    readonly property real u: Win98Tokens.u
    readonly property real k: Win98Tokens.textScale
    readonly property string plain: accessMarks ? Win98Tokens.plainText(text) : text
    readonly property int accessIndex: accessMarks ? Win98Tokens.accessIndex(text) : -1
    readonly property color shownColor: disabledLook ? Win98Tokens.gray : color
    readonly property bool truncated: main.truncated

    implicitWidth: main.implicitWidth * k * size
    implicitHeight: (wrap ? main.implicitHeight : Win98Tokens.lineUnits * 2) * k * size

    // size 2 draws the size-1 text into a layer and doubles it without
    // filtering: Qt's glyph cache blends a 50 px W95FA at this scale, a
    // doubled 25 px one is exact.
    Item {
        id: canvas
        width: root.width / root.size
        height: root.height / root.size
        transformOrigin: Item.TopLeft
        scale: root.size
        layer.enabled: root.size !== 1
        layer.smooth: false

        component Face: Text {
            // Left-aligned text gets one text pixel of slack, so a string
            // exactly as wide as the item does not elide on rounding.
            // Centred or right-aligned text gets none: a half text pixel
            // would put it between physical pixels. Right-align by placing
            // the item instead.
            width: canvas.width / root.k + (root.horizontalAlignment === Text.AlignLeft ? 1 : 0)
            transformOrigin: Item.TopLeft
            scale: root.k
            text: root.plain
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            wrapMode: root.wrap ? Text.WordWrap : Text.NoWrap
            maximumLineCount: root.maximumLineCount
            elide: root.elide
            horizontalAlignment: root.horizontalAlignment
            lineHeightMode: Text.FixedHeight
            lineHeight: root.lineUnits * 2
            font.family: Win98Tokens.fontFamily
            font.pixelSize: Win98Tokens.fontRaster
            font.hintingPreference: Font.PreferNoHinting
            font.kerning: false
            font.letterSpacing: root.bold ? 2 : 0
        }

        Face {
            visible: root.disabledLook && Win98Tokens.emboss.a > 0
            x: root.u
            y: root.u
            color: Win98Tokens.emboss
        }
        Face {
            id: main
            color: root.shownColor
        }
        Face {
            visible: root.bold
            x: root.u
            color: root.shownColor
        }

        // The access key's underline: 1 u below the baseline, under one
        // letter. A disabled label draws the underline's emboss too.
        Repeater {
            model: root.showAccess && root.accessIndex >= 0 && !root.wrap ? (root.disabledLook && Win98Tokens.emboss.a > 0 ? 2 : 1) : 0

            Rectangle {
                required property int index
                z: index === 1 ? -1 : 0
                x: Win98Tokens.textWidth(root.plain.slice(0, root.accessIndex), root.bold) + (index === 1 ? root.u : 0)
                y: (Win98Tokens.ascentUnits + 1) * root.u + (index === 1 ? root.u : 0)
                width: Win98Tokens.textWidth(root.plain.charAt(root.accessIndex), false) - root.u
                height: root.u
                color: index === 1 ? Win98Tokens.emboss : root.shownColor
            }
        }
    }
}
