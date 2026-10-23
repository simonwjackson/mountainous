pragma ComponentBehavior: Bound

import Quickshell.Bluetooth
import QtQuick

// Bluetooth as a Win98 window: the radio's check box and Scan, the devices
// in a list view, and Connect / Disconnect / Pair / Cancel and Forget for
// the selected device. The shared BluetoothPanel owns every value.
//
// Keys: Up/Down select, Enter or Space run the action, S scans, P turns
// the radio on or off, Shift+Del forgets.
Win98Window {
    id: root

    required property var panel

    readonly property var adapter: panel.adapter
    readonly property bool on: !!adapter && adapter.enabled
    readonly property bool scanning: !!adapter && adapter.discovering
    readonly property var row: list.view.currentItem
    readonly property var device: row ? row.modelData : null

    title: "Bluetooth"
    iconName: "bluetooth-on"
    onCloseClicked: MenuState.close()

    function runCurrent() { if (root.row) root.row.runAction(); }
    function forgetCurrent() { if (root.device && root.device.paired && !root.device.pairing) root.device.forget(); }
    function toggleScan() { if (root.on) root.adapter.discovering = !root.adapter.discovering; }
    function togglePower() { if (root.adapter) root.adapter.enabled = !root.adapter.enabled; }

    Column {
        id: body
        width: root.width - 22 * root.u

        Item {
            width: parent.width
            height: 21 * root.u
            Win98CheckBox {
                y: 4 * root.u
                text: "Bluetooth &on"
                enabled: root.adapter !== null
                checked: root.on
                onToggled: root.togglePower()
            }
            Win98Button {
                x: parent.width - width
                small: true
                text: root.scanning ? "&Stop" : "&Scan"
                enabled: root.on
                onClicked: root.toggleScan()
            }
        }
        Item { width: 1; height: 3 * root.u }
        Win98GroupBox {
            width: parent.width
            title: root.scanning ? "Devices (scanning)" : "Devices"
            Column {
                width: body.width - 14 * root.u
                spacing: 5 * root.u
                Win98ListView {
                    id: list
                    width: parent.width
                    height: 140 * root.u
                    model: root.panel.devices
                    focus: true
                    showFocus: true
                    emptyText: !root.adapter ? "No Bluetooth adapter is available."
                        : !root.adapter.enabled ? "Turn on Bluetooth to find devices."
                        : root.scanning ? "Looking for devices..."
                        : "No devices found. Select Scan to try again."
                    Component.onCompleted: if (count > 0) currentIndex = 0
                    onCountChanged: {
                        if (count > 0 && currentIndex < 0) currentIndex = 0;
                        if (count === 0) currentIndex = -1;
                    }
                    onActivated: root.runCurrent()
                    delegate: Win98ListRow {
                        id: dev
                        required property var modelData
                        property bool pairRequested: false
                        property bool pairFailedHere: false
                        // A harness can show the failure on a stand-in device.
                        readonly property bool pairFailed: pairFailedHere || modelData.pairFailed === true
                        iconName: modelData.connected ? "bluetooth-on" : "bluetooth-off"
                        title: modelData.name || modelData.address
                        bold: modelData.connected
                        detailColor: pairFailed && !selected ? Win98Tokens.danger : Win98Tokens.gray
                        detail: {
                            const parts = [];
                            if (dev.pairFailed) parts.push("Pairing failed");
                            else if (modelData.pairing) parts.push("Pairing...");
                            else if (modelData.state === BluetoothDeviceState.Connecting) parts.push("Connecting...");
                            else if (modelData.state === BluetoothDeviceState.Disconnecting) parts.push("Disconnecting...");
                            else if (modelData.connected) parts.push("Connected");
                            else if (modelData.paired) parts.push("Paired");
                            else parts.push("Available");
                            if (modelData.batteryAvailable) parts.push(Math.round(modelData.battery * 100) + "%");
                            parts.push(modelData.address);
                            return parts.join(" \u00b7 ");
                        }
                        readonly property string actionLabel: modelData.pairing ? "Cancel"
                            : modelData.connected ? "Disconnect" : modelData.paired ? "Connect" : "Pair"
                        function runAction() {
                            if (modelData.pairing) modelData.cancelPair();
                            else if (modelData.connected) modelData.disconnect();
                            else if (modelData.paired) modelData.connect();
                            else { dev.pairRequested = true; dev.pairFailedHere = false; modelData.pair(); }
                        }
                        Connections {
                            target: dev.modelData
                            ignoreUnknownSignals: true
                            function onPairedChanged(): void {
                                if (!dev.modelData.paired) return;
                                dev.pairRequested = false;
                                dev.pairFailedHere = false;
                                dev.modelData.trusted = true;
                            }
                            function onPairingChanged(): void {
                                if (!dev.modelData.pairing && dev.pairRequested && !dev.modelData.paired) {
                                    dev.pairRequested = false;
                                    dev.pairFailedHere = true;
                                }
                            }
                        }
                    }
                }
                Row {
                    x: parent.width - width
                    spacing: 6 * root.u
                    Win98Button {
                        small: true
                        isDefault: true
                        text: root.row ? root.row.actionLabel : "Connect"
                        enabled: root.device !== null
                        onClicked: root.runCurrent()
                    }
                    Win98Button {
                        small: true
                        text: "&Forget"
                        enabled: !!root.device && root.device.paired && !root.device.pairing
                        onClicked: root.forgetCurrent()
                    }
                }
            }
        }
        Item { width: 1; height: 8 * root.u }
        Win98StatusBar {
            width: parent.width
            panes: [root.panel.statusText.replace(/\u2026/g, "..."), "\u2191\u2193 select \u00b7 Enter action \u00b7 S scan \u00b7 P power \u00b7 Shift+Del forget"]
        }
    }

    Shortcut { sequences: ["Return", "Enter", "Space"]; context: Qt.WindowShortcut; onActivated: root.runCurrent() }
    Shortcut { sequence: "S"; context: Qt.WindowShortcut; onActivated: root.toggleScan() }
    Shortcut { sequence: "P"; context: Qt.WindowShortcut; onActivated: root.togglePower() }
    Shortcut { sequence: "Shift+Delete"; context: Qt.WindowShortcut; onActivated: root.forgetCurrent() }
}
