import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    required property var screen
    property bool shown: false
    signal closeRequested

    readonly property var device: {
        if (!Networking.devices) return null;
        const devices = [...Networking.devices.values].filter(function (candidate) {
            return candidate.type === DeviceType.Wifi;
        });
        return devices.length > 0 ? devices[0] : null;
    }
    readonly property var connectedNetwork: root.networks.find(function (network) {
        return network.connected;
    }) || null
    readonly property var networks: {
        const device = root.device;
        if (!device || !device.networks) return [];
        const list = [...device.networks.values];
        list.sort(function (a, b) {
            const aRank = a.connected ? 0 : a.known ? 1 : 2;
            const bRank = b.connected ? 0 : b.known ? 1 : 2;
            if (aRank !== bRank) return aRank - bRank;
            if (a.signalStrength !== b.signalStrength)
                return b.signalStrength - a.signalStrength;
            return a.name.localeCompare(b.name);
        });
        return list;
    }

    property var passwordNetwork: null
    property string failureMessage: ""

    function layoutPlan(width, height) {
        return {
            cardWidth: Math.min(360, Math.max(0, width - 12)),
            cardHeight: Math.min(520, Math.max(170, height - 44)),
            showDetails: width >= 310,
            rowHeight: height < 320 ? 48 : 56
        };
    }

    function isEnterprise(network) {
        return network.security === WifiSecurityType.Wpa3SuiteB192
            || network.security === WifiSecurityType.Wpa2Eap
            || network.security === WifiSecurityType.WpaEap
            || network.security === WifiSecurityType.Leap;
    }

    function needsPassword(network) {
        return !network.known
            && network.security !== WifiSecurityType.Open
            && network.security !== WifiSecurityType.Owe
            && !root.isEnterprise(network);
    }

    function securityLabel(network) {
        if (network.security === WifiSecurityType.Open) return "Open";
        if (network.security === WifiSecurityType.Owe) return "Enhanced open";
        if (root.isEnterprise(network)) return "Enterprise";
        return "Secured";
    }

    function failureText(reason) {
        if (reason === ConnectionFailReason.NoSecrets) return "A password is required.";
        if (reason === ConnectionFailReason.WifiAuthTimeout) return "Authentication timed out.";
        if (reason === ConnectionFailReason.WifiNetworkLost) return "The network disappeared.";
        return "Connection failed.";
    }

    function runNetworkAction(network) {
        root.failureMessage = "";
        if (network.stateChanging) return;
        if (network.connected) {
            network.disconnect();
        } else if (root.isEnterprise(network) && !network.known) {
            root.failureMessage = "Enterprise Wi-Fi needs NetworkManager setup.";
        } else if (root.needsPassword(network)) {
            root.passwordNetwork = network;
            Qt.callLater(function () { passwordInput.forceActiveFocus(); });
        } else {
            network.connect();
        }
    }

    function submitPassword() {
        if (!root.passwordNetwork || passwordInput.text.length === 0) return;
        root.failureMessage = "";
        root.passwordNetwork.connectWithPsk(passwordInput.text);
        passwordInput.text = "";
        root.passwordNetwork = null;
    }

    function cancelPassword() {
        if (passwordInput) passwordInput.text = "";
        root.passwordNetwork = null;
        if (networkList) networkList.forceActiveFocus();
    }

    onShownChanged: {
        root.failureMessage = "";
        root.passwordNetwork = null;
        if (root.device)
            root.device.scannerEnabled = root.shown && Networking.wifiEnabled;
    }

    Connections {
        target: Networking
        function onWifiEnabledChanged(): void {
            if (!Networking.wifiEnabled) root.cancelPassword();
            if (root.device && root.shown)
                root.device.scannerEnabled = Networking.wifiEnabled;
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
                            text: "Wi-Fi"
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
                                if (!root.device) return "No Wi-Fi adapter";
                                if (!Networking.wifiHardwareEnabled) return "Blocked by radio switch";
                                if (!Networking.wifiEnabled) return "Off";
                                if (root.connectedNetwork) return root.connectedNetwork.name;
                                return "Not connected";
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
                            opacity: root.device && Networking.wifiEnabled ? 1.0 : 0.45

                            Text {
                                anchors.centerIn: parent
                                text: root.device && root.device.scannerEnabled ? "Stop" : "Scan"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                                font.family: Theme.fontFamily
                            }

                            MouseArea {
                                id: scanArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: root.device && Networking.wifiEnabled
                                onClicked: root.device.scannerEnabled = !root.device.scannerEnabled
                            }
                        }

                        TogglePill {
                            checked: Networking.wifiEnabled
                            enabled: Networking.wifiHardwareEnabled
                            onToggled: function (checked) {
                                Networking.wifiEnabled = checked;
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
                        text: root.device && root.device.scannerEnabled
                            ? "NETWORKS · SCANNING"
                            : "NETWORKS"
                        color: Theme.textDim
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                    }

                    ListView {
                        id: networkList

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        focus: true
                        keyNavigationWraps: true
                        highlightMoveDuration: 80
                        model: ScriptModel { values: root.networks }

                        Component.onCompleted: forceActiveFocus()
                        onCountChanged: {
                            if (count > 0 && currentIndex < 0) currentIndex = 0;
                            if (count === 0) currentIndex = -1;
                        }

                        function moveSelection(offset) {
                            if (count === 0) return;
                            currentIndex = (currentIndex + offset + count) % count;
                            positionViewAtIndex(currentIndex, ListView.Contain);
                        }

                        function runCurrentAction() {
                            if (currentItem) currentItem.runAction();
                        }

                        function forgetCurrentNetwork() {
                            if (currentItem && currentItem.modelData.known)
                                currentItem.modelData.forget();
                        }

                        delegate: Rectangle {
                            id: networkRow

                            required property var modelData
                            required property int index

                            width: networkList.width
                            height: card.plan.rowHeight
                            radius: Theme.radiusSmall
                            color: networkRow.ListView.isCurrentItem
                                ? Theme.bgActive
                                : rowArea.containsMouse ? Theme.bgSelected : "transparent"

                            readonly property string actionLabel: {
                                if (modelData.stateChanging) return "Working";
                                if (modelData.connected) return "Disconnect";
                                if (root.isEnterprise(modelData) && !modelData.known) return "Set up";
                                return "Connect";
                            }

                            function runAction() {
                                root.runNetworkAction(modelData);
                            }

                            Connections {
                                target: networkRow.modelData

                                function onConnectionFailed(reason): void {
                                    root.failureMessage = root.failureText(reason);
                                }

                                function onConnectedChanged(): void {
                                    if (networkRow.modelData.connected) {
                                        root.failureMessage = "";
                                        root.cancelPassword();
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
                                        text: modelData.name
                                        elide: Text.ElideRight
                                        color: Theme.textPrimary
                                        font.pixelSize: 12
                                        font.family: Theme.fontFamily
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: {
                                            const parts = [];
                                            if (modelData.state === ConnectionState.Connecting)
                                                parts.push("Connecting…");
                                            else if (modelData.state === ConnectionState.Disconnecting)
                                                parts.push("Disconnecting…");
                                            else if (modelData.connected) parts.push("Connected");
                                            else if (modelData.known) parts.push("Known");
                                            else parts.push(root.securityLabel(modelData));
                                            if (card.plan.showDetails)
                                                parts.push(Math.round(modelData.signalStrength * 100) + "%");
                                            return parts.join(" · ");
                                        }
                                        elide: Text.ElideRight
                                        color: Theme.textDetail
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 18
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.security === WifiSecurityType.Open ? "" : "⌑"
                                    color: Theme.textMuted
                                    font.pixelSize: 12
                                    font.family: Theme.fontFamily
                                }

                                Rectangle {
                                    Layout.preferredWidth: networkRow.actionLabel === "Disconnect" ? 82 : 66
                                    Layout.preferredHeight: 28
                                    radius: Theme.radiusSmall
                                    color: actionArea.containsMouse ? Theme.bgActive : Theme.bgSelected
                                    opacity: modelData.stateChanging ? 0.45 : 1.0

                                    Text {
                                        anchors.centerIn: parent
                                        text: networkRow.actionLabel
                                        color: Theme.textSecondary
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                    }

                                    MouseArea {
                                        id: actionArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !modelData.stateChanging
                                        onClicked: networkRow.runAction()
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    visible: modelData.known && !modelData.stateChanging
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
                            visible: root.networks.length === 0
                            text: {
                                if (!root.device) return "No Wi-Fi adapter is available.";
                                if (!Networking.wifiHardwareEnabled)
                                    return "The hardware radio switch blocks Wi-Fi.";
                                if (!Networking.wifiEnabled)
                                    return "Turn on Wi-Fi to find networks.";
                                if (root.device.scannerEnabled) return "Looking for networks…";
                                return "No networks found. Select Scan to try again.";
                            }
                            color: Theme.textMuted
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.failureMessage !== ""
                        text: root.failureMessage
                        elide: Text.ElideRight
                        color: Theme.danger
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        visible: root.passwordNetwork !== null
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSmall
                            color: Theme.bgInput
                            border.width: 1
                            border.color: passwordInput.activeFocus ? Theme.accent : Theme.borderMuted

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: passwordInput.text === ""
                                text: root.passwordNetwork
                                    ? "Password for " + root.passwordNetwork.name
                                    : "Password"
                                color: Theme.textDim
                                font.pixelSize: 11
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight
                                width: parent.width - 16
                            }

                            TextInput {
                                id: passwordInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                color: Theme.textInput
                                selectionColor: Theme.accent
                                font.pixelSize: 11
                                font.family: Theme.fontFamily

                                Keys.onReturnPressed: root.submitPassword()
                                Keys.onEnterPressed: root.submitPassword()
                                Keys.onEscapePressed: root.cancelPassword()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 66
                            Layout.fillHeight: true
                            radius: Theme.radiusSmall
                            color: connectArea.containsMouse ? Theme.bgActive : Theme.bgSelected
                            opacity: passwordInput.text.length > 0 ? 1.0 : 0.45

                            Text {
                                anchors.centerIn: parent
                                text: "Connect"
                                color: Theme.textSecondary
                                font.pixelSize: 10
                                font.family: Theme.fontFamily
                            }

                            MouseArea {
                                id: connectArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: passwordInput.text.length > 0
                                onClicked: root.submitPassword()
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        text: root.passwordNetwork
                            ? "Enter connect · Esc cancel"
                            : "↑↓ select · Enter action · S scan · P power · Shift+Del forget"
                        elide: Text.ElideRight
                        color: Theme.textDetail
                        font.pixelSize: 9
                        font.family: Theme.fontFamily
                    }
                }
            }

            Shortcut {
                sequence: "Up"
                context: Qt.WindowShortcut
                enabled: root.passwordNetwork === null
                onActivated: networkList.moveSelection(-1)
            }

            Shortcut {
                sequence: "Down"
                context: Qt.WindowShortcut
                enabled: root.passwordNetwork === null
                onActivated: networkList.moveSelection(1)
            }

            Shortcut {
                sequence: "Return"
                context: Qt.WindowShortcut
                enabled: root.passwordNetwork === null
                onActivated: networkList.runCurrentAction()
            }

            Shortcut {
                sequence: "Enter"
                context: Qt.WindowShortcut
                enabled: root.passwordNetwork === null
                onActivated: networkList.runCurrentAction()
            }

            Shortcut {
                sequence: "Space"
                context: Qt.WindowShortcut
                enabled: root.passwordNetwork === null
                onActivated: networkList.runCurrentAction()
            }

            Shortcut {
                sequence: "S"
                context: Qt.WindowShortcut
                enabled: root.passwordNetwork === null
                    && root.device !== null
                    && Networking.wifiEnabled
                onActivated: root.device.scannerEnabled = !root.device.scannerEnabled
            }

            Shortcut {
                sequence: "P"
                context: Qt.WindowShortcut
                enabled: root.passwordNetwork === null
                    && Networking.wifiHardwareEnabled
                onActivated: Networking.wifiEnabled = !Networking.wifiEnabled
            }

            Shortcut {
                sequence: "Shift+Delete"
                context: Qt.WindowShortcut
                enabled: root.passwordNetwork === null
                onActivated: networkList.forgetCurrentNetwork()
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                enabled: root.passwordNetwork === null
                onActivated: root.closeRequested()
            }
        }
    }
}
