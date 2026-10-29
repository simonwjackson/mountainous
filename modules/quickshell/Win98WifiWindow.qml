pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell.Networking
import QtQuick

// Wi-Fi as a Win98 window: the radio's check box and Scan, the networks in
// a list view, the failure in a red frame, the password prompt, and
// Connect / Disconnect / Set up and Forget for the selected network. The
// shared WifiPanel owns every value.
//
// Keys: Up/Down select, Enter or Space run the action, S scans, P turns
// the radio on or off, Shift+Del forgets. While the password prompt is up,
// Enter connects and Esc cancels the prompt.
Win98Window {
    id: root

    required property var panel

    readonly property var device: panel.device
    readonly property bool asking: panel.passwordNetwork !== null
    readonly property bool scanning: !!device && device.scannerEnabled
    readonly property var network: list.currentIndex >= 0 ? panel.networks[list.currentIndex] || null : null

    title: "Wi-Fi"
    iconName: "wifi-4"
    onCloseClicked: MenuState.close()

    // A short screen: the list gives up rows first (down to two), then the
    // status bar goes; the body scrolls only after that (Win98Window).
    readonly property real listNatural: 140 * u
    readonly property real listMin: 72 * u
    // Measured after layout settles, not bound: the list's height feeds
    // the window's own height, so a binding would loop. The sum is a fixed
    // point (what the list gives up, it adds back).
    property real natural: 0
    Timer {
        id: naturalMeasure
        interval: 0
        onTriggered: root.measureNatural()
    }
    function measureNatural() { root.natural = implicitHeight + (listNatural - list.height) + (statusArea.visible ? 0 : statusBar.height + 8 * u); }
    Connections {
        target: root
        function onImplicitHeightChanged() { naturalMeasure.restart(); }
    }
    Component.onCompleted: naturalMeasure.restart()
    readonly property real squeeze: availableHeight > 0 ? Math.max(0, natural - availableHeight) : 0
    readonly property bool dropStatus: squeeze > listNatural - listMin + 0.5
    readonly property real listHeight: Math.max(listMin, Math.floor((listNatural - squeeze) / u) * u)

    // Esc closes the prompt first.
    function cancel() {
        if (!root.asking) return false;
        root.panel.cancelPassword();
        return true;
    }
    function actionLabel(n) {
        if (!n) return "Connect";
        if (n.stateChanging) return "Working";
        if (n.connected) return "Disconnect";
        if (root.panel.isEnterprise(n) && !n.known) return "Set up";
        return "Connect";
    }
    function runCurrent() { if (root.network && !root.asking) root.panel.runNetworkAction(root.network); }
    function forgetCurrent() { if (root.network && root.network.known && !root.network.stateChanging) root.network.forget(); }
    function toggleScan() { if (root.device && root.panel.radioEnabled) root.device.scannerEnabled = !root.device.scannerEnabled; }
    function submit() { root.panel.submitPassword(password.text); }

    Timer {
        id: passwordFocus
        interval: 0
        onTriggered: password.forceActiveFocus()
    }
    Connections {
        target: root.panel
        function onPasswordNetworkChanged(): void {
            if (root.panel.passwordNetwork) {
                const i = root.panel.networks.indexOf(root.panel.passwordNetwork);
                if (i >= 0) list.currentIndex = i;
                passwordFocus.restart();
            } else {
                password.text = "";
                list.forceActiveFocus();
            }
        }
    }

    Column {
        id: body
        width: root.bodyWidth

        Item {
            width: parent.width
            height: 21 * root.u
            Win98CheckBox {
                y: 4 * root.u
                text: "Wi-Fi &on"
                enabled: root.panel.hardwareEnabled
                checked: root.panel.radioEnabled
                onToggled: root.panel.setRadio(!root.panel.radioEnabled)
            }
            Win98Button {
                x: parent.width - width
                small: true
                text: root.scanning ? "&Stop" : "&Scan"
                enabled: root.device !== null && root.panel.radioEnabled
                onClicked: root.toggleScan()
            }
        }
        Item { width: 1; height: 3 * root.u }
        Win98GroupBox {
            width: parent.width
            title: root.scanning ? "Networks (scanning)" : "Networks"
            Column {
                width: body.width - 14 * root.u
                spacing: 5 * root.u
                Win98ListView {
                    id: list
                    width: parent.width
                    height: root.listHeight
                    model: root.panel.networks
                    focus: true
                    showFocus: !root.asking
                    emptyText: !root.device ? "No Wi-Fi adapter is available."
                        : !root.panel.hardwareEnabled ? "The hardware radio switch blocks Wi-Fi."
                        : !root.panel.radioEnabled ? "Turn on Wi-Fi to find networks."
                        : root.scanning ? "Looking for networks..."
                        : "No networks found. Select Scan to try again."
                    Component.onCompleted: if (count > 0) currentIndex = 0
                    onCountChanged: {
                        if (count > 0 && currentIndex < 0) currentIndex = 0;
                        if (count === 0) currentIndex = -1;
                    }
                    onActivated: root.runCurrent()
                    delegate: Win98ListRow {
                        id: net
                        required property var modelData
                        readonly property int rung: modelData.signalStrength >= 0.75 ? 4 : modelData.signalStrength >= 0.5 ? 3
                            : modelData.signalStrength >= 0.25 ? 2 : 1
                        iconName: "wifi-" + rung
                        title: modelData.name
                        bold: modelData.connected
                        detail: (modelData.stateChanging ? "Connecting..." : modelData.connected ? "Connected"
                            : modelData.known ? "Known" : root.panel.securityLabel(modelData))
                            + " \u00b7 " + Math.round(modelData.signalStrength * 100) + "%"
                        trailing: modelData.security === WifiSecurityType.Open ? "" : "lock"
                        Connections {
                            target: net.modelData
                            ignoreUnknownSignals: true
                            function onConnectionFailed(reason): void { root.panel.failureMessage = root.panel.failureText(reason); }
                            function onConnectedChanged(): void { if (net.modelData.connected) root.panel.failureMessage = ""; }
                        }
                    }
                }
                Item {
                    visible: root.panel.failureMessage !== ""
                    width: parent.width
                    height: visible ? failText.height + 8 * root.u : 0
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: root.u
                        border.color: Kit.Win98Tokens.danger
                    }
                    Win98Text {
                        id: failText
                        x: 6 * root.u; y: 4 * root.u
                        width: parent.width - 12 * root.u
                        wrap: true
                        text: root.panel.failureMessage
                        accessMarks: false
                        color: Kit.Win98Tokens.danger
                    }
                }
                Item {
                    visible: root.asking
                    width: parent.width
                    height: visible ? 21 * root.u : 0
                    Win98Text {
                        id: passLabel
                        y: 4 * root.u
                        text: "&Password:"
                    }
                    Win98TextField {
                        id: password
                        x: passLabel.width + 6 * root.u
                        width: parent.width - x - connect.width - 6 * root.u
                        echoMode: TextInput.Password
                        onAccepted: root.submit()
                    }
                    Win98Button {
                        id: connect
                        x: parent.width - width
                        small: true
                        isDefault: true
                        text: "Connect"
                        enabled: password.text.length > 0
                        onClicked: root.submit()
                    }
                }
                Row {
                    x: parent.width - width
                    spacing: 6 * root.u
                    Win98Button {
                        small: true
                        isDefault: !root.asking
                        text: root.actionLabel(root.network)
                        enabled: root.network !== null && !root.network.stateChanging
                        onClicked: root.runCurrent()
                    }
                    Win98Button {
                        small: true
                        text: "&Forget"
                        enabled: !!root.network && root.network.known && !root.network.stateChanging
                        onClicked: root.forgetCurrent()
                    }
                }
            }
        }
        Item {
            id: statusArea
            visible: !root.dropStatus
            width: parent.width
            height: visible ? statusBar.height + 8 * root.u : 0
        Win98StatusBar {
            id: statusBar
            y: 8 * root.u
            width: parent.width
            panes: [root.panel.statusText, root.asking ? "Enter connect \u00b7 Esc cancel"
                : "\u2191\u2193 select \u00b7 Enter action \u00b7 S scan \u00b7 P power \u00b7 Shift+Del forget"]
        }
        }
    }

    Shortcut { sequences: ["Return", "Enter", "Space"]; context: Qt.WindowShortcut; enabled: !root.asking; onActivated: root.runCurrent() }
    Shortcut { sequence: "S"; context: Qt.WindowShortcut; enabled: !root.asking; onActivated: root.toggleScan() }
    Shortcut { sequence: "P"; context: Qt.WindowShortcut; enabled: !root.asking && root.panel.hardwareEnabled; onActivated: root.panel.setRadio(!root.panel.radioEnabled) }
    Shortcut { sequence: "Shift+Delete"; context: Qt.WindowShortcut; enabled: !root.asking; onActivated: root.forgetCurrent() }
}
