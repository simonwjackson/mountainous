import Quickshell
import Quickshell.Io
import QtQuick
import "desktop-icons-model.js" as Model

// The shell's side of Hensou Files' desktop provider (ADR 0006): one
// socket to $XDG_RUNTIME_DIR/hensou/desktop.sock, JSON lines. Hello, then
// Subscribe with the theme and the primary screen's layout; the Snapshot
// and the Changed deltas become `icons`. A theme switch or a display
// change resubscribes. While the provider is down the icons are hidden
// (never stale ones drawn as live) and the socket retries quietly.
// desktop-icons-model.js reduce() is the whole state machine.
Scope {
    id: root

    property bool enabled: true
    property string theme: "platinum"
    // Model.screenLayout(theme, screen), or null before the screen is known.
    property var layout: null
    property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "") + "/hensou/desktop.sock"

    property var session: Model.initial()
    readonly property bool shown: root.enabled && Model.shown(root.session)
    readonly property var icons: root.shown ? root.session.icons : []
    readonly property bool snap: root.session.snap === true
    readonly property var grid: root.session.grid
    readonly property string kind: root.session.kind
    property int request: 0

    signal confirmNeeded(var effect)
    signal failed(var effect)
    signal providerChanged(var effect)

    function nextRequest() { root.request += 1; return root.request; }

    // One message; false when there is no live socket (the intent is
    // dropped, as the provider would have to confirm it anyway).
    function send(message) {
        if (!root.sock || !root.sock.connected) return false;
        root.sock.write(Model.encode(message));
        root.sock.flush();
        return true;
    }

    function dispatch(event) {
        const result = Model.reduce(root.session, event);
        root.session = result.state;
        for (const message of result.send) root.send(message);
        for (const effect of result.effects) {
            switch (effect.type) {
            case "open-socket": root.openSocket(); break;
            case "close-socket": Qt.callLater(root.closeSocket); break;
            case "retry": retry.interval = Math.max(50, effect.ms); retry.restart(); break;
            case "confirm": root.confirmNeeded(effect); break;
            case "error": root.failed(effect); break;
            case "changed": root.providerChanged(effect); break;
            }
        }
    }

    function pushLayout() {
        if (root.layout) root.dispatch({ type: "layout", theme: root.theme, layout: root.layout });
    }
    onLayoutChanged: Qt.callLater(root.pushLayout)
    onThemeChanged: Qt.callLater(root.pushLayout)
    onEnabledChanged: {
        if (root.enabled) { root.dispatch({ type: "connect" }); return; }
        retry.stop();
        root.closeSocket();
        root.session = Model.initial();
    }
    Component.onCompleted: {
        root.pushLayout();
        if (root.enabled) root.dispatch({ type: "connect" });
    }
    Component.onDestruction: root.closeSocket()

    // Every attempt gets a new Socket: Quickshell 0.3.1 keeps a failed
    // attempt's QLocalSocket and will not connect it again (see
    // Notifications.qml).
    property var sock: null
    function closeSocket() {
        if (!root.sock) return;
        const old = root.sock;
        root.sock = null;
        old.connected = false;
        old.destroy();
    }
    function openSocket() {
        root.closeSocket();
        const s = socketComponent.createObject(root, { path: root.socketPath });
        root.sock = s;
        s.connected = true;
    }

    Component {
        id: socketComponent
        Socket {
            id: socket
            parser: SplitParser {
                onRead: function (data) {
                    if (root.sock === socket) root.dispatch({ type: "line", data: data });
                }
            }
            onConnectionStateChanged: {
                if (root.sock !== socket) return;
                root.dispatch({ type: socket.connected ? "opened" : "lost" });
            }
            // A missing socket file errors and never connects.
            onError: function (error) {
                if (root.sock === socket && !socket.connected) root.dispatch({ type: "lost" });
            }
        }
    }

    Timer {
        id: retry
        repeat: false
        onTriggered: if (root.enabled) root.dispatch({ type: "retry" })
    }
}
