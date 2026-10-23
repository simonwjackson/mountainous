import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "builder-gate.js" as Gate

// The remote-builder panel: the full state, why, and every action.
//
//   Remote builds                                ×
//   ○ Refusing builds
//     You turned builds off. This lasts until myoko
//     joins another network.
//   Network home   Power mains   Running 0
//   ────────────────────────────────────────────
//   T  Accept builds                       [pill]
//   [D  Use default (on)]  [X  Stop builds]
//   Tab move · Enter choose · Esc close
//
// Opened from the ▾ beside the bar control, a right-click on it, or
// SUPER+O then R. Every action has a letter, and Tab walks them.
Scope {
    id: root

    required property var screen
    required property var gate
    property bool shown: false
    // True when SUPER+O R opened the panel.
    property bool openedByKeyboard: false
    // True when the keyboard opened the panel or has been used in it; the
    // focus ring shows only then.
    property bool keyboardUsed: false
    // The id of the action the keyboard is on.
    property string focusId: "toggle"
    signal closeRequested

    readonly property var actionList: Gate.actions(gate.sample, gate.pending)
    readonly property var focusTargets: actionList.concat([{id: "close", enabled: true}])

    onShownChanged: {
        if (!shown) return;
        root.keyboardUsed = root.openedByKeyboard;
        root.focusId = Gate.moveFocus(root.focusTargets, "", 1);
        root.gate.refresh();
    }

    // When the focused action turns disabled (it just ran, or its reason
    // went away), the focus moves to the first one that is still enabled.
    onActionListChanged: {
        if (root.gate.pending !== "") return;
        // focusTargets may not have caught up yet; build it from the new list.
        const targets = root.actionList.concat([{id: "close", enabled: true}]);
        const target = targets.filter(function (t) { return t.id === root.focusId; })[0];
        if (!target || !target.enabled) root.focusId = Gate.moveFocus(targets, "", 1);
    }

    function action(id) {
        for (const a of root.actionList) if (a.id === id) return a;
        return null;
    }

    function activate(id) {
        if (id === "close") {
            root.closeRequested();
            return;
        }
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
        root.focusId = Gate.moveFocus(root.focusTargets, root.focusId, delta);
    }

    function hintText() {
        // Each action shows its own letter, so the hint names only the rest.
        return "Tab move  ·  Enter choose  ·  Esc close";
    }

    LazyLoader {
        active: root.shown && root.gate.enabled

        PanelWindow {
            id: veil

            screen: root.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            color: "transparent"

            HyprlandFocusGrab {
                active: root.shown
                windows: [ veil ]
                onCleared: root.closeRequested()
            }

            MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

            Rectangle {
                id: card

                readonly property var plan: Gate.panelPlan(veil.width, veil.height)
                readonly property var sample: root.gate.sample
                readonly property string pending: root.gate.pending
                readonly property bool accepting: sample.kind === "ready" && sample.value.accepting

                // Bring the keyboard's target into view when the card scrolls.
                function revealFocus() {
                    let item = null;
                    if (root.focusId === "close") item = closeButton;
                    else if (root.focusId === "toggle") item = card.plan.inlineSwitch ? inlineSwitch : switchRow;
                    else for (let i = 0; i < buttons.count; i++) {
                        if (buttons.model[i].id === root.focusId) item = buttons.itemAt(i);
                    }
                    if (!item) return;
                    const top = item.mapToItem(content, 0, 0).y;
                    const bottom = top + item.height;
                    if (top < flick.contentY) flick.contentY = Math.max(0, top - 6);
                    else if (bottom > flick.contentY + flick.height)
                        flick.contentY = Math.min(flick.contentHeight - flick.height, bottom - flick.height + 6);
                }

                Connections {
                    target: root
                    function onFocusIdChanged() { Qt.callLater(card.revealFocus); }
                }

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 32
                anchors.rightMargin: 6
                width: plan.cardWidth
                height: Math.min(content.implicitHeight + 24, plan.maxHeight)
                radius: Theme.radiusLarge
                color: Theme.bgPanel
                border.width: 1
                border.color: Theme.borderMuted

                MouseArea { anchors.fill: parent }

                // What does not fit scrolls. The plan has already dropped the
                // readouts that may yield, so only a very short screen gets here.
                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 12
                    clip: true
                    contentWidth: width
                    contentHeight: content.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    ScrollIndicator.vertical: ScrollIndicator { }

                    ColumnLayout {
                        id: content
                        width: flick.width
                        spacing: 8

                        // The title row. On a short screen the headline
                        // takes the title's place, and on a shorter one the
                        // switch joins it.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                visible: card.plan.titleIsHeadline
                                    && Gate.mark(card.sample, card.pending) !== "none"
                                text: Gate.mark(card.sample, card.pending) === "on" ? "●" : "○"
                                color: card.accepting ? Theme.accent : Theme.textMuted
                                font.pixelSize: 10
                                font.family: Theme.fontFamily
                            }

                            Text {
                                Layout.fillWidth: true
                                text: card.plan.titleIsHeadline
                                    ? Gate.headline(card.sample, card.pending) : "Remote builds"
                                color: card.plan.titleIsHeadline && card.accepting
                                    ? Theme.accent : Theme.textPrimary
                                font.pixelSize: card.plan.titleIsHeadline ? 12 : 14
                                font.family: Theme.fontFamily
                                font.bold: !card.plan.titleIsHeadline
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                id: inlineSwitch
                                readonly property bool focused: root.keyboardUsed && root.focusId === "toggle"
                                visible: card.plan.inlineSwitch
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 28
                                radius: Theme.radiusSmall
                                color: "transparent"
                                border.width: focused ? 2 : 0
                                border.color: Theme.accent

                                TogglePill {
                                    anchors.centerIn: parent
                                    checked: switchRow.model.checked
                                    enabled: switchRow.model.enabled
                                    onToggled: root.activate("toggle")
                                }
                            }

                            Rectangle {
                                id: closeButton
                                readonly property bool focused: root.keyboardUsed && root.focusId === "close"
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: Theme.radiusSmall
                                color: closeArea.pressed ? Theme.bgActive
                                    : closeArea.containsMouse ? Theme.bgSelected : "transparent"
                                border.width: focused ? 2 : 0
                                border.color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: Theme.textSecondary
                                    font.pixelSize: 16
                                    font.family: Theme.fontFamily
                                }

                                MouseArea {
                                    id: closeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.closeRequested()
                                }
                            }
                        }

                        // The state and why.
                        RowLayout {
                            Layout.fillWidth: true
                            visible: !card.plan.titleIsHeadline
                            spacing: 8

                            Text {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 2
                                visible: Gate.mark(card.sample, card.pending) !== "none"
                                text: Gate.mark(card.sample, card.pending) === "on" ? "●" : "○"
                                color: card.accepting ? Theme.accent : Theme.textMuted
                                font.pixelSize: 10
                                font.family: Theme.fontFamily
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    text: Gate.headline(card.sample, card.pending)
                                    color: card.accepting ? Theme.accent : Theme.textPrimary
                                    font.pixelSize: 12
                                    font.family: Theme.fontFamily
                                    wrapMode: Text.Wrap
                                }

                                // On a short screen the reason keeps one
                                // line; the bar's tooltip has all of it.
                                Text {
                                    Layout.fillWidth: true
                                    visible: card.plan.showReason && text !== ""
                                    text: Gate.reasonText(card.sample)
                                    color: Theme.textSecondary
                                    font.pixelSize: 11
                                    font.family: Theme.fontFamily
                                    wrapMode: Text.Wrap
                                    maximumLineCount: card.plan.reasonLines
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: card.plan.showReason && text !== ""
                                    text: Gate.runningNote(card.sample)
                                    color: Theme.textSecondary
                                    font.pixelSize: 11
                                    font.family: Theme.fontFamily
                                    wrapMode: Text.Wrap
                                    maximumLineCount: card.plan.reasonLines
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // The facts behind the answer. A readout: it yields
                        // on a short screen; the reason above keeps the
                        // decision.
                        Flow {
                            Layout.fillWidth: true
                            visible: card.plan.showFacts && Gate.facts(card.sample).length > 0
                            spacing: 14

                            Repeater {
                                model: Gate.facts(card.sample)

                                Row {
                                    required property var modelData
                                    spacing: 5

                                    Text {
                                        text: modelData.label
                                        color: Theme.textDetail
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                    }

                                    Text {
                                        text: modelData.value
                                        color: Theme.textSecondary
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            visible: !card.plan.titleIsHeadline
                            color: Theme.bgSeparator
                        }

                        // The main control: the switch. TogglePill draws it;
                        // the whole row is the target.
                        Rectangle {
                            id: switchRow

                            readonly property var model: root.action("toggle")
                            readonly property bool focused: root.keyboardUsed && root.focusId === "toggle"

                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            visible: !card.plan.inlineSwitch
                            radius: Theme.radiusSmall
                            color: !model.enabled ? "transparent"
                                : switchArea.pressed ? Theme.bgActive
                                : switchArea.containsMouse ? Theme.bgSelected : Theme.bgInput
                            border.width: focused ? 2 : 1
                            border.color: focused ? Theme.accent
                                : model.enabled ? Theme.borderMuted : Theme.bgSelected

                            MouseArea {
                                id: switchArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: switchRow.model.enabled
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activate("toggle")
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 4
                                spacing: 8

                                Text {
                                    text: switchRow.model.key
                                    color: switchRow.model.enabled ? Theme.textMuted : Theme.textOff
                                    font.pixelSize: 11
                                    font.family: Theme.fontFamily
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: switchRow.model.label
                                    color: switchRow.model.enabled ? Theme.textPrimary : Theme.textOff
                                    font.pixelSize: 11
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                }

                                TogglePill {
                                    checked: switchRow.model.checked
                                    enabled: switchRow.model.enabled
                                    onToggled: root.activate("toggle")
                                }
                            }
                        }

                        // The other two actions. They share a row while the
                        // card is wide enough and stack when it is not.
                        GridLayout {
                            Layout.fillWidth: true
                            columns: card.plan.buttonsInRow ? 2 : 1
                            columnSpacing: 6
                            rowSpacing: 6

                            Repeater {
                                id: buttons
                                model: root.actionList.filter(function (a) { return a.id !== "toggle"; })

                                NotificationButton {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    keyHint: modelData.key
                                    enabled: modelData.enabled
                                    focused: root.keyboardUsed && root.focusId === modelData.id
                                    maxWidth: card.width
                                    onClicked: root.activate(modelData.id)
                                }
                            }
                        }

                        // Why an action is disabled, in one line.
                        Text {
                            Layout.fillWidth: true
                            visible: card.plan.showDetail && text !== ""
                            text: {
                                const why = root.actionList.filter(function (a) {
                                    return !a.enabled && a.detail !== "";
                                }).map(function (a) { return a.detail + "."; });
                                return why.join(" ");
                            }
                            color: Theme.textDetail
                            font.pixelSize: 10
                            font.family: Theme.fontFamily
                            wrapMode: Text.Wrap
                        }

                        // A failed command. It stays until the next command,
                        // the gate's next write, or 30 s.
                        Text {
                            Layout.fillWidth: true
                            visible: root.gate.actionError !== null
                            text: Gate.actionErrorText(root.gate.actionError)
                            color: Theme.warning
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: card.plan.showHint
                            text: root.hintText()
                            color: Theme.textDetail
                            font.pixelSize: 9
                            font.family: Theme.fontFamily
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            Shortcut {
                sequence: "T"
                context: Qt.WindowShortcut
                onActivated: root.byKey("toggle")
            }

            Shortcut {
                sequence: "D"
                context: Qt.WindowShortcut
                onActivated: root.byKey("default")
            }

            Shortcut {
                sequence: "X"
                context: Qt.WindowShortcut
                onActivated: root.byKey("stop")
            }

            Shortcut {
                sequence: "Tab"
                context: Qt.WindowShortcut
                onActivated: root.moveFocus(1)
            }

            Shortcut {
                sequence: "Backtab"
                context: Qt.WindowShortcut
                onActivated: root.moveFocus(-1)
            }

            Shortcut {
                sequences: ["Down", "Right"]
                context: Qt.WindowShortcut
                onActivated: root.moveFocus(1)
            }

            Shortcut {
                sequences: ["Up", "Left"]
                context: Qt.WindowShortcut
                onActivated: root.moveFocus(-1)
            }

            Shortcut {
                sequences: ["Return", "Enter", "Space"]
                context: Qt.WindowShortcut
                onActivated: {
                    root.keyboardUsed = true;
                    root.activate(root.focusId);
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                onActivated: root.closeRequested()
            }
        }
    }
}
