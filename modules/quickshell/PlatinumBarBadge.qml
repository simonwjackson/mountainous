import Quickshell
import Hensou as Kit
import QtQuick

// The dot on a bar icon's top right corner: notifications are waiting on
// the bell, builds are running on the hammer. A ring in the colour behind
// the icon cuts it free of the glyph under it.
Rectangle {
    property color fill: Kit.PlatinumTokens.barText
    property color knock: Kit.PlatinumTokens.barSurface

    x: 11
    y: -1
    width: 7
    height: 7
    radius: 3.5
    color: fill
    border.width: Kit.PlatinumTokens.hairFor(QsWindow.window)
    border.color: knock
}
