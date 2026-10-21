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

    // Public state. connection is the one tagged socket state (see
    // Model.CONNECTION_KINDS); view is what to draw for it (Model.VIEW_KINDS).
    property var connection: Model.connectionStart()
    property var items: []
    property var status: Model.emptyStatus()
    property var popups: []
    property double now: Date.now()
    readonly property var view: Model.viewState(root.connection, root.items, root.now)
    readonly property int count: items.length

    // Which cards the reader opened, by id. Held here, not in a centre, so a
    // popup can open its item in the centre, and a resize or a new item does
    // not close a card.
    property var expandedIds: ({})
    // An item a popup asked the centre to show: some(id) until a centre
    // takes it.
    property var focusRequest: Model.none()

    // A fresh upsert for an item whose popup already shows: its timeout
    // starts again.
    signal popupRefreshed(int id)

    function toggleExpanded(id) {
        const next = Object.assign({}, root.expandedIds);
        if (next[id]) delete next[id];
        else next[id] = true;
        root.expandedIds = next;
    }

    // Open an item's card and ask the next centre to bring it into view.
    function revealItem(id) {
        const next = Object.assign({}, root.expandedIds);
        next[id] = true;
        root.expandedIds = next;
        root.focusRequest = Model.some(id);
        root.hidePopup(id);
    }

    function takeFocusRequest() {
        const request = root.focusRequest;
        root.focusRequest = Model.none();
        return request;
    }

    function find(id) {
        return Model.findItem(root.items, id);
    }

    function apply(event) {
        const next = Model.applyEvent({items: root.items, status: root.status, popups: root.popups}, event);
        root.items = next.items;
        root.status = next.status;
        root.popups = next.popups;
    }

    function handleLine(line) {
        const parsed = Model.parseLine(line);
        if (parsed.kind === "invalid") {
            if (line.trim() !== "") console.warn("notifications: ignored line (" + parsed.reason + ") " + line.slice(0, 120));
            return;
        }
        const event = parsed.event;
        if (event.type === "snapshot") root.enter(Model.snapshotReceived(root.connection));
        // Updates before the snapshot would be folded onto nothing.
        if (root.connection.kind !== "connected") return;
        const showing = event.type === "upsert" && event.fresh
            && root.popups.indexOf(event.item.id) >= 0;
        root.apply(event);
        if (showing) root.popupRefreshed(event.item.id);
    }

    function send(line) {
        const sock = root.sock;
        if (root.connection.kind !== "connected" || !sock) return;
        sock.write(line);
        sock.flush();
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
        const found = root.find(id);
        if (found.kind === "none" || !found.value.sender_alive) return;
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

    function reconnectNow() {
        root.enter(Model.retryNow(root.connection));
    }

    // Every change of connection state goes through here, and here is where
    // each state's effects start: the transitions themselves are pure.
    function enter(next) {
        const previous = root.connection;
        if (next === previous) return;
        root.connection = next;
        root.now = Date.now();
        if (next.kind === previous.kind && next.kind !== "connecting") return;

        snapshotWait.stop();
        retry.stop();
        if (next.kind === "connecting") {
            root.openSocket();
        } else if (next.kind === "awaiting_snapshot") {
            root.sock.write(Model.subscribeOp());
            root.sock.flush();
            snapshotWait.start();
        } else if (next.kind === "offline") {
            root.closeSocket();
            const state = Model.initialState();
            root.items = state.items;
            root.status = state.status;
            root.popups = state.popups;
            retry.interval = Math.max(1, next.retryAt - Date.now());
            retry.start();
        }
    }

    // Every attempt gets a new Socket. Quickshell 0.3.1's Socket keeps the
    // QLocalSocket of a failed attempt, and while it holds one, setting
    // connected to true again does nothing (src/io/socket.cpp, setConnected).
    property var sock: null

    function closeSocket() {
        if (!root.sock) return;
        const old = root.sock;
        root.sock = null;
        old.destroy();
    }

    function openSocket() {
        root.closeSocket();
        const sock = socketComponent.createObject(root, {path: root.socketPath});
        root.sock = sock;
        sock.connected = true;
    }

    Component.onCompleted: root.openSocket()

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
                root.enter(socket.connected
                    ? Model.socketOpened(root.connection)
                    : Model.socketLost(root.connection, Date.now()));
            }

            // A missing socket file reports an error and never connects, so
            // the state change above does not fire.
            onError: function (error) {
                if (root.sock === socket && !socket.connected)
                    root.enter(Model.socketLost(root.connection, Date.now()));
            }
        }
    }

    Timer {
        id: retry
        repeat: false
        onTriggered: root.enter(Model.retryDue(root.connection))
    }

    Timer {
        id: snapshotWait
        interval: Model.SNAPSHOT_WAIT_MS
        repeat: false
        onTriggered: root.enter(Model.snapshotTimedOut(root.connection, Date.now()))
    }

    // The offline countdown in the centre.
    Timer {
        interval: 1000
        repeat: true
        running: root.connection.kind === "offline"
        onTriggered: root.now = Date.now()
    }
}
