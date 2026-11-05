import Quickshell
import Quickshell.Wayland
import QtQuick
import Hensou as Kit
import "desktop-art.js" as Art

// The desktop itself: one background-layer surface per screen, under every
// window, the bars and the glance space, using a solid colour or the
// pattern for the current appearance (themes.json "art.patterns"). It is
// shared, not part of a Desktop, so a theme swap repaints it in place
// instead of mapping a second full-screen surface.
//
// On the primary screen (desktopIcons) it also carries the desktop icons
// (DesktopIcons.qml): the surface then takes clicks where it shows, which
// is only where no window covers it, since it lies on the Background layer
// under every window, and takes the keyboard on demand (a click on it),
// for arrow keys and rename. Its input mask is the icon layer while the
// provider is live, and empty otherwise.
//
// A tile is an 8 x 8 SVG drawn at whole device pixels per tile pixel and
// shown unfiltered, tiles starting at the screen's origin, so its cells
// share the glance dither's grid (3 device px at 1.5 for Platinum).
PanelWindow {
    id: root

    readonly property var entry: ThemeCatalog.find(Theme.name)
    readonly property string file: Art.pattern(entry, Theme.mode, Theme.extraDark, Theme.appearance)
    readonly property var desktopPalette: entry && entry.id === "memphis" ? Kit.MemphisTokens.palette(Theme.appearance) : null
    readonly property int baseCell: entry && entry.art ? entry.art.patternCell : 2

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "mountainous-desktop"
    WlrLayershell.keyboardFocus: root.desktopIcons ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: Art.background(entry, Theme.mode, Theme.extraDark, Theme.appearance, desktopPalette)
    // The primary screen's pattern carries the desktop icons.
    property bool desktopIcons: false
    readonly property var iconLayer: icons.item
    mask: Region { item: icons.item && icons.item.takesInput ? icons : null }


    Image {
        id: tiles
        objectName: "desktopPattern"
        readonly property real dpr: QsWindow.window && QsWindow.window.devicePixelRatio > 0
            ? QsWindow.window.devicePixelRatio : 1.5
        readonly property var tile: Art.tile(root.baseCell, dpr)

        anchors.fill: parent
        visible: root.file !== ""
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

    Loader {
        id: icons
        anchors.fill: parent
        active: root.desktopIcons
        focus: true
        sourceComponent: DesktopIcons {
            screen: root.screen
            window: root
            focus: true
        }
    }
}
