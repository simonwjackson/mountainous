import Quickshell
import Quickshell.Io
import QtQuick
import "notification-model.js" as Model

// One owner for the notification socket. notifyd owns
// org.freedesktop.Notifications and does the syncing; this side only draws
// what it is told and sends four ops back (contract section 7). It must never
// use Quickshell.Services.Notifications: a NotificationServer here would
// fight notifyd for the bus name.
//
// The popups and the centre read the public state below. The socket lives in
// this Scope so one connection serves every screen.
Scope {
    id: root

    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
        + "/notify-sync/ui.sock"

    // Public state. online means a snapshot came in on the current
    // connection; before that the items would be stale or empty.
    property bool online: false
    property bool connecting: true
    property var items: []
    property var status: Model.emptyStatus()
    property var popups: []
    readonly property int count: items.length
    readonly property bool hasCritical: items.some(function (i) { return i.urgency === 2; })
    readonly property int retryInSeconds: Math.ceil(retryRemaining / 1000)

    property int attempt: 0
    property int retryRemaining: 0

    // A fresh upsert for an item whose popup already shows: its timeout
    // starts again.
    signal popupRefreshed(int id)

    function byId(id) {
        for (let i = 0; i < root.items.length; i++) {
            if (root.items[i].id === id) return root.items[i];
        }
        return null;
    }

    function apply(event) {
        const next = Model.applyEvent({items: root.items, status: root.status, popups: root.popups}, event);
        root.items = next.items;
        root.status = next.status;
        root.popups = next.popups;
    }

    function handleLine(line) {
        const event = Model.parseLine(line);
        if (!event) {
            if (line.trim() !== "") console.warn("notifications: ignored line " + line.slice(0, 120));
            return;
        }
        if (event.type === "snapshot") {
            root.online = true;
            root.connecting = false;
            root.attempt = 0;
        }
        // Updates before the snapshot would be folded onto nothing.
        if (!root.online) return;
        const showing = event.type === "upsert" && event.fresh
            && root.popups.indexOf(event.item.id) >= 0;
        root.apply(event);
        if (showing) root.popupRefreshed(event.item.id);
    }

    function send(line) {
        const sock = root.sock;
        if (!sock || !sock.connected) return false;
        sock.write(line);
        sock.flush();
        return true;
    }

    function dismiss(id) {
        root.hidePopup(id);
        root.send(Model.dismissOp(id));
    }

    function dismissAll() {
        root.popups = [];
        root.send(Model.dismissAllOp());
    }

    // A disabled action never reaches the daemon: once the sender has gone,
    // nobody is listening for it.
    function invoke(id, key) {
        const item = root.byId(id);
        if (!item || !item.sender_alive) return;
        root.hidePopup(id);
        root.send(Model.actionOp(id, key));
    }

    // A popup timeout, or a click that only puts it away. The item stays.
    function hidePopup(id) {
        root.popups = root.popups.filter(function (p) { return p !== id; });
    }

    function hideAllPopups() {
        root.popups = [];
    }

    function lost() {
        snapshotWait.stop();
        root.online = false;
        root.items = [];
        root.popups = [];
        root.status = Model.emptyStatus();
        root.scheduleRetry();
    }

    function scheduleRetry() {
        if (retry.running) return;
        const delay = Model.backoffMs(root.attempt);
        root.attempt += 1;
        root.connecting = false;
        root.retryRemaining = delay;
        retry.interval = delay;
        retry.start();
        countdown.start();
    }

    function reconnectNow() {
        if (root.online) return;
        root.attempt = 0;
        root.connect();
    }

    // Every attempt gets a new Socket. Quickshell 0.3.1's Socket keeps the
    // QLocalSocket of a failed attempt, and while it holds one, setting
    // connected to true again does nothing (src/io/socket.cpp, setConnected).
    property var sock: null

    function connect() {
        retry.stop();
        countdown.stop();
        snapshotWait.stop();
        root.retryRemaining = 0;
        root.connecting = true;
        if (root.sock) {
            const old = root.sock;
            root.sock = null;
            old.destroy();
        }
        const sock = socketComponent.createObject(root, {path: root.socketPath});
        root.sock = sock;
        sock.connected = true;
    }

    Component.onCompleted: root.connect()

    Component {
        id: socketComponent

        Socket {
            id: socket

            parser: SplitParser {
                onRead: function (data) {
                    if (root.sock === socket) root.handleLine(data);
                }
            }

            onConnectionStateChanged: {
                if (root.sock !== socket) return;
                if (socket.connected) {
                    root.connecting = true;
                    socket.write(Model.subscribeOp());
                    socket.flush();
                    snapshotWait.restart();
                } else {
                    root.lost();
                }
            }

            // A missing socket file reports an error and never connects, so
            // the state change above does not fire. Both paths end in one
            // retry.
            onError: function (error) {
                if (root.sock === socket && !socket.connected) root.lost();
            }
        }
    }

    Timer {
        id: retry
        repeat: false
        onTriggered: root.connect()
    }

    // A daemon that takes the connection but never sends its snapshot is as
    // good as down. Drop it and go through the same backoff.
    Timer {
        id: snapshotWait
        interval: 5000
        repeat: false
        onTriggered: if (!root.online) root.lost()
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: root.retryRemaining = Math.max(0, root.retryRemaining - 1000)
    }
}
