import Hensou as Kit
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

// A confirmation or an error from the desktop, as each OS drew one
// (desktop-icons-model.js confirmPlan and errorPlan give the words).
// Platinum: a modal alert under the bar at the left, as PlatinumAlert;
// buttons on the right, the default one ringed. Memphis: a message box in
// the middle of the screen with Yes / No (or OK), the default focused.
// Enter takes the default button, Escape cancels. Modal: nothing else on
// the screen takes a click while it is open.
PanelWindow {
    id: alert

    required property var modelData
    // { title, text, accept, cancel, defaultButton, icon }
    required property var spec
    property string themeId: "platinum"
    signal accepted
    signal cancelled

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    // The keyboard at once (a menu's arrows, an alert's Enter and Escape),
    // under any compositor; HyprlandFocusGrab ends it on an outside click.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "mountainous-alert"
    Component.onCompleted: SoundEvents.requested("alert")

    readonly property bool win98: alert.themeId === "win98"
    readonly property bool hasCancel: !!alert.spec && (alert.spec.cancel || "") !== ""
    readonly property bool cancelIsDefault: alert.hasCancel && alert.spec.defaultButton === "cancel"
    property bool done: false
    function accept() { if (alert.done) return; alert.done = true; alert.accepted(); }
    function cancel() { if (alert.done) return; alert.done = true; if (alert.hasCancel) alert.cancelled(); else alert.accepted(); }
    function takeDefault() { if (alert.cancelIsDefault) alert.cancel(); else alert.accept(); }

    HyprlandFocusGrab {
        active: alert.visible && !alert.done
        windows: [alert]
    }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    Shortcut { sequence: "Escape"; context: Qt.WindowShortcut; onActivated: alert.cancel() }
    Shortcut { sequences: ["Return", "Enter"]; context: Qt.WindowShortcut; onActivated: alert.takeDefault() }
    Shortcut { sequence: "Y"; context: Qt.WindowShortcut; enabled: alert.win98 && alert.hasCancel; onActivated: alert.accept() }
    Shortcut { sequence: "N"; context: Qt.WindowShortcut; enabled: alert.win98 && alert.hasCancel; onActivated: alert.cancel() }

    // ---------------------------------------------------------- Platinum
    PlatinumDialogFrame {
        visible: !alert.win98
        x: Math.max(4, Math.min(24, alert.width - width - 4))
        y: Math.max(4, Math.min(Kit.PlatinumTokens.barHeight + 22, alert.height - height - 4))
        width: Math.min(implicitWidth, alert.width - 8)
        closable: false

        Column {
            width: Math.max(160, Math.min(380, alert.width - 48))
            spacing: 16

            Row {
                width: parent.width
                spacing: 14
                Canvas {
                    id: mark
                    width: 32
                    height: 32
                    readonly property string kind: alert.spec ? alert.spec.icon : "caution"
                    onKindChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d");
                        c.reset();
                        c.strokeStyle = "#000000";
                        c.lineWidth = 1.5;
                        if (kind === "stop") {
                            // The stop alert: a red octagon with a white bar.
                            const p = [[10, 1.5], [22, 1.5], [30.5, 10], [30.5, 22], [22, 30.5], [10, 30.5], [1.5, 22], [1.5, 10]];
                            c.fillStyle = "#d02020";
                            c.beginPath(); c.moveTo(p[0][0], p[0][1]);
                            for (let i = 1; i < p.length; i++) c.lineTo(p[i][0], p[i][1]);
                            c.closePath(); c.fill(); c.stroke();
                            c.fillStyle = "#ffffff";
                            c.fillRect(8, 14, 16, 4);
                        } else {
                            // The caution mark, as PlatinumAlert draws it.
                            c.fillStyle = "#f2c94c";
                            c.beginPath(); c.moveTo(16, 2.5); c.lineTo(30.5, 29.5); c.lineTo(1.5, 29.5); c.closePath();
                            c.fill(); c.stroke();
                            c.fillStyle = "#000000";
                            c.fillRect(14.5, 11, 3, 10);
                            c.fillRect(14.5, 23.5, 3, 3);
                        }
                    }
                }
                Column {
                    width: parent.width - mark.width - parent.spacing
                    spacing: 6
                    Text {
                        width: parent.width
                        text: alert.spec ? alert.spec.title : ""
                        wrapMode: Text.Wrap
                        color: Kit.PlatinumTokens.menuText
                        font.family: Kit.PlatinumTokens.platinumFont
                        font.pixelSize: Kit.PlatinumTokens.platinumText
                        font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: alert.spec ? alert.spec.text : ""
                        wrapMode: Text.Wrap
                        lineHeight: 1.2
                        color: Kit.PlatinumTokens.menuTextSecondary
                        font.family: Kit.PlatinumTokens.platinumFont
                        font.pixelSize: Kit.PlatinumTokens.platinumSmall
                        font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                    }
                }
            }

            // Buttons end on the right edge; the default one has the ring.
            Item {
                width: parent.width
                height: buttons.height
                readonly property real buttonWidth: Kit.PlatinumMetrics.buttonWidth(
                    [alert.spec ? alert.spec.cancel || "" : "", alert.spec ? alert.spec.accept : ""])
                Row {
                    id: buttons
                    anchors.right: parent.right
                    spacing: 12
                    PlatinumButton {
                        objectName: "alertCancel"
                        visible: alert.hasCancel
                        anchors.verticalCenter: parent.verticalCenter
                        text: alert.spec ? alert.spec.cancel || "" : ""
                        isDefault: alert.cancelIsDefault
                        fixedWidth: parent.parent.buttonWidth
                        onClicked: alert.cancel()
                    }
                    PlatinumButton {
                        objectName: "alertAccept"
                        anchors.verticalCenter: parent.verticalCenter
                        text: alert.spec ? alert.spec.accept : ""
                        isDefault: !alert.cancelIsDefault
                        fixedWidth: parent.parent.buttonWidth
                        onClicked: alert.accept()
                    }
                }
            }
        }
    }

    // ----------------------------------------------------------- Memphis
    Win98Window {
        id: box
        visible: alert.win98
        title: alert.spec ? alert.spec.title : ""
        showClose: true
        margins: false
        onCloseClicked: alert.cancel()
        x: Kit.Win98Tokens.snap((alert.width - width) / 2, box.u)
        y: Kit.Win98Tokens.snap((alert.height - height) / 2, box.u)
        width: Math.min(implicitWidth, alert.width - 8)

        Item {
            readonly property real textWidth: Math.min(260 * box.u, Math.max(140 * box.u, message.implicitWidth))
            implicitWidth: 12 * box.u + 32 * box.u + 12 * box.u + textWidth + 14 * box.u
            implicitHeight: 12 * box.u + Math.max(32 * box.u, message.height) + 14 * box.u + 23 * box.u + 10 * box.u
            Win98Icon {
                x: 12 * box.u
                y: 12 * box.u
                size: 32
                name: alert.spec && alert.spec.icon === "error" ? "bad" : "warn"
            }
            Win98Text {
                id: message
                x: 56 * box.u
                y: 12 * box.u + (message.height < 32 * box.u ? Kit.Win98Tokens.snap((32 * box.u - message.height) / 2, box.u) : 0)
                width: parent.textWidth
                text: alert.spec ? alert.spec.text : ""
                accessMarks: false
                wrap: true
            }
            Row {
                x: Kit.Win98Tokens.half((parent.width - width) / 2, box.u)
                y: parent.implicitHeight - 10 * box.u - 23 * box.u
                spacing: 6 * box.u
                Win98Button {
                    objectName: "alertAccept"
                    text: alert.spec ? alert.spec.accept : "OK"
                    widthUnits: 75
                    isDefault: !alert.cancelIsDefault
                    focus: !alert.cancelIsDefault
                    onClicked: alert.accept()
                }
                Win98Button {
                    objectName: "alertCancel"
                    visible: alert.hasCancel
                    widthUnits: 75
                    text: alert.spec ? alert.spec.cancel || "" : ""
                    isDefault: alert.cancelIsDefault
                    focus: alert.cancelIsDefault
                    onClicked: alert.cancel()
                }
            }
        }
    }
}
