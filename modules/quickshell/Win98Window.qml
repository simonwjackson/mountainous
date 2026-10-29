import QtQuick
import Quickshell
import Hensou as Kit
import "app-icon.js" as AppIcon

// Flat host adapter: shared drawing, actual QsWindow scale, shell icon lookup.
Kit.Win98Window {
    readonly property real hensouDevicePixelRatio: QsWindow.window && QsWindow.window.devicePixelRatio > 0
        ? QsWindow.window.devicePixelRatio : 1.5
    readonly property var hensouIconResolver: name => Quickshell.iconPath(name, AppIcon.fallback(name))
}
