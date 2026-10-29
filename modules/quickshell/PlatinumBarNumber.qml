import Hensou as Kit
import QtQuick

// A number on the bar, in a fixed box. ChicagoFLF's digits differ in
// width, so without the box the bar would move each time a value changed.
// By default the box is as wide as the widest of `widest` ("100", "99+",
// "100%"). With byDigits it holds the number as it stands, each digit at
// the widest digit's width (Kit.PlatinumMetrics.digitBox): "1 issue" has no
// empty box for a second digit, and 3 to 7 still never moves.
Text {
    id: root

    // Every string the box must hold; the widest sets the width.
    property var widest: ["100"]
    property bool byDigits: false
    property color tone: Kit.PlatinumTokens.barText

    width: byDigits ? Kit.PlatinumMetrics.digitBox(text) : Kit.PlatinumMetrics.widest(widest)
    horizontalAlignment: Text.AlignLeft
    textFormat: Text.PlainText
    color: tone
    font.family: Kit.PlatinumTokens.platinumFont
    font.pixelSize: Kit.PlatinumTokens.platinumText
    font.letterSpacing: Kit.PlatinumTokens.platinumTracking
}
