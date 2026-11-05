pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import QtQuick

// A Memphis scheme drawn small, in that scheme's own palette
// (MemphisTokens.palette(id)): an inactive window, an active window with a
// menu bar (normal, disabled, selected), its text and scroll bar, a message
// box, and the taskbar's edge, over the scheme's desktop. Display Properties shows
// it for the scheme in the draft, which need not be the one on screen.
Item {
    id: root

    property var scheme: Kit.MemphisTokens.current

    readonly property real u: Kit.MemphisTokens.unitFor(QsWindow.window)
    readonly property var p: scheme

    MemphisWindow {
        x: 10 * root.u; y: 6 * root.u
        width: 220 * root.u; height: 70 * root.u
        title: "Inactive Window"; active: false
        scheme: root.p
    }
    MemphisWindow {
        x: 20 * root.u; y: 26 * root.u
        width: 240 * root.u; height: 102 * root.u
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
                        width: Kit.MemphisTokens.ceilU(Kit.MemphisTokens.textWidth(modelData, false, root.u), root.u) + 12 * root.u
                        height: 17 * root.u
                        color: modelData === "Selected" ? root.p.selection : "transparent"
                        MemphisText {
                            x: 6 * root.u; y: 2 * root.u
                            text: word.modelData; accessMarks: false
                            scheme: root.p
                            disabledLook: word.modelData === "Disabled"
                            color: word.modelData === "Selected" ? root.p.selectionText : root.p.menuText
                        }
                    }
                }
            }
            MemphisBevel {
                id: field
                width: 234 * root.u; height: 46 * root.u
                variant: "field"; scheme: root.p; color: root.p.win
                MemphisText { x: 5 * root.u; y: 3 * root.u; text: "Window Text"; accessMarks: false; color: root.p.winText; scheme: root.p }
                // The scheme's scroll bar: its arrows, and its track drawn
                // as Memphis drew it (solid, or the face and light dither).
                Item {
                    x: field.width - 2 * root.u - width; y: 2 * root.u
                    width: 16 * root.u; height: field.height - 4 * root.u
                    Rectangle { anchors.fill: parent; color: root.p.scrollDither ? root.p.face : root.p.scrollTrack }
                    MemphisDither { visible: root.p.scrollDither; anchors.fill: parent; color: root.p.dither }
                    Repeater {
                        model: ["arrow-up", "arrow-down"]
                        MemphisBevel {
                            id: arrow
                            required property string modelData
                            required property int index
                            y: index === 0 ? 0 : parent.height - height
                            width: 16 * root.u; height: 16 * root.u
                            scheme: root.p
                            MemphisIcon {
                                name: arrow.modelData
                                color: root.p.text
                                x: Kit.MemphisTokens.snap((arrow.width - width) / 2, root.u)
                                y: Kit.MemphisTokens.snap((arrow.height - height) / 2, root.u)
                            }
                        }
                    }
                }
            }
        }
    }
    // The taskbar's edge, with the Start button.
    Rectangle {
        x: 0; y: root.height - 12 * root.u
        width: root.width; height: 12 * root.u
        color: root.p.face
        Rectangle { width: parent.width; height: root.u; color: root.p.hi }
        MemphisBevel { x: 2 * root.u; y: 2 * root.u; width: 26 * root.u; height: 9 * root.u; scheme: root.p }
    }
    // The message box sits low and left of the active window's scroll
    // bar, so the bar shows, as in Memphis's own preview.
    MemphisWindow {
        x: 70 * root.u; y: 88 * root.u
        width: 150 * root.u; height: 62 * root.u
        title: "Message Box"; margins: false
        scheme: root.p
        Column {
            width: 144 * root.u
            Item {
                width: 144 * root.u; height: 19 * root.u
                MemphisText { x: 6 * root.u; y: 3 * root.u; text: "Message Text"; accessMarks: false; color: root.p.text; scheme: root.p }
            }
            MemphisButton {
                x: Kit.MemphisTokens.snap((144 * root.u - width) / 2, root.u)
                widthUnits: 50; small: true; height: 18 * root.u
                text: "OK"
                scheme: root.p
            }
        }
    }
}
