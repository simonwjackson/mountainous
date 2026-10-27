pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "themes/win98/session-model.js" as Session

// The volume and brightness pop-up: a small raised box above the tray
// icon (above » when the icon moved there, above Start when only Start is
// left), with the icon, the word, the value, and Win98's block progress
// bar (Win98LevelBar's blocks, in the selection colour). It shows for
// 1.5 s after a change and takes no input; the Desktop decides when (its
// arming rules are Platinum's tag rules). On a surface of its own that
// covers the screen, so the box lands on whole physical pixels, as the
// tooltip does.
Scope {
    id: host

    required property var desktop
    required property var taskbar

    readonly property string kind: desktop.popupId
    readonly property bool shown: desktop.active && desktop.shell.chromeVisible && kind !== "" && desktop.openId === ""

    // The open box, for checks.
    property var box: null

    LazyLoader {
        active: host.shown

        PanelWindow {
            id: win
            readonly property real u: Win98Tokens.unitFor(win)
            readonly property var place: host.taskbar.placeOf(host.kind)
                || host.taskbar.placeOf("more") || host.taskbar.placeOf("start")
            readonly property var plan: Session.popupPlan(Math.floor(win.width / win.u),
                place ? place.x / win.u : win.width / win.u, place ? place.w / win.u : 0)
            readonly property bool vol: host.kind === "vol"
            readonly property var words: Session.popupText(host.kind, vol ? host.desktop.volLevel : host.desktop.briLevel,
                vol && host.desktop.volMuted)
            screen: host.desktop.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "mountainous-popup"
            color: "transparent"
            mask: Region {}

            Component.onCompleted: host.box = box
            Component.onDestruction: if (host.box === box) host.box = null

            Item {
                id: box
                objectName: "volumePopup"
                x: win.plan.x * win.u
                y: win.height - host.taskbar.barHeight - 2 * win.u - height
                width: win.plan.width * win.u
                height: 40 * win.u
                Win98Bevel { anchors.fill: parent; variant: "window" }
                Win98Icon {
                    id: icon
                    x: 6 * win.u; y: 5 * win.u
                    name: win.vol ? host.desktop.trayIcon("vol") : "brightness"
                }
                Win98Text {
                    visible: win.plan.label
                    x: icon.x + 16 * win.u + 6 * win.u
                    y: icon.y + Win98Tokens.snap((16 * win.u - height) / 2, win.u)
                    text: win.words.label
                    accessMarks: false
                }
                Win98Text {
                    objectName: "volumePopupValue"
                    x: box.width - 6 * win.u - width
                    y: icon.y + Win98Tokens.snap((16 * win.u - height) / 2, win.u)
                    text: win.words.value
                    accessMarks: false
                }
                Win98LevelBar {
                    objectName: "volumePopupBar"
                    x: 6 * win.u
                    y: 26 * win.u
                    width: box.width - 12 * win.u
                    height: 10 * win.u
                    blocks: true
                    value: (win.vol ? host.desktop.volLevel : host.desktop.briLevel) / 100
                    stale: win.vol && host.desktop.volMuted
                }
            }
        }
    }
}
