pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import Quickshell.Wayland
import QtQuick
import "themes/win98/session-model.js" as Session

// Shut Down Myoko: Win98's Shut Down Windows. The whole screen, the
// taskbar too, goes under a black 50% checker, one Win98 pixel a cell (the
// glance space's Win98Dither), and the dialog stands in its middle with
// Stand by, Shut down, Restart and Log off. It opens on the last choice
// OK'd; the three that close windows show the red warning line. OK runs
// the Desktop's session command (Platinum's); Cancel, Esc and the close box
// leave everything as it was. A press on the checker does nothing: the
// dialog is modal, as Win98's was.
//
// Its own surface (Overlay, namespace mountainous-shutdown), because the
// checker covers the taskbar, which the menu host's surface does not. It is
// MenuState's "shutdown", so one menu or window is open at a time.
//
// Keys: Up/Down (and Left/Right) move the choice, as in a Win98 option
// group; the underlined letters choose; Enter is OK; Esc cancels; Tab moves
// between the choices, OK and Cancel.
Scope {
    id: host

    required property var desktop

    readonly property bool shown: desktop.active && desktop.shell.chromeVisible && desktop.openId === "shutdown"

    // The open dialog, for checks.
    property var dialog: null

    LazyLoader {
        active: host.shown

        PanelWindow {
            id: win
            readonly property real u: Kit.Win98Tokens.unitFor(win)
            readonly property var plan: Session.shutPlan(Math.floor(win.width / win.u))
            readonly property var choices: host.desktop.shutChoices
            readonly property var current: choices.find(function (c) { return c.id === host.desktop.shutChoice; }) || choices[0]

            screen: host.desktop.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "mountainous-shutdown"
            focusable: true
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            Component.onCompleted: host.dialog = dialog
            Component.onDestruction: if (host.dialog === dialog) host.dialog = null

            function step(d) {
                const i = win.choices.indexOf(win.current);
                host.desktop.shutChoice = win.choices[(i + d + win.choices.length) % win.choices.length].id;
            }
            function ok() { host.desktop.confirmShutDown(win.current.id); }
            function cancel() { MenuState.close(); }

            // The checker: every other unit black, the screen showing through.
            Win98Dither {
                objectName: "shutDownDither"
                width: Math.ceil(win.width / win.u) * win.u
                height: Math.ceil(win.height / win.u) * win.u
                color: "#000000"
                phase: 1
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            Win98Window {
                id: dialog
                objectName: "shutDownDialog"
                title: host.desktop.hostLabel === "" ? "Shut Down" : "Shut Down " + host.desktop.hostLabel
                width: win.plan.width * win.u
                availableHeight: win.height - 4 * win.u
                x: Kit.Win98Tokens.half((win.width - width) / 2, win.u)
                y: Math.max(2 * win.u, Kit.Win98Tokens.snap((win.height - height) / 2, win.u))
                margins: false
                focus: true
                onCloseClicked: win.cancel()
                // Esc is the menu host's for other windows; here it cancels.
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Escape) win.cancel();
                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) win.step(1);
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) win.step(-1);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        // Cancel takes Enter when it has the focus.
                        if (cancelButton.activeFocus) win.cancel(); else win.ok();
                    }
                    else {
                        const ch = (event.text || "").toLowerCase();
                        const hit = ch !== "" ? win.choices.find(function (c) { return Kit.Win98Tokens.accessKey(c.text) === ch; }) : null;
                        if (!hit) return;
                        host.desktop.shutChoice = hit.id;
                    }
                    event.accepted = true;
                }

                Item {
                    id: body
                    x: 10 * win.u
                    width: dialog.bodyWidth - 20 * win.u
                    // 10 u in, the icon or the question and choices, 10 u, the buttons, 8 u out.
                    implicitHeight: 10 * win.u + Math.max(win.plan.icon ? 32 * win.u : 0, column.implicitHeight) + 10 * win.u
                        + Kit.Win98Tokens.buttonHeight * win.u + 8 * win.u

                    Win98Icon {
                        visible: win.plan.icon
                        y: 10 * win.u
                        name: "computer"
                    }
                    Column {
                        id: column
                        x: win.plan.icon ? 44 * win.u : 0
                        y: 10 * win.u
                        width: body.width - x
                        spacing: 4 * win.u
                        Win98Text {
                            width: parent.width
                            wrap: true
                            text: "What do you want " + (host.desktop.hostLabel || "this computer") + " to do?"
                            accessMarks: false
                        }
                        Item { width: 1; height: 2 * win.u }
                        Repeater {
                            model: win.choices
                            Win98RadioButton {
                                id: radio
                                required property var modelData
                                objectName: "shutDown-" + modelData.id
                                width: Math.min(implicitWidth, column.width)
                                height: 14 * win.u
                                text: modelData.text
                                checked: win.current.id === modelData.id
                                // The chosen option carries the focus ring, as in Win98.
                                showFocus: checked && !okButton.activeFocus && !cancelButton.activeFocus
                                onClicked: host.desktop.shutChoice = modelData.id
                            }
                        }
                        Item { width: 1; height: 2 * win.u }
                        // The line under the choices: red for a choice that
                        // closes windows, kept as a blank row for Stand by
                        // so the dialog does not change height.
                        Win98Text {
                            objectName: "shutDownWarning"
                            width: parent.width
                            wrap: true
                            text: win.current.closes ? Session.WARNING : " "
                            accessMarks: false
                            color: Kit.Win98Tokens.danger
                        }
                    }
                    Row {
                        x: body.width - width
                        y: body.implicitHeight - 8 * win.u - Kit.Win98Tokens.buttonHeight * win.u
                        spacing: 6 * win.u
                        Win98Button { id: okButton; objectName: "shutDownOk"; text: "OK"; isDefault: true; onClicked: win.ok() }
                        Win98Button { id: cancelButton; objectName: "shutDownCancel"; text: "Cancel"; onClicked: win.cancel() }
                    }
                }
            }
        }
    }
}
