import Quickshell
import Quickshell.Networking
import QtQuick

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
}
