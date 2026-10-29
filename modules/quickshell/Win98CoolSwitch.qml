pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "themes/win98/task-model.js" as TaskModel
import "themes/win98/start-model.js" as StartModel
import "app-icon.js" as AppIcon

// Held Super+Tab: Win98's Alt+Tab "Cool Switch" box over the windows. A
// raised grey box in the middle of the screen above the taskbar, each
// window's 32-u icon in a 43-u cell (up to 7 a row), a frame on the window
// the release will choose, and its title in a sunken box below; a
// minimized window says so. Rows past the room scroll to keep the choice in
// view, with "N more rows above/below" (task-model.js coolPlan). The
// Desktop's cycle() drives it from the chrome cycle messages; it takes no
// input and appears at once.
Scope {
    id: host

    required property var desktop
    required property var taskbar

    readonly property bool shown: desktop.active && desktop.shell.chromeVisible && desktop.cycleState !== null
    // The cycle's windows, in its order: { address, title, icon, appId, minimized }.
    readonly property var items: {
        const c = desktop.cycleState;
        if (!c) return [];
        return c.order.map(function (k) {
            const r = desktop.rowFor(k);
            const t = r ? r.toplevel : null;
            const appId = r ? r.appId : "";
            return { address: k, title: r ? (r.title || "(untitled)") : "", appId: appId,
                icon: StartModel.appIcon(appId, ""), minimized: !!(r && desktop.hider && desktop.hider.isHidden(r)) };
        });
    }
    readonly property int current: {
        const c = desktop.cycleState;
        if (!c || !c.order.length) return -1;
        return c.order.indexOf(desktop.cycleTarget);
    }

    // The open box, for checks.
    property var box: null

    LazyLoader {
        active: host.shown && host.items.length > 0

        PanelWindow {
            id: win
            readonly property real u: Kit.Win98Tokens.unitFor(win)
            readonly property real area: win.height - host.taskbar.barHeight
            readonly property var plan: TaskModel.coolPlan(host.items.length, host.current,
                Math.floor(win.width / win.u), Math.floor(win.area / win.u))
            screen: host.desktop.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "mountainous-coolswitch"
            color: "transparent"
            mask: Region {}

            Component.onCompleted: host.box = box
            Component.onDestruction: if (host.box === box) host.box = null

            Item {
                id: box
                objectName: "coolSwitch"
                width: win.plan.width * win.u
                height: win.plan.height * win.u
                x: Kit.Win98Tokens.half((win.width - width) / 2, win.u)
                y: Math.max(2 * win.u, Kit.Win98Tokens.snap((win.area - height) / 2, win.u))

                Win98Bevel { anchors.fill: parent; variant: "window" }

                Grid {
                    id: grid
                    x: 8 * win.u
                    y: 8 * win.u
                    columns: win.plan.cols
                    Repeater {
                        model: host.items.slice(win.plan.first * win.plan.cols, (win.plan.first + win.plan.shown) * win.plan.cols)
                        Item {
                            id: cell
                            required property var modelData
                            required property int index
                            readonly property bool on: win.plan.first * win.plan.cols + index === host.current
                            width: 43 * win.u
                            height: 43 * win.u
                            // The choice: a 2-u frame in the text colour, as Win98 drew it.
                            Rectangle {
                                visible: cell.on
                                x: 2 * win.u; y: 2 * win.u
                                width: 39 * win.u; height: 39 * win.u
                                color: "transparent"
                                border.width: 2 * win.u
                                border.color: Kit.Win98Tokens.text
                            }
                            Win98Icon {
                                visible: cell.modelData.icon !== ""
                                name: cell.modelData.icon
                                size: 32
                                x: Kit.Win98Tokens.snap((cell.width - width) / 2, win.u)
                                y: Kit.Win98Tokens.snap((cell.height - height) / 2, win.u)
                            }
                            IconImage {
                                visible: cell.modelData.icon === ""
                                implicitSize: 32 * win.u
                                x: Kit.Win98Tokens.snap((cell.width - width) / 2, win.u)
                                y: Kit.Win98Tokens.snap((cell.height - height) / 2, win.u)
                                source: {
                                    if (cell.modelData.icon !== "" || cell.modelData.appId === "") return "";
                                    const e = DesktopEntries.heuristicLookup(cell.modelData.appId);
                                    const name = AppIcon.themeName(cell.modelData.appId, e && e.icon ? e.icon : "");
                                    return Quickshell.iconPath(name, AppIcon.fallback(name));
                                }
                            }
                        }
                    }
                }
                Win98Text {
                    objectName: "coolSwitchMore"
                    visible: win.plan.rows > win.plan.shown
                    x: 8 * win.u
                    y: grid.y + win.plan.shown * 43 * win.u + 6 * win.u
                    width: box.width - 16 * win.u
                    text: TaskModel.moreText(win.plan.above, win.plan.below)
                    accessMarks: false
                    color: Kit.Win98Tokens.gray
                }
                Item {
                    x: 8 * win.u
                    y: box.height - 8 * win.u - 20 * win.u
                    width: box.width - 16 * win.u
                    height: 20 * win.u
                    Win98Bevel { anchors.fill: parent; variant: "thinSunken"; filled: false }
                    Win98Text {
                        objectName: "coolSwitchTitle"
                        readonly property var it: host.items[host.current] || null
                        x: Kit.Win98Tokens.half(Math.max(4 * win.u, (parent.width - width) / 2), win.u)
                        y: Kit.Win98Tokens.snap((parent.height - height) / 2, win.u)
                        width: Math.min(implicitWidth, parent.width - 8 * win.u)
                        text: it ? it.title + (it.minimized ? " (minimized)" : "") : ""
                        accessMarks: false
                    }
                }
            }
        }
    }
}
