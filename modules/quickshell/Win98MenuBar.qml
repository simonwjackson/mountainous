pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

// A menu bar inside a window: 18 u tall, each title 6 u in from its
// neighbours with its access letter underlined. The pointer on a title
// draws a thin raised edge; the open title is sunken. A press opens or
// closes that title's menu (the window draws the menu; opened reports
// where it hangs, in this bar's coordinates); while one is open, the
// pointer moving to another title opens that one, as Win98 did.
//
// menus: [{ id, text }] ("&View"); openId: the title whose menu is open.
Item {
    id: root

    property var menus: []
    property string openId: ""
    signal opened(string id, real x, real w)
    signal closed

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    implicitHeight: 18 * u
    implicitWidth: titles.width

    // Each title's place, for the window that hangs its menu.
    function placeOf(id) {
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i);
            if (it && it.objectName === "menu-" + id) return { x: it.x, w: it.width };
        }
        return null;
    }

    Row {
        id: titles
        height: root.height
        Repeater {
            id: repeater
            model: root.menus
            Item {
                id: title
                required property var modelData
                readonly property string mid: modelData.id
                readonly property bool open: root.openId === mid
                objectName: "menu-" + mid
                width: label.implicitWidth + 12 * root.u
                height: 16 * root.u
                y: root.u
                Win98Bevel {
                    anchors.fill: parent
                    filled: false
                    visible: title.open || area.containsMouse
                    variant: title.open ? "thinSunken" : "thinRaised"
                }
                Win98Text {
                    id: label
                    x: 6 * root.u + (title.open ? root.u : 0)
                    y: root.u + (title.open ? root.u : 0)
                    text: title.modelData.text
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: if (root.openId !== "" && !title.open) root.opened(title.mid, title.x, title.width)
                    onPressed: {
                        if (title.open) root.closed();
                        else root.opened(title.mid, title.x, title.width);
                    }
                }
            }
        }
    }
}
