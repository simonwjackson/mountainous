import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts


PlatinumMenuFrame {
    id: frame
    required property var panel

    preferredWidth: 380
    title: "Wi-Fi"
    detail: panel.statusText
    scrolls: networks.scrolls

    readonly property real actionWidth: PlatinumMetrics.buttonWidth(["Connect", "Disconnect", "Set up", "Working"])
    readonly property bool asking: panel.passwordNetwork !== null

    // Escape leaves the password field before it closes the menu.
    function cancel() {
        if (!frame.asking) return false;
        panel.cancelPassword();
        return true;
    }

    function submit() {
        panel.submitPassword(passwordInput.text);
        passwordInput.text = "";
    }

    Connections {
        target: frame.panel
        function onPasswordNetworkChanged(): void {
            if (panel.passwordNetwork !== null) {
                Qt.callLater(function () { passwordInput.forceActiveFocus(); });
            } else {
                passwordInput.text = "";
                networks.view.forceActiveFocus();
            }
        }
    }

    PlatinumMenuCheckRow {
        text: "On"
        rightInset: frame.rightInset
        checked: panel.radioEnabled
        enabled: panel.hardwareEnabled
        onToggled: function (checked) { panel.setRadio(checked); }

        PlatinumButton {
            text: panel.device && panel.device.scannerEnabled ? "Stop" : "Scan"
            fixedWidth: frame.actionWidth
            enabled: panel.device !== null && panel.radioEnabled
            onClicked: panel.device.scannerEnabled = !panel.device.scannerEnabled
        }
    }

    PlatinumMenuParts.Separator {}

    PlatinumMenuParts.Section {
        rightInset: frame.rightInset
        text: panel.device && panel.device.scannerEnabled ? "NETWORKS · SCANNING" : "NETWORKS"
    }

    PlatinumMenuParts.Empty {
        visible: panel.networks.length === 0
        rightInset: frame.rightInset
        text: {
            if (!panel.device) return "No Wi-Fi adapter is available.";
            if (!panel.hardwareEnabled) return "The hardware radio switch blocks Wi-Fi.";
            if (!panel.radioEnabled) return "Turn on Wi-Fi to find networks.";
            if (panel.device.scannerEnabled) return "Looking for networks…";
            return "No networks found. Select Scan to try again.";
        }
    }

    PlatinumMenuList {
        id: networks
        visible: panel.networks.length > 0
        model: ScriptModel { values: panel.networks }

        Component.onCompleted: view.forceActiveFocus()
        onCountChanged: {
            if (count > 0 && currentIndex < 0) currentIndex = 0;
            if (count === 0) currentIndex = -1;
        }

        delegate: PlatinumMenuListRow {
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
                else parts.push(panel.securityLabel(modelData));
                parts.push(Math.round(modelData.signalStrength * 100) + "%");
                return parts.join(" · ");
            }
            onEntered: networks.currentIndex = index

            readonly property string actionLabel: {
                if (modelData.stateChanging) return "Working";
                if (modelData.connected) return "Disconnect";
                if (panel.isEnterprise(modelData) && !modelData.known) return "Set up";
                return "Connect";
            }

            function runAction() { panel.runNetworkAction(modelData); }

            Connections {
                target: networkRow.modelData
                ignoreUnknownSignals: true

                function onConnectionFailed(reason): void {
                    panel.failureMessage = panel.failureText(reason);
                }

                function onConnectedChanged(): void {
                    if (networkRow.modelData.connected) {
                        panel.failureMessage = "";
                        panel.cancelPassword();
                    }
                }
            }

            Item {
                width: 14
                height: PlatinumTokens.menuButtonHeight
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
                width: PlatinumTokens.menuButtonHeight
                height: PlatinumTokens.menuButtonHeight
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
        visible: panel.failureMessage !== ""
        Layout.fillWidth: true
        Layout.leftMargin: PlatinumTokens.menuTextLeft
        Layout.rightMargin: frame.rightInset
        Layout.topMargin: 4
        implicitHeight: failureText.implicitHeight + 10
        color: "transparent"
        border.width: PlatinumTokens.hair
        border.color: PlatinumTokens.menuDanger

        Text {
            id: failureText
            x: 8
            width: parent.width - 16
            anchors.verticalCenter: parent.verticalCenter
            text: panel.failureMessage
            wrapMode: Text.Wrap
            color: PlatinumTokens.menuDanger
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumSmall
            font.letterSpacing: PlatinumTokens.platinumTracking
        }
    }

    // The password for a secured network: the field on the text
    // edge, Connect on the right edge, as wide as every action.
    Item {
        visible: frame.asking
        Layout.fillWidth: true
        Layout.topMargin: 4
        implicitHeight: 30

        PlatinumBevel {
            x: PlatinumTokens.menuTextLeft
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - frame.rightInset - frame.actionWidth - PlatinumTokens.menuGap
            height: 24
            sunken: true
            edged: false
            color: PlatinumTokens.well

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: passwordInput.text === ""
                text: panel.passwordNetwork ? "Password for " + panel.passwordNetwork.name : "Password"
                elide: Text.ElideRight
                color: PlatinumTokens.menuTextOff
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
            }

            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: PlatinumTokens.menuText
                selectionColor: PlatinumTokens.highlight
                selectedTextColor: PlatinumTokens.highlightText
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
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
            fixedWidth: frame.actionWidth - 4 * PlatinumTokens.hair
            enabled: passwordInput.text.length > 0
            onClicked: frame.submit()
        }
    }

    PlatinumMenuParts.Hint {
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
        enabled: !frame.asking && panel.device !== null && panel.radioEnabled
        onActivated: panel.device.scannerEnabled = !panel.device.scannerEnabled
    }
    Shortcut {
        sequence: "P"
        context: Qt.WindowShortcut
        enabled: !frame.asking && panel.hardwareEnabled
        onActivated: panel.setRadio(!panel.radioEnabled)
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