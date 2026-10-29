pragma ComponentBehavior: Bound

import Hensou as Kit
import QtQuick
import "themes/win98/session-model.js" as Session

// Start > Settings > System...: Win98's System Properties, the General tab
// only (inert tabs were rejected in phase 1). The picture, then the facts
// Platinum's About shows (SystemFacts, one reader for both themes): the
// NixOS version, generation and revision, who it is registered to, the
// host and its DMI product name, and how long it has run. Narrow, the
// picture goes above the facts, then goes; short, the window scrolls with
// its caption kept (Win98Window), and the focused button scrolls into view.
// OK, Cancel, Esc and the close box close it.
Win98Window {
    id: root

    required property var desktop

    objectName: "systemProperties"
    title: "System Properties"
    showHelp: true
    margins: false
    focus: true
    onCloseClicked: MenuState.close()

    SystemFacts { id: facts; live: root.visible }
    // The host sets the width (420 u at most); the plan reads it back.
    readonly property var plan: Session.sysPlan(Math.floor(root.width / root.u + 1e-6) + 4)
    readonly property var groups: Session.sysFacts({ host: facts.host, product: facts.product, version: facts.version,
        generation: facts.generation, uptime: facts.uptime, user: root.desktop.userName })

    Item {
        id: body
        x: 8 * root.u
        width: root.bodyWidth - 16 * root.u
        implicitHeight: 8 * root.u + tabs.height + 8 * root.u + Kit.Win98Tokens.buttonHeight * root.u + 8 * root.u

        Win98Tabs {
            id: tabs
            y: 8 * root.u
            width: body.width
            height: tabs.strip - 2 * root.u + sheet.implicitHeight + 24 * root.u
            tabs: ["General"]
            currentIndex: 0
            padUnits: 0
            // One tab: one row (and no binding loop through the wrap).
            singleRow: true

            Item {
                id: sheet
                x: 12 * root.u
                y: 12 * root.u
                width: tabs.width - 24 * root.u
                implicitHeight: root.plan.stack
                    ? (root.plan.picture ? picture.height + 8 * root.u : 0) + factList.implicitHeight
                    : Math.max(root.plan.picture ? picture.height : 0, factList.implicitHeight)

                Win98Icon {
                    id: picture
                    visible: root.plan.picture
                    x: root.plan.stack ? Kit.Win98Tokens.half((sheet.width - width) / 2, root.u) : 0
                    name: "system"
                }
                Column {
                    id: factList
                    objectName: "systemFacts"
                    x: root.plan.stack || !root.plan.picture ? 0 : picture.width + 16 * root.u
                    y: root.plan.stack && root.plan.picture ? picture.height + 8 * root.u : 0
                    width: sheet.width - x
                    spacing: 4 * root.u
                    Repeater {
                        model: root.groups
                        Column {
                            id: group
                            required property var modelData
                            width: factList.width
                            Win98Text { text: group ? group.modelData.heading : ""; accessMarks: false; width: Math.min(implicitWidth, group ? group.width : 0) }
                            Repeater {
                                model: group.modelData.lines
                                Win98Text {
                                    required property string modelData
                                    // The group goes first when the sheet is rebuilt.
                                    readonly property real room: group ? group.width - x : 0
                                    x: 12 * root.u
                                    width: room
                                    // A long version or revision wraps rather than leaving the sheet.
                                    wrap: implicitWidth > room
                                    text: modelData
                                    accessMarks: false
                                }
                            }
                        }
                    }
                }
            }
        }
        Row {
            x: body.width - width
            y: tabs.y + tabs.height + 8 * root.u
            spacing: 6 * root.u
            Win98Button { objectName: "systemOk"; text: "OK"; isDefault: true; focus: true; onClicked: MenuState.close() }
            Win98Button { objectName: "systemCancel"; text: "Cancel"; onClicked: MenuState.close() }
        }
    }
    Keys.onReturnPressed: MenuState.close()
    Keys.onEnterPressed: MenuState.close()
}
