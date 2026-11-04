import Quickshell
import QtQuick
import QtQuick.Window

// A per-window icon, with the existing app icon while metadata is missing,
// ambiguous or fails to load. Application-group icons leave toplevel null.
Image {
    id: root
    property var toplevel: null
    property string fallbackSource: ""
    property real implicitSize: 16
    readonly property string favicon: root.toplevel ? CdpBrowser.faviconFor(root.toplevel) : ""
    property string failedSource: ""

    width: implicitSize
    height: implicitSize
    sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
    sourceSize.height: Math.ceil(height * Screen.devicePixelRatio)
    fillMode: Image.PreserveAspectFit
    source: root.favicon !== "" && root.favicon !== root.failedSource ? root.favicon : root.fallbackSource
    onStatusChanged: {
        if (status === Image.Error && root.favicon !== "" && source.toString() === root.favicon)
            root.failedSource = root.favicon;
    }
}
