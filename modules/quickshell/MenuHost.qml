import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

// The one menu window of a screen. MenuState says which menu is open and
// where; this window shows that menu hanging from its control.
//
// The window covers the screen except the bar: its input mask leaves the
// bar out, so the pointer still reaches the bar's controls while a menu
// is open. That is what lets a menu follow the pointer from title to
// title (sticky menus), and what lets a click on the open title close it.
// The focus grab lists the bar too, for the same reason. A click
// anywhere else, or Escape, closes the menu.
Scope {
    id: host

    required property var screen
    // The screen's TopBar window.
    required property var bar
    // Menu name -> Component. Each component's root is a MenuFrame.
    required property var menus

    readonly property string current: MenuState.current
    readonly property bool active: current !== "" && MenuState.screen === host.screen
        && host.menus[current] !== undefined && host.menus[current] !== null

    LazyLoader {
        active: host.active

        PanelWindow {
            id: win

            screen: host.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            color: "transparent"
            WlrLayershell.namespace: "mountainous-menu"

            // Input everywhere but the bar.
            mask: Region {
                x: 0
                y: Theme.barHeight
                width: win.width
                height: Math.max(0, win.height - Theme.barHeight)
            }

            // A window outlives its menu for a moment (LazyLoader deletes it
            // later). Once its menu closes it must never grab again, or a
            // menu opened right after (close, then open) would see this old
            // grab fail and close at once.
            property bool alive: true
            Connections {
                target: host
                function onActiveChanged() { if (!host.active) win.alive = false; }
            }

            HyprlandFocusGrab {
                active: win.alive && host.active
                windows: [ win, host.bar ]
                onCleared: if (win.alive && host.active) MenuState.close()
            }

            MouseArea {
                anchors.fill: parent
                onPressed: MenuState.close()
            }

            // The control's place on the bar, kept live: if the bar's
            // layout moves while the menu is open, the menu moves with it.
            // MenuState.anchorX is the fallback for a menu the bar does not
            // show.
            readonly property real anchorX: {
                const live = host.bar.anchorFor(host.current);
                if (live >= 0) return live;
                const given = MenuState.anchorX;
                return given !== undefined && given !== null ? given : -1;
            }

            Loader {
                id: loader
                focus: true
                sourceComponent: host.active ? host.menus[host.current] : null
                // The menu's top edge lies on the bar's rule, as in Mac OS.
                y: Theme.barHeight - Theme.hair
                x: {
                    const w = item ? item.width : 0;
                    const edge = 4;
                    const wanted = win.anchorX >= 0 ? win.anchorX : win.width - w - edge;
                    return Math.max(edge, Math.min(wanted, win.width - w - edge));
                }

                onLoaded: {
                    const menu = item;
                    menu.maxHeight = Qt.binding(function () { return win.height - loader.y - 12; });
                    menu.menuWidth = Qt.binding(function () {
                        return Math.min(menu.preferredWidth || 360, win.width - 8);
                    });
                    menu.closeRequested.connect(function () { MenuState.close(); });
                    loader.forceActiveFocus();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                onActivated: {
                    const item = loader.item;
                    if (item && item.cancel && item.cancel()) return;
                    MenuState.close();
                }
            }
        }
    }
}
