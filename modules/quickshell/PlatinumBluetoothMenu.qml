import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts


PlatinumMenuFrame {
    id: frame
    required property var panel

    preferredWidth: 380
    title: "Bluetooth"
    // The count the bar gives up first lives here.
    detail: panel.statusText
    scrolls: devices.scrolls

    // Every action button has one width, so the column of
    // Connect / Disconnect / Pair ends and starts on one line.
    readonly property real actionWidth: PlatinumMetrics.buttonWidth(["Pair", "Connect", "Disconnect", "Cancel"])

    PlatinumMenuCheckRow {
        text: "On"
        rightInset: frame.rightInset
        checked: panel.adapter ? panel.adapter.enabled : false
        enabled: panel.adapter !== null
        onToggled: function (checked) { panel.adapter.enabled = checked; }

        PlatinumButton {
            text: panel.adapter && panel.adapter.discovering ? "Stop" : "Scan"
            fixedWidth: frame.actionWidth
            enabled: panel.adapter !== null && panel.adapter.enabled
            onClicked: panel.adapter.discovering = !panel.adapter.discovering
        }
    }

    PlatinumMenuParts.Separator {}

    PlatinumMenuParts.Section {
        rightInset: frame.rightInset
        text: panel.adapter && panel.adapter.discovering ? "DEVICES · SCANNING" : "DEVICES"
    }

    PlatinumMenuParts.Empty {
        visible: panel.devices.length === 0
        rightInset: frame.rightInset
        text: {
            if (!panel.adapter) return "No Bluetooth adapter is available.";
            if (!panel.adapter.enabled) return "Turn on Bluetooth to find devices.";
            if (panel.adapter.discovering) return "Looking for devices…";
            return "No devices found. Select Scan to try again.";
        }
    }

    PlatinumMenuList {
        id: devices
        visible: panel.devices.length > 0
        model: ScriptModel { values: panel.devices }

        Component.onCompleted: view.forceActiveFocus()
        onCountChanged: {
            if (count > 0 && currentIndex < 0) currentIndex = 0;
            if (count === 0) currentIndex = -1;
        }

        delegate: PlatinumMenuListRow {
            id: deviceRow

            required property var modelData
            required property int index

            width: ListView.view.width
            rightInset: frame.rightInset
            selected: ListView.isCurrentItem
            mark: modelData.connected ? "dot" : "ring"
            markDim: !modelData.connected
            name: modelData.name || modelData.address
            detail: {
                const parts = [];
                if (deviceRow.pairFailed) parts.push("Pairing failed");
                else if (modelData.pairing) parts.push("Pairing…");
                else if (modelData.state === BluetoothDeviceState.Connecting) parts.push("Connecting…");
                else if (modelData.state === BluetoothDeviceState.Disconnecting) parts.push("Disconnecting…");
                else if (modelData.connected) parts.push("Connected");
                else if (modelData.paired) parts.push("Paired");
                else parts.push("Available");
                if (modelData.batteryAvailable) parts.push(Math.round(modelData.battery * 100) + "%");
                parts.push(modelData.address);
                return parts.join(" · ");
            }
            detailColor: deviceRow.pairFailed ? PlatinumTokens.menuDanger : PlatinumTokens.menuTextSecondary
            onEntered: devices.currentIndex = index

            property bool pairRequested: false
            property bool pairFailed: false

            readonly property string actionLabel: {
                if (modelData.pairing) return "Cancel";
                if (modelData.connected) return "Disconnect";
                if (modelData.paired) return "Connect";
                return "Pair";
            }

            function runAction() {
                if (modelData.pairing) {
                    modelData.cancelPair();
                } else if (modelData.connected) {
                    modelData.disconnect();
                } else if (modelData.paired) {
                    modelData.connect();
                } else {
                    deviceRow.pairRequested = true;
                    deviceRow.pairFailed = false;
                    modelData.pair();
                }
            }

            Connections {
                target: deviceRow.modelData
                ignoreUnknownSignals: true

                function onPairedChanged(): void {
                    if (deviceRow.modelData.paired) {
                        deviceRow.pairRequested = false;
                        deviceRow.pairFailed = false;
                        deviceRow.modelData.trusted = true;
                    }
                }

                function onPairingChanged(): void {
                    if (!deviceRow.modelData.pairing && deviceRow.pairRequested
                            && !deviceRow.modelData.paired) {
                        deviceRow.pairRequested = false;
                        deviceRow.pairFailed = true;
                    }
                }
            }

            // The forget slot stays when empty, so every action
            // button ends on the same right edge.
            Item {
                width: PlatinumTokens.menuButtonHeight
                height: PlatinumTokens.menuButtonHeight
                PlatinumButton {
                    anchors.fill: parent
                    visible: deviceRow.modelData.paired && !deviceRow.modelData.pairing
                    icon: "close"
                    onClicked: deviceRow.modelData.forget()
                }
            }

            PlatinumButton {
                text: deviceRow.actionLabel
                fixedWidth: frame.actionWidth
                onClicked: deviceRow.runAction()
            }
        }
    }

    PlatinumMenuParts.Hint {
        rightInset: frame.rightInset
        text: "↑↓ select · Enter action · S scan · P power · Shift+Del forget"
    }

    function runCurrent() {
        const row = devices.view.currentItem;
        if (row) row.runAction();
    }

    Shortcut { sequence: "Up"; context: Qt.WindowShortcut; onActivated: devices.moveSelection(-1) }
    Shortcut { sequence: "Down"; context: Qt.WindowShortcut; onActivated: devices.moveSelection(1) }
    Shortcut { sequence: "Return"; context: Qt.WindowShortcut; onActivated: frame.runCurrent() }
    Shortcut { sequence: "Enter"; context: Qt.WindowShortcut; onActivated: frame.runCurrent() }
    Shortcut { sequence: "Space"; context: Qt.WindowShortcut; onActivated: frame.runCurrent() }
    Shortcut {
        sequence: "S"
        context: Qt.WindowShortcut
        enabled: panel.adapter !== null && panel.adapter.enabled
        onActivated: panel.adapter.discovering = !panel.adapter.discovering
    }
    Shortcut {
        sequence: "P"
        context: Qt.WindowShortcut
        enabled: panel.adapter !== null
        onActivated: panel.adapter.enabled = !panel.adapter.enabled
    }
    Shortcut {
        sequence: "Shift+Delete"
        context: Qt.WindowShortcut
        onActivated: {
            const row = devices.view.currentItem;
            if (row && row.modelData.paired) row.modelData.forget();
        }
    }
}