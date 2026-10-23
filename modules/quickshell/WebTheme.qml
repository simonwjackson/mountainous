pragma Singleton

import Quickshell
import Quickshell.Io
import QtWebSockets
import QtQuick
import "web-theme.js" as Policy

// Chromium pages in the active desktop theme: type, scroll bars and form
// controls, from themes/<Theme.name>/web.css. See docs/decisions/web-theme.md.
//
// This owns its own browser-level CDP socket, separate from CdpBrowser's
// navigation and enforcement socket. It auto-attaches to every page and
// out-of-process iframe with waitForDebuggerOnStart, registers the in-page
// script (web-theme-page.js) before the target runs, then resumes it, so a
// new window paints styled. A change of theme, mode or Extra dark, or an
// edit to web.css, re-registers the script with runImmediately, which
// restyles every open frame in place without a reload.
//
// If this socket closes (Quickshell restarts), Chromium drops the
// registered scripts: open documents keep their last styles, a document
// loaded while the socket is down is plain until the socket reconnects and
// styles it in place.
Singleton {
    id: root

    readonly property string portPath: CdpBrowser.profile + "/DevToolsActivePort"
    property int port: 0
    property bool connecting: false
    readonly property bool connected: sock.status === WebSocket.Open

    // sessionId -> { type, url, script: registered identifier, request: last add id }
    property var sessions: ({})
    property int sessionCount: 0
    property int nextId: 1
    property var pending: ({})
    property double lastPush: 0

    property string cssText: ""
    property string pageText: ""
    readonly property string cssPath: Policy.cssPath(Theme.name)
    readonly property var payload: Policy.payload(root.cssText, Theme.name, Theme.mode, Theme.extraDark)
    readonly property string source: root.pageText === "" ? "" : Policy.script(root.pageText, root.payload)
    onSourceChanged: root.pushAll()

    function log(msg) { console.log("[web-theme] " + msg); }

    FileView {
        path: Quickshell.shellPath("web-theme-page.js")
        blockLoading: true
        onLoaded: root.pageText = text()
        onLoadFailed: root.pageText = ""
    }

    FileView {
        id: cssFile
        path: root.cssPath === "" ? "" : Quickshell.shellPath(root.cssPath)
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.cssText = text()
        // A theme with no web.css restyles nothing, and clears the last one.
        onLoadFailed: root.cssText = ""
    }

    //--------------------------------------------------------------
    // PORT: Chromium writes it into the profile when it starts.
    //--------------------------------------------------------------
    // Watch the file, and re-read it every second while disconnected, so
    // a cold browser start is styled as early as possible.
    FileView {
        id: portFile
        path: root.portPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const n = parseInt(text().split("\n")[0]);
            root.port = isNaN(n) || n <= 0 ? 0 : n;
            root.connect();
        }
        onLoadFailed: root.port = 0
    }

    Timer {
        interval: 1000
        repeat: true
        running: !root.connected
        onTriggered: portFile.reload()
    }

    function connect() {
        if (root.port <= 0 || root.connected || root.connecting) return;
        root.connecting = true;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            root.connecting = false;
            if (xhr.status !== 200) return;
            try {
                const url = JSON.parse(xhr.responseText).webSocketDebuggerUrl;
                sock.active = false;
                sock.url = url;
                sock.active = true;
            } catch (e) { /* not a DevTools endpoint */ }
        };
        xhr.open("GET", "http://127.0.0.1:" + root.port + "/json/version");
        xhr.send();
    }

    //--------------------------------------------------------------
    // CDP
    //--------------------------------------------------------------
    function send(method, params, sessionId) {
        const id = root.nextId++;
        const msg = { id: id, method: method, params: params || {} };
        if (sessionId) msg.sessionId = sessionId;
        sock.sendTextMessage(JSON.stringify(msg));
        return id;
    }

    function register(sessionId) {
        const s = root.sessions[sessionId];
        if (!s || root.source === "") return;
        if (s.script !== "") {
            root.send("Page.removeScriptToEvaluateOnNewDocument", { identifier: s.script }, sessionId);
            s.script = "";
        }
        // runImmediately also runs it in the frame's current document.
        s.request = root.send("Page.addScriptToEvaluateOnNewDocument",
            { source: root.source, runImmediately: true }, sessionId);
        root.pending[s.request] = sessionId;
    }

    function pushAll() {
        if (!root.connected) return;
        root.lastPush = Date.now();
        for (const id of Object.keys(root.sessions)) root.register(id);
    }

    function attached(p) {
        const info = p.targetInfo || {};
        if (info.type === "page" || info.type === "iframe") {
            root.sessions[p.sessionId] = { type: info.type, url: info.url, script: "", request: 0 };
            root.sessionCount = Object.keys(root.sessions).length;
            // Page.enable keeps the script across cross-process navigations
            // and makes it run in out-of-process iframes.
            root.send("Page.enable", {}, p.sessionId);
            root.send("Target.setAutoAttach", { autoAttach: true, waitForDebuggerOnStart: true,
                flatten: true, filter: [{ type: "iframe" }] }, p.sessionId);
            root.register(p.sessionId);
        }
        // Always resume, even a target this does not style.
        root.send("Runtime.runIfWaitingForDebugger", {}, p.sessionId);
    }

    function detached(sessionId) {
        delete root.sessions[sessionId];
        root.sessionCount = Object.keys(root.sessions).length;
    }

    function answered(m) {
        const sessionId = root.pending[m.id];
        delete root.pending[m.id];
        const s = root.sessions[sessionId];
        const identifier = m.result ? m.result.identifier : "";
        if (!s || !identifier) return;
        if (s.request === m.id) s.script = identifier;
        // A newer theme was registered first; drop this stale script.
        else root.send("Page.removeScriptToEvaluateOnNewDocument", { identifier: identifier }, sessionId);
    }

    WebSocket {
        id: sock
        active: false
        onStatusChanged: function () {
            const status = sock.status;
            if (status === WebSocket.Open) {
                root.sessions = {};
                root.pending = {};
                root.sessionCount = 0;
                root.log("attached to port " + root.port);
                root.send("Target.setAutoAttach", { autoAttach: true, waitForDebuggerOnStart: true,
                    flatten: true, filter: [{ type: "page" }] });
            } else if (status === WebSocket.Closed || status === WebSocket.Error) {
                if (root.sessionCount > 0) root.log("detached");
                root.sessions = {};
                root.pending = {};
                root.sessionCount = 0;
                sock.active = false;
            }
        }
        onTextMessageReceived: function (msg) {
            // Page.enable reports every navigation; none of it is needed.
            if (msg.startsWith('{"method":"Page.')) return;
            let m;
            try { m = JSON.parse(msg); } catch (e) { return; }
            if (m.method === "Target.attachedToTarget") root.attached(m.params);
            else if (m.method === "Target.detachedFromTarget") root.detached(m.params.sessionId);
            else if (m.id !== undefined && root.pending[m.id] !== undefined) root.answered(m);
        }
    }

    IpcHandler {
        target: "webTheme"
        function status(): string {
            return (root.connected ? "connected" : "disconnected") + " port=" + root.port
                + " frames=" + root.sessionCount + " theme=" + Theme.name
                + " appearance=" + (root.payload.appearance || "none") + " pushed=" + root.lastPush;
        }
        // Register the current styles again in every frame.
        function reapply(): void { root.pushAll(); }
    }
}
