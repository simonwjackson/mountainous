import QtQuick

// A number on the bar, in a box as wide as its widest value ("100",
// "99+", "100%"). ChicagoFLF's digits differ in width, so without the box
// the bar would move each time a value changed.
Text {
    id: root

    // Every string the box must hold; the widest sets the width.
    property var widest: ["100"]
    property color tone: PlatinumTokens.barText

    width: PlatinumMetrics.widest(widest)
    horizontalAlignment: Text.AlignLeft
    textFormat: Text.PlainText
    color: tone
    font.family: PlatinumTokens.platinumFont
    font.pixelSize: PlatinumTokens.platinumText
    font.letterSpacing: PlatinumTokens.platinumTracking
}
