pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

// A Win98 scheme drawn small, in that scheme's own palette: an inactive
// window, an active window with a menu bar (normal, disabled, selected) and
// its text, a message box, and the taskbar's edge. Display Properties shows
// it for the scheme in the draft, which need not be the one on screen.
Item {
    id: root

    property var scheme: Win98Tokens.current

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    readonly property var p: scheme

    Win98Window {
        x: 10 * root.u; y: 6 * root.u
        width: 220 * root.u; height: 70 * root.u
        title: "Inactive Window"; active: false
        scheme: root.p
    }
    Win98Window {
        x: 20 * root.u; y: 26 * root.u
        width: 240 * root.u; height: 90 * root.u
        title: "Active Window"; margins: false
        scheme: root.p
        Column {
            width: 234 * root.u
            // The menu bar: each word 6 u in from its box.
            Row {
                height: 17 * root.u
                Repeater {
                    model: ["Normal", "Disabled", "Selected"]
                    Rectangle {
                        id: word
                        required property string modelData
                        width: Win98Tokens.ceilU(Win98Tokens.textWidth(modelData, false, root.u), root.u) + 12 * root.u
                        height: 17 * root.u
                        color: modelData === "Selected" ? root.p.selection : "transparent"
                        Win98Text {
                            x: 6 * root.u; y: 2 * root.u
                            text: word.modelData; accessMarks: false
                            scheme: root.p
                            disabledLook: word.modelData === "Disabled"
                            color: word.modelData === "Selected" ? root.p.selectionText : root.p.text
                        }
                    }
                }
            }
            Win98Bevel {
                width: 234 * root.u; height: 34 * root.u
                variant: "field"; scheme: root.p; color: root.p.win
                Win98Text { x: 5 * root.u; y: 3 * root.u; text: "Window Text"; accessMarks: false; color: root.p.winText }
            }
        }
    }
    // The taskbar's edge, with the Start button.
    Rectangle {
        x: 0; y: root.height - 12 * root.u
        width: root.width; height: 12 * root.u
        color: root.p.face
        Rectangle { width: parent.width; height: root.u; color: root.p.hi }
        Win98Bevel { x: 2 * root.u; y: 2 * root.u; width: 26 * root.u; height: 9 * root.u; scheme: root.p }
    }
    Win98Window {
        x: 140 * root.u; y: 64 * root.u
        width: 150 * root.u; height: 62 * root.u
        title: "Message Box"; margins: false
        scheme: root.p
        Column {
            width: 144 * root.u
            Item {
                width: 144 * root.u; height: 19 * root.u
                Win98Text { x: 6 * root.u; y: 3 * root.u; text: "Message Text"; accessMarks: false; color: root.p.text }
            }
            Win98Button {
                x: Win98Tokens.snap((144 * root.u - width) / 2, root.u)
                widthUnits: 50; small: true; height: 18 * root.u
                text: "OK"
                scheme: root.p
            }
        }
    }
}
