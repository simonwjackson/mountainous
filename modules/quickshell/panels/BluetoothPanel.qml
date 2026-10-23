import Quickshell
import Quickshell.Bluetooth
import QtQuick

// Shared Bluetooth state. The active theme reads it even while its menu is closed.
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
}
