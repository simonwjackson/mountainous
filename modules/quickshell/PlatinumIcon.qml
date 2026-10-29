import QtQuick
import Quickshell
import Hensou as Kit
import "app-icon.js" as AppIcon

// Flat host adapter: shared drawing, actual QsWindow scale, shell icon lookup.
Kit.PlatinumIcon {
    // QsWindow.window is declared QObject in the plugin metadata. Its runtime
    // window exposes DPR; retain that dynamic host seam without using Screen.
    readonly property var hensouWindow: QsWindow.window
    readonly property real hensouDevicePixelRatio: hensouWindow && hensouWindow.devicePixelRatio > 0
        ? hensouWindow.devicePixelRatio : 1.5
    readonly property var hensouIconResolver: name => Quickshell.iconPath(name, AppIcon.fallback(name))
}
