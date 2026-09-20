import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    required property var screen
    property bool shown: false
    signal closeRequested

    readonly property var adapter: Bluetooth.defaultAdapter
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

    function layoutPlan(width, height) {
        return {
            cardWidth: Math.min(360, Math.max(0, width - 12)),
            cardHeight: Math.min(520, Math.max(150, height - 44)),
            showAddress: width >= 310,
            rowHeight: height < 320 ? 48 : 56
        };
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

    LazyLoader {
        active: root.shown

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

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeRequested()
            }

            Rectangle {
                id: card

                readonly property var plan: root.layoutPlan(veil.width, veil.height)

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 32
                anchors.rightMargin: 6
                width: plan.cardWidth
                height: plan.cardHeight
                radius: Theme.radiusLarge
                color: Theme.bgPanel
                border.width: 1
                border.color: Theme.borderMuted

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: "Bluetooth"
                            color: Theme.textPrimary
                            font.pixelSize: 14
                            font.family: Theme.fontFamily
                            font.bold: true
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: Theme.radiusSmall
                            color: closeArea.containsMouse ? Theme.bgSelected : "transparent"

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

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!root.adapter) return "No Bluetooth adapter";
                                if (root.adapter.state === BluetoothAdapterState.Blocked)
                                    return "Blocked by radio switch";
                                if (root.adapter.state === BluetoothAdapterState.Enabling)
                                    return "Turning on…";
                                if (root.adapter.state === BluetoothAdapterState.Disabling)
                                    return "Turning off…";
                                if (root.connectedCount === 1) return "1 device connected";
                                if (root.connectedCount > 1)
                                    return root.connectedCount + " devices connected";
                                return root.adapter.enabled ? "On" : "Off";
                            }
                            elide: Text.ElideRight
                            color: Theme.textMuted
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                        }

                        Rectangle {
                            Layout.preferredWidth: 58
                            Layout.preferredHeight: 28
                            radius: Theme.radiusSmall
                            color: scanArea.containsMouse ? Theme.bgSelected : "transparent"
                            opacity: root.adapter && root.adapter.enabled ? 1.0 : 0.45

                            Text {
                                anchors.centerIn: parent
                                text: root.adapter && root.adapter.discovering ? "Stop" : "Scan"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                                font.family: Theme.fontFamily
                            }

                            MouseArea {
                                id: scanArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: root.adapter && root.adapter.enabled
                                onClicked: root.adapter.discovering = !root.adapter.discovering
                            }
                        }

                        TogglePill {
                            checked: root.adapter ? root.adapter.enabled : false
                            enabled: root.adapter !== null
                            onToggled: function (checked) {
                                root.adapter.enabled = checked;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.bgSeparator
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.adapter && root.adapter.discovering
                            ? "DEVICES · SCANNING"
                            : "DEVICES"
                        color: Theme.textDim
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                    }

                    ListView {
                        id: deviceList

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        focus: true
                        keyNavigationWraps: true
                        highlightMoveDuration: 80
                        model: ScriptModel { values: root.devices }

                        Component.onCompleted: forceActiveFocus()
                        onCountChanged: {
                            if (count > 0 && currentIndex < 0) currentIndex = 0;
                            if (count === 0) currentIndex = -1;
                        }

                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_Escape) {
                                root.closeRequested();
                            } else if (event.key === Qt.Key_S && root.adapter && root.adapter.enabled) {
                                root.adapter.discovering = !root.adapter.discovering;
                            } else if (event.key === Qt.Key_P && root.adapter) {
                                root.adapter.enabled = !root.adapter.enabled;
                            } else if ((event.key === Qt.Key_Return
                                        || event.key === Qt.Key_Enter
                                        || event.key === Qt.Key_Space)
                                       && currentItem) {
                                currentItem.runAction();
                            } else if (event.key === Qt.Key_Delete
                                       && (event.modifiers & Qt.ShiftModifier)
                                       && currentItem
                                       && currentItem.modelData.paired) {
                                currentItem.modelData.forget();
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }

                        delegate: Rectangle {
                            id: deviceRow

                            required property var modelData
                            required property int index

                            width: deviceList.width
                            height: card.plan.rowHeight
                            radius: Theme.radiusSmall
                            color: deviceRow.ListView.isCurrentItem
                                ? Theme.bgActive
                                : rowArea.containsMouse ? Theme.bgSelected : "transparent"

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

                                function onPairedChanged(): void {
                                    if (deviceRow.modelData.paired) {
                                        deviceRow.pairRequested = false;
                                        deviceRow.pairFailed = false;
                                        deviceRow.modelData.trusted = true;
                                    }
                                }

                                function onPairingChanged(): void {
                                    if (!deviceRow.modelData.pairing
                                            && deviceRow.pairRequested
                                            && !deviceRow.modelData.paired) {
                                        deviceRow.pairRequested = false;
                                        deviceRow.pairFailed = true;
                                    }
                                }
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 6

                                Text {
                                    Layout.preferredWidth: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.connected ? "●" : "○"
                                    color: modelData.connected ? Theme.accent : Theme.textDim
                                    font.pixelSize: 11
                                    font.family: Theme.fontFamily
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || modelData.address
                                        elide: Text.ElideRight
                                        color: Theme.textPrimary
                                        font.pixelSize: 12
                                        font.family: Theme.fontFamily
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: {
                                            const parts = [];
                                            if (deviceRow.pairFailed) parts.push("Pairing failed");
                                            else if (modelData.pairing) parts.push("Pairing…");
                                            else if (modelData.state === BluetoothDeviceState.Connecting)
                                                parts.push("Connecting…");
                                            else if (modelData.state === BluetoothDeviceState.Disconnecting)
                                                parts.push("Disconnecting…");
                                            else if (modelData.connected) parts.push("Connected");
                                            else if (modelData.paired) parts.push("Paired");
                                            else parts.push("Available");
                                            if (modelData.batteryAvailable)
                                                parts.push(Math.round(modelData.battery * 100) + "%");
                                            if (card.plan.showAddress) parts.push(modelData.address);
                                            return parts.join(" · ");
                                        }
                                        elide: Text.ElideRight
                                        color: Theme.textDetail
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: deviceRow.actionLabel === "Disconnect" ? 82 : 62
                                    Layout.preferredHeight: 28
                                    radius: Theme.radiusSmall
                                    color: actionArea.containsMouse ? Theme.bgActive : Theme.bgSelected

                                    Text {
                                        anchors.centerIn: parent
                                        text: deviceRow.actionLabel
                                        color: Theme.textSecondary
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                    }

                                    MouseArea {
                                        id: actionArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: deviceRow.runAction()
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    visible: modelData.paired && !modelData.pairing
                                    radius: Theme.radiusSmall
                                    color: forgetArea.containsMouse ? Theme.bgActive : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: Theme.textMuted
                                        font.pixelSize: 14
                                        font.family: Theme.fontFamily
                                    }

                                    MouseArea {
                                        id: forgetArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: modelData.forget()
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            width: Math.max(0, parent.width - 24)
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            visible: root.devices.length === 0
                            text: {
                                if (!root.adapter) return "No Bluetooth adapter is available.";
                                if (!root.adapter.enabled)
                                    return "Turn on Bluetooth to find devices.";
                                if (root.adapter.discovering) return "Looking for devices…";
                                return "No devices found. Select Scan to try again.";
                            }
                            color: Theme.textMuted
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        text: "↑↓ select · Enter action · S scan · P power · Shift+Del forget"
                        elide: Text.ElideRight
                        color: Theme.textDetail
                        font.pixelSize: 9
                        font.family: Theme.fontFamily
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: root.closeRequested()
            }
        }
    }
}
