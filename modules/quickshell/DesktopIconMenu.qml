import Hensou as Kit
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "desktop-icons-model.js" as Model

// A desktop context menu at the pointer, drawn with the theme's own menu:
// PlatinumCascadeMenu (Platinum) or MemphisMenu (Memphis). An overlay window
// over the whole screen, so the menu shows above windows as a period menu
// did; a click outside, or Escape, closes it. rows: desktop-icons-model
// rows; chosen(row) runs the action.
PanelWindow {
    id: win

    required property var modelData
    property string themeId: "platinum"
    property var rows: []
    // Where the menu opens, in this screen's logical px.
    property real atX: 0
    property real atY: 0
    signal chosen(var row)
    signal dismissed

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    // The keyboard at once (a menu's arrows, an alert's Enter and Escape),
    // under any compositor; HyprlandFocusGrab ends it on an outside click.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "mountainous-desktop-menu"

    readonly property bool memphis: win.themeId === "memphis"
    property bool alive: true
    function close() { if (!win.alive) return; win.alive = false; win.dismissed(); }
    function choose(row) { if (!win.alive) return; win.alive = false; win.chosen(row); }

    HyprlandFocusGrab {
        active: win.alive
        windows: [win]
        onCleared: win.close()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: win.close()
    }

    Item {
        id: menuBounds
        anchors.fill: parent
    }

    // The menu's top left: at the pointer, moved in to stay on screen.
    // PlatinumCascadeMenu reads its parent's place in the window.
    Loader {
        id: loader
        readonly property real w: item ? item.width : 0
        readonly property real h: item ? item.height : 0
        x: Math.max(2, Math.min(win.atX, win.width - w - 2))
        y: Math.max(2, Math.min(win.atY, win.height - h - 2))
        focus: true
        sourceComponent: win.memphis ? memphisMenu : platinumMenu
        onLoaded: loader.forceActiveFocus()
    }

    Component {
        id: platinumMenu
        PlatinumCascadeMenu {
            items: Model.platinumRows(win.rows)
            menuWidth: 360
            maxHeight: win.height - 16
            onActivated: function (row) { if (row && row.action) win.choose(row.action.row); }
            onCloseRequested: win.close()
        }
    }
    Component {
        id: memphisMenu
        MemphisMenu {
            animate: false
            bounds: menuBounds
            model: Model.memphisItems(win.rows)
            onTriggered: function (item) { if (item && item.row) win.choose(item.row); }
            onClosed: win.close()
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: !win.memphis
        onActivated: {
            const item = loader.item;
            if (item && item.cancel && item.cancel()) return;
            win.close();
        }
    }
}
