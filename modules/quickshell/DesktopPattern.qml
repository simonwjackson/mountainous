import Quickshell
import Quickshell.Wayland
import QtQuick
import "desktop-art.js" as Art

// The desktop itself: one background-layer surface per screen, under every
// window, the bars and the glance space, tiled with the current theme's
// pattern for the current appearance (themes.json "art.patterns"). It is
// shared, not part of a Desktop, so a theme swap repaints it in place
// instead of mapping a second full-screen surface.
//
// A tile is an 8 x 8 SVG drawn at whole device pixels per tile pixel and
// shown unfiltered, tiles starting at the screen's origin, so its cells
// share the glance dither's grid (3 device px at 1.5 for Platinum).
PanelWindow {
    id: root

    readonly property var entry: ThemeCatalog.find(Theme.name)
    readonly property string file: Art.pattern(entry, Theme.mode, Theme.extraDark)
    readonly property int baseCell: entry && entry.art ? entry.art.patternCell : 2

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "mountainous-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "#000000"
    // Nothing on the desktop takes input.
    mask: Region {}

    Image {
        id: tiles
        objectName: "desktopPattern"
        readonly property real dpr: QsWindow.window && QsWindow.window.devicePixelRatio > 0
            ? QsWindow.window.devicePixelRatio : 1.5
        readonly property var tile: Art.tile(root.baseCell, dpr)

        anchors.fill: parent
        source: root.file === "" ? "" : Quickshell.shellPath(root.file)
        sourceSize.width: tile.logical
        sourceSize.height: tile.logical
        fillMode: Image.Tile
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
        smooth: false
        mipmap: false
        asynchronous: false
    }
}
