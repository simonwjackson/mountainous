import QtQuick
import Quickshell
import Hensou as Kit
import "hensou-host.js" as HensouHost
import "app-icon.js" as AppIcon

// Flat host adapter: shared drawing, actual QsWindow scale, shell icon lookup.
Kit.Win98Icon {
    readonly property real hensouDevicePixelRatio: HensouHost.devicePixelRatio(QsWindow.window)
    readonly property var hensouIconResolver: (name, checkOnly) => HensouHost.iconSource(name, checkOnly, Quickshell, AppIcon)
}
