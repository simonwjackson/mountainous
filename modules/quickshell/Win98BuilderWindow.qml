pragma ComponentBehavior: Bound

import QtQuick
import "builder-gate.js" as Gate

// Remote builds as a Win98 window: what the gate is doing and why, the
// facts behind it, then the three actions with their keys in a right-hand
// column (T, D, X), as the Platinum control has them. Every action keeps
// its place when it is disabled; one grey line says why. The shared
// BuilderPanel owns the actions, the pending command and keyboard focus.
//
// Keys: T toggles, D uses the default, X stops builds; Tab or the arrows
// move the focus; Enter or Space run the focused action.
Win98Window {
    id: root

    required property var panel

    readonly property var gate: panel.gate
    readonly property var sample: gate.sample
    readonly property string pending: gate.pending
    readonly property var actions: panel.actionList
    readonly property var toggle: actions[0]
    readonly property var others: actions.slice(1)
    readonly property string mark: Gate.mark(sample, pending)
    readonly property string note: Gate.runningNote(sample)
    readonly property string reason: Gate.reasonText(sample)
    readonly property var facts: Gate.facts(sample)
    readonly property string why: actions.filter(function (a) { return !a.enabled && a.detail !== ""; })
        .map(function (a) { return a.detail + "."; })
        .filter(function (v, i, all) { return all.indexOf(v) === i; }).join(" ")
    readonly property bool ring: panel.keyboardUsed

    title: "Remote builds"
    iconName: "builder"
    onCloseClicked: MenuState.close()

    function dots(s) { return String(s).replace(/\u2026/g, "..."); }
    // The action's letter, underlined where the label has it.
    function marked(label, key) {
        const i = label.toLowerCase().indexOf(key.toLowerCase());
        return i < 0 ? label : label.slice(0, i) + "&" + label.slice(i);
    }

    Column {
        id: body
        width: root.bodyWidth
        spacing: 6 * root.u

        Item {
            width: parent.width
            height: Math.max(16 * root.u, words.height)
            Win98Icon {
                y: root.u
                name: root.pending ? "hourglass" : root.mark === "on" ? "ok" : root.mark === "off" ? "bad"
                    : root.sample.kind === "error" ? "warn" : "hourglass"
            }
            Column {
                id: words
                x: 20 * root.u
                width: parent.width - x
                spacing: 3 * root.u
                Win98Text {
                    width: Math.min(implicitWidth, parent.width)
                    text: root.dots(Gate.headline(root.sample, root.pending))
                    accessMarks: false
                    bold: true
                }
                Win98Text {
                    visible: root.reason !== ""
                    width: parent.width
                    wrap: true
                    text: root.reason
                    accessMarks: false
                }
                Win98Text {
                    visible: root.note !== ""
                    width: parent.width
                    wrap: true
                    text: root.note
                    accessMarks: false
                    color: Win98Tokens.warning
                }
            }
        }

        Item {
            visible: root.facts.length > 0
            width: parent.width
            height: visible ? status.height - 3 * root.u : 0
            Win98GroupBox {
                id: status
                y: -3 * root.u
                width: parent.width
                title: "Status"
                Column {
                    width: body.width - 14 * root.u
                    spacing: 5 * root.u
                    Repeater {
                        model: root.facts
                        Item {
                            required property var modelData
                            width: parent.width
                            height: 13 * root.u
                            Win98Text { text: parent.modelData.label; accessMarks: false; color: Win98Tokens.gray }
                            Win98Text { x: parent.width - width; text: parent.modelData.value; accessMarks: false }
                        }
                    }
                }
            }
        }

        // An etched line, 3 u from its neighbours' gaps and 2 u in.
        Item {
            width: parent.width
            height: 8 * root.u
            Win98Separator { x: 2 * root.u; y: 3 * root.u; width: parent.width - 4 * root.u }
        }

        Item {
            width: parent.width
            height: 13 * root.u
            Win98CheckBox {
                text: root.marked(root.toggle.label, root.toggle.key)
                checked: root.toggle.checked === true
                enabled: root.toggle.enabled
                showFocus: root.ring && root.panel.focusId === "toggle"
                onToggled: root.panel.byKey("toggle")
            }
            Win98Text { x: parent.width - width; text: root.toggle.key; accessMarks: false; color: Win98Tokens.gray }
        }
        Repeater {
            model: root.others
            Item {
                id: act
                required property var modelData
                width: body.width
                height: 21 * root.u
                Win98Button {
                    small: true
                    widthUnits: 150
                    text: root.marked(act.modelData.label, act.modelData.key)
                    enabled: act.modelData.enabled
                    showFocus: root.ring && root.panel.focusId === act.modelData.id
                    onClicked: root.panel.byKey(act.modelData.id)
                }
                Win98Text {
                    x: parent.width - width
                    y: 4 * root.u
                    text: act.modelData.key
                    accessMarks: false
                    color: Win98Tokens.gray
                }
            }
        }

        Win98Text {
            visible: root.why !== ""
            width: parent.width
            wrap: true
            text: root.why
            accessMarks: false
            color: Win98Tokens.gray
        }

        Item {
            visible: !!root.gate.actionError
            width: parent.width
            height: visible ? failText.height + 8 * root.u : 0
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: root.u
                border.color: Win98Tokens.warning
            }
            Win98Text {
                id: failText
                x: 6 * root.u; y: 4 * root.u
                width: parent.width - 12 * root.u
                wrap: true
                text: Gate.actionErrorText(root.gate.actionError)
                accessMarks: false
                color: Win98Tokens.warning
            }
        }

        Item {
            width: parent.width
            height: 20 * root.u
            Win98StatusBar {
                y: 2 * root.u
                width: parent.width
                panes: ["Tab move \u00b7 Enter choose \u00b7 Esc close"]
            }
        }
    }

    Shortcut { sequence: "T"; context: Qt.WindowShortcut; onActivated: root.panel.byKey("toggle") }
    Shortcut { sequence: "D"; context: Qt.WindowShortcut; onActivated: root.panel.byKey("default") }
    Shortcut { sequence: "X"; context: Qt.WindowShortcut; onActivated: root.panel.byKey("stop") }
    Shortcut { sequences: ["Tab", "Down", "Right"]; context: Qt.WindowShortcut; onActivated: root.panel.moveFocus(1) }
    Shortcut { sequences: ["Backtab", "Up", "Left"]; context: Qt.WindowShortcut; onActivated: root.panel.moveFocus(-1) }
    Shortcut {
        sequences: ["Return", "Enter", "Space"]
        context: Qt.WindowShortcut
        onActivated: { root.panel.keyboardUsed = true; root.panel.activate(root.panel.focusId); }
    }
}
