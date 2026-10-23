pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

// The taskbar's tooltip, on a surface that takes no input. The surface
// covers the screen, so the tip lands on whole physical pixels however the
// scale rounds a small surface's size. It stands over its control, 3 u
// above the bar, kept 2 u inside the screen.
Scope {
    id: host

    required property var desktop
    required property var taskbar

    readonly property real u: Win98Tokens.u
    readonly property var preview: desktop.preview || ({})
    readonly property string tipId: preview.tip !== undefined ? preview.tip : desktop.tipId
    readonly property bool shown: desktop.active && desktop.shell.chromeVisible && tipId !== "" && desktop.openId === ""
    readonly property string text: shown ? desktop.tooltip(tipId) : ""

    LazyLoader {
        active: host.shown && host.text !== ""

        PanelWindow {
            id: win
            screen: host.desktop.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "mountainous-tooltip"
            color: "transparent"
            mask: Region {}
            readonly property var place: host.taskbar.placeOf(host.tipId)
            Win98ToolTip {
                id: tip
                text: host.text
                x: {
                    const x = win.place ? win.place.x : win.width;
                    return Math.max(2 * host.u, Math.min(x, win.width - width - 2 * host.u));
                }
                y: win.height - host.taskbar.barHeight - 3 * host.u - height
            }
        }
    }
}
