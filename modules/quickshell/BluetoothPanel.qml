import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

// Bluetooth: the bar control's state and its menu. MenuHost shows the
// menu; this Scope owns the state, so the bar reads it while the menu is
// closed.
Scope {
    id: root

    // True while this screen shows the menu: discovery runs only then.
    property bool shown: false

    // Bluetooth.defaultAdapter, or a stand-in with the same shape.
    property var adapter: Bluetooth.defaultAdapter
    readonly property int connectedCount: root.devices.filter(function (device) {
        return device.connected;
    }).length
    readonly property var devices: {
        const adapter = root.adapter;
        if (!adapter || !adapter.devices) return [];
        const list = [...adapter.devices.values];
        list.sort(function (a, b) {
            const aRank = a.connected ? 0 : a.paired ? 1 : 2;
            const bRank = b.connected ? 0 : b.paired ? 1 : 2;
            if (aRank !== bRank) return aRank - bRank;
            return (a.name || a.address).localeCompare(b.name || b.address);
        });
        return list;
    }

    readonly property string statusText: {
        if (!root.adapter) return "No Bluetooth adapter";
        if (root.adapter.state === BluetoothAdapterState.Blocked) return "Blocked by radio switch";
        if (root.adapter.state === BluetoothAdapterState.Enabling) return "Turning on…";
        if (root.adapter.state === BluetoothAdapterState.Disabling) return "Turning off…";
        if (root.connectedCount === 1) return "1 device connected";
        if (root.connectedCount > 1) return root.connectedCount + " devices connected";
        return root.adapter.enabled ? "On" : "Off";
    }

    function stopDiscovery() {
        if (root.adapter && root.adapter.discovering)
            root.adapter.discovering = false;
    }

    onShownChanged: {
        if (!root.adapter) return;
        root.adapter.discovering = root.shown && root.adapter.enabled;
    }

    Connections {
        target: root.adapter
        function onEnabledChanged(): void {
            if (root.adapter && root.shown)
                root.adapter.discovering = root.adapter.enabled;
        }
    }

    property Component menu: Component {
        MenuFrame {
            id: frame

            preferredWidth: 380
            title: "Bluetooth"
            // The count the bar gives up first lives here.
            detail: root.statusText
            scrolls: devices.scrolls

            // Every action button has one width, so the column of
            // Connect / Disconnect / Pair ends and starts on one line.
            readonly property real actionWidth: PlatinumMetrics.buttonWidth(["Pair", "Connect", "Disconnect", "Cancel"])

            MenuCheckRow {
                text: "On"
                rightInset: frame.rightInset
                checked: root.adapter ? root.adapter.enabled : false
                enabled: root.adapter !== null
                onToggled: function (checked) { root.adapter.enabled = checked; }

                PlatinumButton {
                    text: root.adapter && root.adapter.discovering ? "Stop" : "Scan"
                    fixedWidth: frame.actionWidth
                    enabled: root.adapter !== null && root.adapter.enabled
                    onClicked: root.adapter.discovering = !root.adapter.discovering
                }
            }

            MenuParts.Separator {}

            MenuParts.Section {
                rightInset: frame.rightInset
                text: root.adapter && root.adapter.discovering ? "DEVICES · SCANNING" : "DEVICES"
            }

            MenuParts.Empty {
                visible: root.devices.length === 0
                rightInset: frame.rightInset
                text: {
                    if (!root.adapter) return "No Bluetooth adapter is available.";
                    if (!root.adapter.enabled) return "Turn on Bluetooth to find devices.";
                    if (root.adapter.discovering) return "Looking for devices…";
                    return "No devices found. Select Scan to try again.";
                }
            }

            MenuList {
                id: devices
                visible: root.devices.length > 0
                model: ScriptModel { values: root.devices }

                Component.onCompleted: view.forceActiveFocus()
                onCountChanged: {
                    if (count > 0 && currentIndex < 0) currentIndex = 0;
                    if (count === 0) currentIndex = -1;
                }

                delegate: MenuListRow {
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
                    detailColor: deviceRow.pairFailed ? Theme.menuDanger : Theme.menuTextSecondary
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
                        width: Theme.menuButtonHeight
                        height: Theme.menuButtonHeight
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

            MenuParts.Hint {
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
                enabled: root.adapter !== null && root.adapter.enabled
                onActivated: root.adapter.discovering = !root.adapter.discovering
            }
            Shortcut {
                sequence: "P"
                context: Qt.WindowShortcut
                enabled: root.adapter !== null
                onActivated: root.adapter.enabled = !root.adapter.enabled
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
    }
}
