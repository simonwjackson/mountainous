import Quickshell
import QtQuick
import "../../panels"

// Production data owners with deterministic, disconnected inputs. No probing,
// scanning, network calls or compositor commands run in this preview.
Scope {
    id: fixture
    property bool revealed: false
    property string control: ""
    property bool chromeVisible: true
    property bool chromeAccessVisible: false
    readonly property var shell: fixture
    readonly property var bluetooth: bluetoothData
    readonly property var wifi: wifiData
    readonly property var sound: soundData
    readonly property var brightness: brightnessData
    readonly property var oci: ociData
    readonly property var storage: storageData
    readonly property var builder: builderData
    readonly property var centre: centreData
    readonly property var notifications: notificationData
    readonly property var dictation: dictationData
    readonly property var omniBar: omniData
    readonly property var builderGate: gateData
    readonly property var frontWindow: null
    readonly property date now: new Date(2026, 9, 22, 16, 51)
    function windowsOn(screen) { return []; }
    function pageOf(toplevel) { return -1; }
    function dropOnto(windows, from, to) { }
    function openMenu(name, screen) { control = name; }

    BluetoothPanel { id: bluetoothData; adapter: null }
    WifiPanel { id: wifiData; device: null; radioEnabled: false; hardwareEnabled: false }
    SoundPanel { id: soundData; pipewireReady: false; defaultSink: null; defaultSource: null; outputs: []; inputs: [] }
    BrightnessPanel { id: brightnessData }
    OciEgress { id: ociData; enabled: false }
    StorageHealth { id: storageData; enabled: false }
    BuilderPanel { id: builderData; gate: gateData }
    NotificationCentre { id: centreData; service: notificationData }
    QtObject {
        id: gateData
        property bool enabled: false
        property var sample: ({kind: "unavailable"})
        property string pending: ""
    }
    QtObject {
        id: notificationData
        property int count: 0
        property var items: []
        property var view: ({kind: "empty"})
        property var status: ({server: "connected", outbox: 0, last_error: null})
    }
    QtObject {
        id: dictationData
        property string state: "idle"
        property bool barVisible: false
        property string statusText: ""
        property string backendLabel: ""
        property int queueCount: 0
        property bool canRetry: false
    }
    QtObject {
        id: omniData
        property bool shown: false
        property string mode: "root"
        property string query: ""
        property var caller: null
        property var screen: null
        property var windowRows: []
        property var appRows: []
        property var commandRows: []
        function enterRoot() { }
        function enterMode(mode, text) { }
        function enterNavigate(text) { }
        function back() { }
        function dismiss() { }
        function run(row) { }
        function navigateTo(text) { }
        function claimView(owner) { }
        function releaseView(owner) { }
    }
}
