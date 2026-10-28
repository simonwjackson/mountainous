import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

// A Platinum confirmation alert for Log Out…, Restart… and Shut Down…: a
// modal under the bar at the left, never centred. The action is the
// default button (Enter); Cancel and Escape close it. Nothing else on the
// screen takes a click while it is open.
PanelWindow {
    id: alert
    Component.onCompleted: SoundEvents.requested("alert")

    required property var modelData
    // { title, text, button } from menu-models.js alert().
    required property var spec
    signal accepted
    signal cancelled
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "mountainous-alert"

    HyprlandFocusGrab {
        active: alert.visible
        windows: [alert]
    }

    // Modal: a click outside the alert does nothing.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    PlatinumDialogFrame {
        id: frame
        x: Math.max(4, Math.min(24, alert.width - width - 4))
        y: Math.max(4, Math.min(PlatinumTokens.barHeight + 22, alert.height - height - 4))
        width: Math.min(implicitWidth, alert.width - 8)
        closable: false
        focus: true
        Keys.onEscapePressed: alert.cancelled()
        Keys.onReturnPressed: alert.accepted()
        Keys.onEnterPressed: alert.accepted()
        Component.onCompleted: forceActiveFocus()

        Column {
            width: Math.max(160, Math.min(380, alert.width - 48))
            spacing: 16

            Row {
                width: parent.width
                spacing: 14
                // The caution mark of a Platinum alert.
                Canvas {
                    id: caution
                    width: 32
                    height: 30
                    onPaint: {
                        const c = getContext("2d");
                        c.reset();
                        c.fillStyle = "#f2c94c";
                        c.strokeStyle = "#000000";
                        c.lineWidth = 1.5;
                        c.beginPath(); c.moveTo(16, 1.5); c.lineTo(30.5, 28.5); c.lineTo(1.5, 28.5); c.closePath();
                        c.fill(); c.stroke();
                        c.fillStyle = "#000000";
                        c.fillRect(14.5, 10, 3, 10);
                        c.fillRect(14.5, 22.5, 3, 3);
                    }
                }
                Column {
                    width: parent.width - caution.width - parent.spacing
                    spacing: 6
                    Text {
                        width: parent.width
                        text: alert.spec ? alert.spec.title : ""
                        color: PlatinumTokens.menuText
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumText
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
                    Text {
                        width: parent.width
                        text: alert.spec ? alert.spec.text : ""
                        wrapMode: Text.Wrap
                        lineHeight: 1.2
                        color: PlatinumTokens.menuTextSecondary
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumSmall
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
                }
            }

            // Buttons end on the right edge; the default is last, with its ring.
            Item {
                width: parent.width
                height: buttons.height
                readonly property real buttonWidth: PlatinumMetrics.buttonWidth(["Cancel", alert.spec ? alert.spec.button : ""])
                Row {
                    id: buttons
                    anchors.right: parent.right
                    spacing: 12
                    PlatinumButton {
                        objectName: "alertCancel"
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Cancel"
                        fixedWidth: parent.parent.buttonWidth
                        onClicked: alert.cancelled()
                    }
                    PlatinumButton {
                        objectName: "alertDefault"
                        anchors.verticalCenter: parent.verticalCenter
                        text: alert.spec ? alert.spec.button : ""
                        isDefault: true
                        fixedWidth: parent.parent.buttonWidth
                        onClicked: alert.accepted()
                    }
                }
            }
        }
    }
}
