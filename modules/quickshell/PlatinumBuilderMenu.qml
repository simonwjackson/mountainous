import Hensou as Kit
import Quickshell
import QtQuick
import QtQuick.Layouts
import "builder-gate.js" as Gate


PlatinumMenuFrame {
    id: frame
    required property var panel

    readonly property var sample: panel.gate.sample
    readonly property string pending: panel.gate.pending
    readonly property string markName: Gate.mark(sample, pending)
    readonly property var facts: Gate.facts(sample)
    readonly property var toggle: panel.action("toggle")
    readonly property var others: panel.actionList.filter(function (a) { return a.id !== "toggle"; })
    // "Use default" and "Stop" are one role: one width.
    readonly property real buttonWidth: Kit.PlatinumMetrics.buttonWidth(frame.others.map(function (a) { return a.label; })
        .concat(["Use default (off)", "Stop 88 builds"]))
    readonly property real keyWidth: Kit.PlatinumMetrics.widest(["T", "D", "X", "W"])
    readonly property string why: panel.actionList.filter(function (a) {
        return !a.enabled && a.detail !== "";
    }).map(function (a) { return a.detail + "."; }).join(" ")

    preferredWidth: 360
    title: "Remote builds"

    // The state and why, with the gutter mark: ● accepting,
    // ○ refusing, none without a valid status.
    Item {
        Layout.fillWidth: true
        implicitHeight: stateColumn.implicitHeight + 6

        PlatinumIcon {
            visible: frame.markName !== "none"
            x: Kit.PlatinumTokens.menuGutter + (Kit.PlatinumTokens.menuGutterWidth - width) / 2
            y: (headlineText.height - height) / 2
            name: frame.markName === "on" ? "dot" : "ring"
            size: 12
            color: frame.markName === "on" ? Kit.PlatinumTokens.menuText : Kit.PlatinumTokens.menuTextSecondary
        }

        Column {
            id: stateColumn
            x: Kit.PlatinumTokens.menuTextLeft
            width: parent.width - x - frame.rightInset
            spacing: 3

            Text {
                id: headlineText
                width: parent.width
                text: Gate.headline(frame.sample, frame.pending)
                wrapMode: Text.Wrap
                color: Kit.PlatinumTokens.menuText
                font.family: Kit.PlatinumTokens.platinumFont
                font.pixelSize: Kit.PlatinumTokens.platinumText
                font.letterSpacing: Kit.PlatinumTokens.platinumTracking
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: Gate.reasonText(frame.sample)
                wrapMode: Text.Wrap
                color: Kit.PlatinumTokens.menuTextSecondary
                font.family: Kit.PlatinumTokens.platinumFont
                font.pixelSize: Kit.PlatinumTokens.platinumSmall
                font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                lineHeight: 1.15
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: Gate.runningNote(frame.sample)
                wrapMode: Text.Wrap
                color: Kit.PlatinumTokens.menuWarning
                font.family: Kit.PlatinumTokens.platinumFont
                font.pixelSize: Kit.PlatinumTokens.platinumSmall
                font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                lineHeight: 1.15
            }
        }
    }

    // The facts behind the answer: label on the text edge, value on
    // the right edge.
    Repeater {
        model: frame.facts

        Item {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 20

            Text {
                x: Kit.PlatinumTokens.menuTextLeft
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: Kit.PlatinumTokens.menuTextSecondary
                font.family: Kit.PlatinumTokens.platinumFont
                font.pixelSize: Kit.PlatinumTokens.platinumSmall
                font.letterSpacing: Kit.PlatinumTokens.platinumTracking
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: frame.rightInset
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.value
                color: Kit.PlatinumTokens.menuText
                font.family: Kit.PlatinumTokens.platinumFont
                font.pixelSize: Kit.PlatinumTokens.platinumSmall
                font.letterSpacing: Kit.PlatinumTokens.platinumTracking
            }
        }
    }

    PlatinumMenuParts.Separator {}

    // The flip: a check box in the gutter, its letter on the right.
    Item {
        id: toggleRow
        readonly property bool focused: panel.keyboardUsed && panel.focusId === "toggle"
        Layout.fillWidth: true
        implicitHeight: Kit.PlatinumTokens.menuLine + 4
        enabled: frame.toggle.enabled

        Rectangle {
            visible: toggleRow.focused
            x: Kit.PlatinumTokens.menuGutter - 2
            width: toggleLabel.x + toggleLabel.width + 6 - x
            height: parent.height - 4
            y: 2
            color: "transparent"
            border.width: 2 * Kit.PlatinumTokens.hairFor(QsWindow.window)
            border.color: Kit.PlatinumTokens.highlight
        }

        PlatinumCheckBox {
            id: toggleBox
            x: Kit.PlatinumTokens.menuGutter + (Kit.PlatinumTokens.menuGutterWidth - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            checked: frame.toggle.checked
            enabled: frame.toggle.enabled
            down: toggleArea.pressed
        }

        Text {
            id: toggleLabel
            x: Kit.PlatinumTokens.menuTextLeft
            anchors.verticalCenter: parent.verticalCenter
            text: frame.toggle.label
            color: frame.toggle.enabled ? Kit.PlatinumTokens.menuText : Kit.PlatinumTokens.menuTextOff
            font.family: Kit.PlatinumTokens.platinumFont
            font.pixelSize: Kit.PlatinumTokens.platinumText
            font.letterSpacing: Kit.PlatinumTokens.platinumTracking
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: frame.rightInset
            anchors.verticalCenter: parent.verticalCenter
            width: frame.keyWidth
            horizontalAlignment: Text.AlignRight
            text: frame.toggle.key
            color: frame.toggle.enabled ? Kit.PlatinumTokens.menuTextSecondary : Kit.PlatinumTokens.menuTextOff
            font.family: Kit.PlatinumTokens.platinumFont
            font.pixelSize: Kit.PlatinumTokens.platinumSmall
        }

        MouseArea {
            id: toggleArea
            width: toggleLabel.x + toggleLabel.width + 4
            height: parent.height
            enabled: frame.toggle.enabled
            onClicked: {
                panel.focusId = "toggle";
                panel.activate("toggle");
            }
        }
    }

    // Use default and Stop: one width, on the text edge, each with
    // its letter on the right edge.
    Repeater {
        model: frame.others

        Item {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: Kit.PlatinumTokens.menuButtonHeight + 8

            PlatinumButton {
                x: Kit.PlatinumTokens.menuTextLeft
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                fixedWidth: frame.buttonWidth
                enabled: modelData.enabled
                focused: panel.keyboardUsed && panel.focusId === modelData.id
                onClicked: {
                    panel.focusId = modelData.id;
                    panel.activate(modelData.id);
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: frame.rightInset
                anchors.verticalCenter: parent.verticalCenter
                width: frame.keyWidth
                horizontalAlignment: Text.AlignRight
                text: modelData.key
                color: modelData.enabled ? Kit.PlatinumTokens.menuTextSecondary : Kit.PlatinumTokens.menuTextOff
                font.family: Kit.PlatinumTokens.platinumFont
                font.pixelSize: Kit.PlatinumTokens.platinumSmall
            }
        }
    }

    // Why an action is off, in one place.
    PlatinumMenuParts.Line {
        visible: text !== ""
        rightInset: frame.rightInset
        text: frame.why
    }

    // A failed command. It stays until the next command, the gate's
    // next write, or 30 s.
    PlatinumMenuParts.Line {
        visible: panel.gate.actionError !== null
        rightInset: frame.rightInset
        text: Gate.actionErrorText(panel.gate.actionError)
        color: Kit.PlatinumTokens.menuWarning
    }

    PlatinumMenuParts.Hint {
        rightInset: frame.rightInset
        text: "Tab move · Enter choose · Esc close"
    }

    Shortcut { sequence: "T"; context: Qt.WindowShortcut; onActivated: panel.byKey("toggle") }
    Shortcut { sequence: "D"; context: Qt.WindowShortcut; onActivated: panel.byKey("default") }
    Shortcut { sequence: "X"; context: Qt.WindowShortcut; onActivated: panel.byKey("stop") }
    Shortcut { sequence: "Tab"; context: Qt.WindowShortcut; onActivated: panel.moveFocus(1) }
    Shortcut { sequence: "Backtab"; context: Qt.WindowShortcut; onActivated: panel.moveFocus(-1) }
    Shortcut { sequences: ["Down", "Right"]; context: Qt.WindowShortcut; onActivated: panel.moveFocus(1) }
    Shortcut { sequences: ["Up", "Left"]; context: Qt.WindowShortcut; onActivated: panel.moveFocus(-1) }
    Shortcut {
        sequences: ["Return", "Enter", "Space"]
        context: Qt.WindowShortcut
        onActivated: {
            panel.keyboardUsed = true;
            panel.activate(panel.focusId);
        }
    }
}