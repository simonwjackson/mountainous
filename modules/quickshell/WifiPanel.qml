import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

// Wi-Fi: the bar control's state and its menu. MenuHost shows the menu.
Scope {
    id: root

    // True while this screen shows the menu: the scanner runs only then.
    property bool shown: false

    // The radio switches, as NetworkManager reports them.
    property bool radioEnabled: Networking.wifiEnabled
    property bool hardwareEnabled: Networking.wifiHardwareEnabled
    function setRadio(on) { Networking.wifiEnabled = on; }

    property var device: {
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

    readonly property string statusText: {
        if (!root.device) return "No Wi-Fi adapter";
        if (!root.hardwareEnabled) return "Blocked by radio switch";
        if (!root.radioEnabled) return "Off";
        if (root.connectedNetwork) return root.connectedNetwork.name;
        return "Not connected";
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
        } else {
            network.connect();
        }
    }

    function submitPassword(password) {
        if (!root.passwordNetwork || password.length === 0) return;
        root.failureMessage = "";
        root.passwordNetwork.connectWithPsk(password);
        root.passwordNetwork = null;
    }

    // The menu clears its field and takes the list's focus back when
    // passwordNetwork goes null.
    function cancelPassword() {
        root.passwordNetwork = null;
    }

    onShownChanged: {
        root.failureMessage = "";
        root.passwordNetwork = null;
        if (root.device)
            root.device.scannerEnabled = root.shown && root.radioEnabled;
    }

    onRadioEnabledChanged: {
        if (!root.radioEnabled) root.cancelPassword();
        if (root.device && root.shown)
            root.device.scannerEnabled = root.radioEnabled;
    }

    property Component menu: Component {
        MenuFrame {
            id: frame

            preferredWidth: 380
            title: "Wi-Fi"
            detail: root.statusText
            scrolls: networks.scrolls

            readonly property real actionWidth: PlatinumMetrics.buttonWidth(["Connect", "Disconnect", "Set up", "Working"])
            readonly property bool asking: root.passwordNetwork !== null

            // Escape leaves the password field before it closes the menu.
            function cancel() {
                if (!frame.asking) return false;
                root.cancelPassword();
                return true;
            }

            function submit() {
                root.submitPassword(passwordInput.text);
                passwordInput.text = "";
            }

            Connections {
                target: root
                function onPasswordNetworkChanged(): void {
                    if (root.passwordNetwork !== null) {
                        Qt.callLater(function () { passwordInput.forceActiveFocus(); });
                    } else {
                        passwordInput.text = "";
                        networks.view.forceActiveFocus();
                    }
                }
            }

            MenuCheckRow {
                text: "On"
                rightInset: frame.rightInset
                checked: root.radioEnabled
                enabled: root.hardwareEnabled
                onToggled: function (checked) { root.setRadio(checked); }

                PlatinumButton {
                    text: root.device && root.device.scannerEnabled ? "Stop" : "Scan"
                    fixedWidth: frame.actionWidth
                    enabled: root.device !== null && root.radioEnabled
                    onClicked: root.device.scannerEnabled = !root.device.scannerEnabled
                }
            }

            MenuParts.Separator {}

            MenuParts.Section {
                rightInset: frame.rightInset
                text: root.device && root.device.scannerEnabled ? "NETWORKS · SCANNING" : "NETWORKS"
            }

            MenuParts.Empty {
                visible: root.networks.length === 0
                rightInset: frame.rightInset
                text: {
                    if (!root.device) return "No Wi-Fi adapter is available.";
                    if (!root.hardwareEnabled) return "The hardware radio switch blocks Wi-Fi.";
                    if (!root.radioEnabled) return "Turn on Wi-Fi to find networks.";
                    if (root.device.scannerEnabled) return "Looking for networks…";
                    return "No networks found. Select Scan to try again.";
                }
            }

            MenuList {
                id: networks
                visible: root.networks.length > 0
                model: ScriptModel { values: root.networks }

                Component.onCompleted: view.forceActiveFocus()
                onCountChanged: {
                    if (count > 0 && currentIndex < 0) currentIndex = 0;
                    if (count === 0) currentIndex = -1;
                }

                delegate: MenuListRow {
                    id: networkRow

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    rightInset: frame.rightInset
                    selected: ListView.isCurrentItem && !frame.asking
                    mark: modelData.connected ? "dot" : "ring"
                    markDim: !modelData.connected
                    name: modelData.name
                    detail: {
                        const parts = [];
                        if (modelData.state === ConnectionState.Connecting) parts.push("Connecting…");
                        else if (modelData.state === ConnectionState.Disconnecting) parts.push("Disconnecting…");
                        else if (modelData.connected) parts.push("Connected");
                        else if (modelData.known) parts.push("Known");
                        else parts.push(root.securityLabel(modelData));
                        parts.push(Math.round(modelData.signalStrength * 100) + "%");
                        return parts.join(" · ");
                    }
                    onEntered: networks.currentIndex = index

                    readonly property string actionLabel: {
                        if (modelData.stateChanging) return "Working";
                        if (modelData.connected) return "Disconnect";
                        if (root.isEnterprise(modelData) && !modelData.known) return "Set up";
                        return "Connect";
                    }

                    function runAction() { root.runNetworkAction(modelData); }

                    Connections {
                        target: networkRow.modelData
                        ignoreUnknownSignals: true

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

                    Item {
                        width: 14
                        height: Theme.menuButtonHeight
                        PlatinumIcon {
                            anchors.centerIn: parent
                            visible: networkRow.modelData.security !== WifiSecurityType.Open
                                && networkRow.modelData.security !== WifiSecurityType.Owe
                            name: "lock"
                            size: 12
                            color: networkRow.fg2
                        }
                    }

                    Item {
                        width: Theme.menuButtonHeight
                        height: Theme.menuButtonHeight
                        PlatinumButton {
                            anchors.fill: parent
                            visible: networkRow.modelData.known && !networkRow.modelData.stateChanging
                            icon: "close"
                            onClicked: networkRow.modelData.forget()
                        }
                    }

                    PlatinumButton {
                        text: networkRow.actionLabel
                        fixedWidth: frame.actionWidth
                        enabled: !networkRow.modelData.stateChanging
                        onClicked: networkRow.runAction()
                    }
                }
            }

            // A failure, said in full on the grid.
            Rectangle {
                visible: root.failureMessage !== ""
                Layout.fillWidth: true
                Layout.leftMargin: Theme.menuTextLeft
                Layout.rightMargin: frame.rightInset
                Layout.topMargin: 4
                implicitHeight: failureText.implicitHeight + 10
                color: "transparent"
                border.width: Theme.hair
                border.color: Theme.menuDanger

                Text {
                    id: failureText
                    x: 8
                    width: parent.width - 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.failureMessage
                    wrapMode: Text.Wrap
                    color: Theme.menuDanger
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumSmall
                    font.letterSpacing: Theme.platinumTracking
                }
            }

            // The password for a secured network: the field on the text
            // edge, Connect on the right edge, as wide as every action.
            Item {
                visible: frame.asking
                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: 30

                Bevel {
                    x: Theme.menuTextLeft
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - frame.rightInset - frame.actionWidth - Theme.menuGap
                    height: 24
                    sunken: true
                    edged: false
                    color: Theme.well

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text === ""
                        text: root.passwordNetwork ? "Password for " + root.passwordNetwork.name : "Password"
                        elide: Text.ElideRight
                        color: Theme.menuTextOff
                        font.family: Theme.platinumFont
                        font.pixelSize: Theme.platinumSmall
                    }

                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.menuText
                        selectionColor: Theme.highlight
                        selectedTextColor: Theme.highlightText
                        font.family: Theme.platinumFont
                        font.pixelSize: Theme.platinumSmall
                        Keys.onReturnPressed: frame.submit()
                        Keys.onEnterPressed: frame.submit()
                    }
                }

                PlatinumButton {
                    anchors.right: parent.right
                    anchors.rightMargin: frame.rightInset
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Connect"
                    isDefault: true
                    fixedWidth: frame.actionWidth - 4 * Theme.hair
                    enabled: passwordInput.text.length > 0
                    onClicked: frame.submit()
                }
            }

            MenuParts.Hint {
                rightInset: frame.rightInset
                text: frame.asking ? "Enter connect · Esc cancel"
                    : "↑↓ select · Enter action · S scan · P power · Shift+Del forget"
            }

            function runCurrent() {
                const row = networks.view.currentItem;
                if (row) row.runAction();
            }

            Shortcut { sequence: "Up"; context: Qt.WindowShortcut; enabled: !frame.asking; onActivated: networks.moveSelection(-1) }
            Shortcut { sequence: "Down"; context: Qt.WindowShortcut; enabled: !frame.asking; onActivated: networks.moveSelection(1) }
            Shortcut { sequence: "Return"; context: Qt.WindowShortcut; enabled: !frame.asking; onActivated: frame.runCurrent() }
            Shortcut { sequence: "Enter"; context: Qt.WindowShortcut; enabled: !frame.asking; onActivated: frame.runCurrent() }
            Shortcut { sequence: "Space"; context: Qt.WindowShortcut; enabled: !frame.asking; onActivated: frame.runCurrent() }
            Shortcut {
                sequence: "S"
                context: Qt.WindowShortcut
                enabled: !frame.asking && root.device !== null && root.radioEnabled
                onActivated: root.device.scannerEnabled = !root.device.scannerEnabled
            }
            Shortcut {
                sequence: "P"
                context: Qt.WindowShortcut
                enabled: !frame.asking && root.hardwareEnabled
                onActivated: root.setRadio(!root.radioEnabled)
            }
            Shortcut {
                sequence: "Shift+Delete"
                context: Qt.WindowShortcut
                enabled: !frame.asking
                onActivated: {
                    const row = networks.view.currentItem;
                    if (row && row.modelData.known) row.modelData.forget();
                }
            }
        }
    }
}
