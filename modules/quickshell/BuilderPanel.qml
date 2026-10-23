import Quickshell
import QtQuick
import QtQuick.Layouts
import "builder-gate.js" as Gate

// The remote-builder menu: the full state, why, and every action, as a
// Platinum menu under the builder title (MenuHost shows it).
//
//   Remote builds                                   [×]
//   ●  Accepting builds
//      At home on mains power, so myoko accepts by default.
//      Network                                    home
//      Power                                     mains
//      Running                                       0
//   ────────────────────────────────────────────────────
//   ☑  Accept builds                                 T
//      [Use default (on)]                            D
//      [Stop builds     ]                            X
//      No manual choice to clear. No builds running.
//      Tab move · Enter choose · Esc close
//
// Opened from the title (press or right-click) or SUPER+O then R. Every
// action has its letter on the right edge, and Tab walks them. The header
// carries what the old tooltip said: the headline, the reason, the running
// note and the facts.
Scope {
    id: root

    required property var gate
    property bool shown: false
    // True when SUPER+O R opened the menu: the focus ring shows at once.
    property bool openedByKeyboard: false
    property bool keyboardUsed: false
    // The action the keyboard is on.
    property string focusId: "toggle"

    readonly property var actionList: Gate.actions(gate.sample, gate.pending)

    onShownChanged: {
        if (!shown) return;
        root.keyboardUsed = root.openedByKeyboard;
        root.focusId = Gate.moveFocus(root.actionList, "", 1);
        root.gate.refresh();
    }

    // When the focused action turns disabled (it just ran, or its reason
    // went away), the focus moves to the first one still enabled.
    onActionListChanged: {
        if (root.gate.pending !== "") return;
        const target = root.actionList.filter(function (t) { return t.id === root.focusId; })[0];
        if (!target || !target.enabled) root.focusId = Gate.moveFocus(root.actionList, "", 1);
    }

    function action(id) {
        for (const a of root.actionList) if (a.id === id) return a;
        return null;
    }

    function activate(id) {
        const a = root.action(id);
        if (a && a.enabled) root.gate.run(a.command);
    }

    function byKey(id) {
        root.keyboardUsed = true;
        root.focusId = id;
        root.activate(id);
    }

    function moveFocus(delta) {
        root.keyboardUsed = true;
        root.focusId = Gate.moveFocus(root.actionList, root.focusId, delta);
    }

    property Component menu: Component {
        MenuFrame {
            id: frame

            readonly property var sample: root.gate.sample
            readonly property string pending: root.gate.pending
            readonly property string markName: Gate.mark(sample, pending)
            readonly property var facts: Gate.facts(sample)
            readonly property var toggle: root.action("toggle")
            readonly property var others: root.actionList.filter(function (a) { return a.id !== "toggle"; })
            // "Use default" and "Stop" are one role: one width.
            readonly property real buttonWidth: PlatinumMetrics.buttonWidth(frame.others.map(function (a) { return a.label; })
                .concat(["Use default (off)", "Stop 88 builds"]))
            readonly property real keyWidth: PlatinumMetrics.widest(["T", "D", "X", "W"])
            readonly property string why: root.actionList.filter(function (a) {
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
                    x: Theme.menuGutter + (Theme.menuGutterWidth - width) / 2
                    y: (headlineText.height - height) / 2
                    name: frame.markName === "on" ? "dot" : "ring"
                    size: 12
                    color: frame.markName === "on" ? Theme.menuText : Theme.menuTextSecondary
                }

                Column {
                    id: stateColumn
                    x: Theme.menuTextLeft
                    width: parent.width - x - frame.rightInset
                    spacing: 3

                    Text {
                        id: headlineText
                        width: parent.width
                        text: Gate.headline(frame.sample, frame.pending)
                        wrapMode: Text.Wrap
                        color: Theme.menuText
                        font.family: Theme.platinumFont
                        font.pixelSize: Theme.platinumText
                        font.letterSpacing: Theme.platinumTracking
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: Gate.reasonText(frame.sample)
                        wrapMode: Text.Wrap
                        color: Theme.menuTextSecondary
                        font.family: Theme.platinumFont
                        font.pixelSize: Theme.platinumSmall
                        font.letterSpacing: Theme.platinumTracking
                        lineHeight: 1.15
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: Gate.runningNote(frame.sample)
                        wrapMode: Text.Wrap
                        color: Theme.menuWarning
                        font.family: Theme.platinumFont
                        font.pixelSize: Theme.platinumSmall
                        font.letterSpacing: Theme.platinumTracking
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
                        x: Theme.menuTextLeft
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Theme.menuTextSecondary
                        font.family: Theme.platinumFont
                        font.pixelSize: Theme.platinumSmall
                        font.letterSpacing: Theme.platinumTracking
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: frame.rightInset
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.value
                        color: Theme.menuText
                        font.family: Theme.platinumFont
                        font.pixelSize: Theme.platinumSmall
                        font.letterSpacing: Theme.platinumTracking
                    }
                }
            }

            MenuParts.Separator {}

            // The flip: a check box in the gutter, its letter on the right.
            Item {
                id: toggleRow
                readonly property bool focused: root.keyboardUsed && root.focusId === "toggle"
                Layout.fillWidth: true
                implicitHeight: Theme.menuLine + 4
                enabled: frame.toggle.enabled

                Rectangle {
                    visible: toggleRow.focused
                    x: Theme.menuGutter - 2
                    width: toggleLabel.x + toggleLabel.width + 6 - x
                    height: parent.height - 4
                    y: 2
                    color: "transparent"
                    border.width: 2 * Theme.hair
                    border.color: Theme.highlight
                }

                PlatinumCheckBox {
                    id: toggleBox
                    x: Theme.menuGutter + (Theme.menuGutterWidth - width) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    checked: frame.toggle.checked
                    enabled: frame.toggle.enabled
                    down: toggleArea.pressed
                }

                Text {
                    id: toggleLabel
                    x: Theme.menuTextLeft
                    anchors.verticalCenter: parent.verticalCenter
                    text: frame.toggle.label
                    color: frame.toggle.enabled ? Theme.menuText : Theme.menuTextOff
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumText
                    font.letterSpacing: Theme.platinumTracking
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: frame.rightInset
                    anchors.verticalCenter: parent.verticalCenter
                    width: frame.keyWidth
                    horizontalAlignment: Text.AlignRight
                    text: frame.toggle.key
                    color: frame.toggle.enabled ? Theme.menuTextSecondary : Theme.menuTextOff
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumSmall
                }

                MouseArea {
                    id: toggleArea
                    width: toggleLabel.x + toggleLabel.width + 4
                    height: parent.height
                    enabled: frame.toggle.enabled
                    onClicked: {
                        root.focusId = "toggle";
                        root.activate("toggle");
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
                    implicitHeight: Theme.menuButtonHeight + 8

                    PlatinumButton {
                        x: Theme.menuTextLeft
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        fixedWidth: frame.buttonWidth
                        enabled: modelData.enabled
                        focused: root.keyboardUsed && root.focusId === modelData.id
                        onClicked: {
                            root.focusId = modelData.id;
                            root.activate(modelData.id);
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: frame.rightInset
                        anchors.verticalCenter: parent.verticalCenter
                        width: frame.keyWidth
                        horizontalAlignment: Text.AlignRight
                        text: modelData.key
                        color: modelData.enabled ? Theme.menuTextSecondary : Theme.menuTextOff
                        font.family: Theme.platinumFont
                        font.pixelSize: Theme.platinumSmall
                    }
                }
            }

            // Why an action is off, in one place.
            MenuParts.Line {
                visible: text !== ""
                rightInset: frame.rightInset
                text: frame.why
            }

            // A failed command. It stays until the next command, the gate's
            // next write, or 30 s.
            MenuParts.Line {
                visible: root.gate.actionError !== null
                rightInset: frame.rightInset
                text: Gate.actionErrorText(root.gate.actionError)
                color: Theme.menuWarning
            }

            MenuParts.Hint {
                rightInset: frame.rightInset
                text: "Tab move · Enter choose · Esc close"
            }

            Shortcut { sequence: "T"; context: Qt.WindowShortcut; onActivated: root.byKey("toggle") }
            Shortcut { sequence: "D"; context: Qt.WindowShortcut; onActivated: root.byKey("default") }
            Shortcut { sequence: "X"; context: Qt.WindowShortcut; onActivated: root.byKey("stop") }
            Shortcut { sequence: "Tab"; context: Qt.WindowShortcut; onActivated: root.moveFocus(1) }
            Shortcut { sequence: "Backtab"; context: Qt.WindowShortcut; onActivated: root.moveFocus(-1) }
            Shortcut { sequences: ["Down", "Right"]; context: Qt.WindowShortcut; onActivated: root.moveFocus(1) }
            Shortcut { sequences: ["Up", "Left"]; context: Qt.WindowShortcut; onActivated: root.moveFocus(-1) }
            Shortcut {
                sequences: ["Return", "Enter", "Space"]
                context: Qt.WindowShortcut
                onActivated: {
                    root.keyboardUsed = true;
                    root.activate(root.focusId);
                }
            }
        }
    }
}
