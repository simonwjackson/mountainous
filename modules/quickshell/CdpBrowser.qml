pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtWebSockets
import QtQuick
import QtQml.Models
import "cdp-target.js" as CdpTarget
import "favicon.js" as Favicon

Singleton {
    id: root

    readonly property string profile:
        Quickshell.env("HOME") + "/.local/share/mountainous/browser"

    // Ordinary Chromium keeps its own cookies. Never merge the two roots.
    readonly property string normalProfile:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/chromium"
    property int normalPort: 0
    property var endpointPages: ({})
    property int port: 0
    property var pages: []          // [{ id, url, title, host, ws, endpoint, favicon }]
    property string lastError: ""
    property var navigationHistory: ({})
    property var focusMap: ({})    // normalized window address -> live page id
    readonly property var windows: Hyprland.toplevels.values
    onWindowsChanged: root.pruneFocus()
    onPagesChanged: root.pruneFocus()

    function pruneFocus() {
        root.focusMap = CdpTarget.pruneFocusMap(root.focusMap, root.windows, root.pages);
    }

    // Cached per target/navigation. Errors are cached too; polling /json/list
    // must not repeatedly fetch manifests or create evaluation sockets.
    property var pageIcons: ({})

    function faviconFor(toplevel, pixels) {
        const page = CdpTarget.faviconPageFor(toplevel, root.pages, root.focusMap);
        if (!page) return "";
        const metadata = root.pageIcons[page.id];
        const icons = metadata && metadata.key === Favicon.pageKey(page) ? metadata.icons : [];
        return Favicon.choose(icons.concat([{url: page.favicon, sizes: ""}]), pixels || 16);
    }

    function recordPageIcons(page, icons) {
        if (!root.pages.some(function (p) { return p.id === page.id && Favicon.pageKey(p) === Favicon.pageKey(page); })) return;
        const next = Object.assign({}, root.pageIcons);
        next[page.id] = {key: Favicon.pageKey(page), icons: Array.isArray(icons) ? icons : []};
        root.pageIcons = next;
    }

    Instantiator {
        model: root.pages
        delegate: WebSocket {
            id: iconSocket
            required property var modelData
            url: modelData.ws || ""
            active: !!modelData.ws && (!root.pageIcons[modelData.id] || root.pageIcons[modelData.id].key !== Favicon.pageKey(modelData))
            onStatusChanged: function(status) {
                if (status === WebSocket.Open) {
                    iconSocket.sendTextMessage(JSON.stringify({id: 1, method: "Runtime.evaluate",
                        params: {expression: Favicon.pageExpression(), awaitPromise: true, returnByValue: true}}));
                } else if (status === WebSocket.Error || (status === WebSocket.Closed && active)) {
                    root.recordPageIcons(modelData, []);
                }
            }
            onTextMessageReceived: function(msg) {
                let response;
                try { response = JSON.parse(msg); } catch (e) { return; }
                if (response.id !== 1) return;
                const result = response.result;
                root.recordPageIcons(modelData, !response.error && result && !result.exceptionDetails && result.result ? result.result.value : []);
            }
            property Timer timeout: Timer {
                interval: 2500
                running: iconSocket.active
                onTriggered: root.recordPageIcons(iconSocket.modelData, [])
            }
        }
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() { root.probeFocusedWindow(); }
    }

    // One bounded batch per focus change, only for ambiguous matches.
    // Results from a previous focus, errors and partial batches prove nothing.
    property int focusSequence: 0
    property var focusProbe: null
    property var focusReplies: ({})
    function probeFocusedWindow() {
        root.focusProbe = null;
        focusTimeout.stop();
        const t = Hyprland.activeToplevel;
        if (!t || !t.address || !root.isBrowserWindow(t)) return;
        const candidates = CdpTarget.candidatesFor(root.pages, CdpTarget.appIdOf(t), t.title || "");
        if (candidates.length < 2) return;
        const sequence = ++root.focusSequence;
        root.focusReplies = {};
        root.focusProbe = {sequence: sequence, address: t.address,
            candidates: candidates.map(function (page) { return {sequence: sequence, page: page}; })};
        focusTimeout.restart();
    }

    function focusReply(sequence, id, focused) {
        const probe = root.focusProbe;
        if (!probe || probe.sequence !== sequence) return;
        const replies = Object.assign({}, root.focusReplies);
        replies[id] = focused;
        root.focusReplies = replies;
        if (Object.keys(replies).length !== probe.candidates.length) return;
        const active = Hyprland.activeToplevel;
        if (active && active.address === probe.address && Object.values(replies).every(function (r) { return r !== null; })) {
            const ids = Object.keys(replies).filter(function (key) { return replies[key] === true; });
            root.focusMap = CdpTarget.recordFocus(root.focusMap, probe.address, ids);
            root.pruneFocus();
        }
        root.focusProbe = null;
        focusTimeout.stop();
    }

    Timer {
        id: focusTimeout
        interval: 1000
        onTriggered: root.focusProbe = null
    }

    // A dead browser leaves DevToolsActivePort behind holding the port
    // it used to own. Zeroing `port` when a request fails made the
    // poller rediscover that stale value every cycle and log it every
    // cycle. `port` is now only what the file says, and `live` is
    // whether anything is answering on it.
    property bool live: false
    readonly property bool ready: port > 0 && live

    function log(msg) { console.log("[cdp] " + msg); }

    //--------------------------------------------------------------
    // PORT DISCOVERY
    //--------------------------------------------------------------
    // Chromium writes the port it chose into the profile.
    //
    // No shell here. A systemd user service gets a minimal PATH --
    // measured on hiyori it held only coreutils, findutils, gnugrep,
    // gnused and systemd -- so `sh -c` failed with "Process failed to
    // start, likely because the binary could not be found". head comes
    // from coreutils, which is present, and needs no shell. A missing
    // file simply yields no output.
    Process {
        id: portReader
        command: ["head", "-1", root.profile + "/DevToolsActivePort"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = Number(this.text.trim());
                if (!Number.isInteger(n) || n <= 0 || n > 65535) {
                    root.port = 0;
                    root.live = false;
                    if (root.endpointPages.web) root.publishPages("web", []);
                    return;
                }
                if (n !== root.port) {
                    root.port = n;
                    root.log("port " + n);
                }
                // Reconnect only while nothing is answering, so a
                // browser that restarts on the same port is picked up
                // without hammering a live one.
                if (!root.live) {
                    root.refresh();
                    browserSock.reconnect();
                }
            }
        }
    }

    Process {
        id: normalPortReader
        command: ["head", "-1", root.normalProfile + "/DevToolsActivePort"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = Number(this.text.trim());
                root.normalPort = Number.isInteger(n) && n > 0 && n <= 65535 ? n : 0;
                root.refreshEndpoint("normal", root.normalPort);
            }
        }
    }

    // Poll: the browser may not be running when the shell starts, and
    // it may be restarted underneath us.
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            portReader.running = true;
            if (Quickshell.env("MOUNTAINOUS_BROWSER_INTEGRATION") !== "0") normalPortReader.running = true;
        }
    }

    //--------------------------------------------------------------
    // TARGET LIST over plain HTTP
    //--------------------------------------------------------------
    function hostOf(url) {
        const m = /^[a-z]+:\/\/([^\/]+)/.exec(url || "");
        return m ? m[1] : "";
    }

    function publishPages(endpoint, pages) {
        const next = Object.assign({}, root.endpointPages);
        next[endpoint] = pages;
        root.endpointPages = next;
        root.pages = (next.web || []).concat(next.normal || []);
        const icons = {};
        for (const page of root.pages) {
            if (root.pageIcons[page.id]) icons[page.id] = root.pageIcons[page.id];
        }
        root.pageIcons = icons;
        root.navigationHistory = CdpTarget.remember(root.navigationHistory, root.pages);
    }

    function refresh() {
        root.refreshEndpoint("web", root.port);
        root.refreshEndpoint("normal", root.normalPort);
    }

    function refreshEndpoint(endpoint, port) {
        if (port <= 0) {
            if (root.endpointPages[endpoint]) root.publishPages(endpoint, []);
            return;
        }
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            // Ignore responses from a browser which restarted during a request.
            if (port !== (endpoint === "web" ? root.port : root.normalPort)) return;
            if (endpoint === "web") root.live = xhr.status === 200;
            if (xhr.status !== 200) { root.publishPages(endpoint, []); return; }
            try {
                const all = JSON.parse(xhr.responseText);
                const out = [];
                for (const t of all) {
                    if (t.type !== "page") continue;
                    out.push({ id: t.id, url: t.url, title: t.title,
                        host: root.hostOf(t.url), ws: t.webSocketDebuggerUrl,
                        endpoint: endpoint, favicon: t.faviconUrl || "" });
                }
                root.publishPages(endpoint, out);
            } catch (e) {
                root.lastError = "" + e;
                root.publishPages(endpoint, []);
            }
        };
        xhr.open("GET", "http://127.0.0.1:" + port + "/json/list");
        xhr.send();
    }

    //--------------------------------------------------------------
    // ACTIVE WINDOW -> TARGET
    //--------------------------------------------------------------
    // app_id looks like chrome-<host>__-Default. The host is the key.
    function hostOfAppId(appId) {
        const m = /^chrome-(.+?)__-/.exec(appId || "");
        return m ? m[1] : "";
    }

    // Pass the toplevel captured at keypress: the omni bar's veil takes
    // keyboard focus, so by the time the field is up the focused window
    // is the veil, not the page.
    function targetFor(toplevel) {
        if (!toplevel) return null;
        const wl = toplevel.wayland;
        return CdpTarget.targetFor(root.pages, root.navigationHistory,
            wl ? wl.appId : "", toplevel.title || "");
    }

    function isBrowserWindow(toplevel) {
        if (!toplevel) return false;
        const wl = toplevel.wayland;
        return CdpTarget.isBrowser(wl ? wl.appId : "");
    }

    //--------------------------------------------------------------
    // NAVIGATE
    //--------------------------------------------------------------
    property var pendingNav: null    // { ws, url }

    function navigate(toplevel, url) {
        if (url === "" || root.pendingNav) return false;
        root.lastError = "";
        // Bare words and hosts both get a scheme, so typing
        // "nixos.org" behaves like an address bar rather than failing.
        let target = url;
        if (!/^[a-z][a-z0-9+.-]*:/.test(target)) {
            target = /^[^\s\/]+\.[^\s\/]+/.test(target)
                ? "https://" + target
                : "https://duckduckgo.com/?q=" + encodeURIComponent(target);
        }

        const t = root.targetFor(toplevel);
        if (!t) {
            root.lastError = "no CDP target for the active window";
            root.log(root.lastError);
            // Ambiguous/disconnected browser targets must not navigate a
            // different page, or silently open a replacement window.
            if (root.isBrowserWindow(toplevel)) return false;
            Launcher.launch(["web-app", target], {id: target, name: target, icon: "chromium", kind: "webapp"});
            return true;
        }

        pageSock.active = false;
        root.pendingNav = { id: t.id, ws: t.ws, url: target };
        pageSock.url = t.ws;
        pageSock.active = true;
        return true;
    }

    WebSocket {
        id: pageSock
        active: false
        onStatusChanged: function(status) {
            if (status === WebSocket.Open && root.pendingNav) {
                pageSock.sendTextMessage(JSON.stringify({
                    id: 1,
                    method: "Page.navigate",
                    params: { url: root.pendingNav.url }
                }));
            } else if (status === WebSocket.Error || (status === WebSocket.Closed && pageSock.active && root.pendingNav)) {
                root.lastError = status === WebSocket.Error
                    ? "page socket: " + pageSock.errorString : "page socket closed before navigation completed";
                root.log(root.lastError);
                root.pendingNav = null;
            }
        }
        onTextMessageReceived: function (msg) {
            let response;
            try { response = JSON.parse(msg); } catch (e) { return; }
            if (response.id !== 1) return;
            if (response.error || (response.result && response.result.errorText)) {
                root.lastError = "navigation: " + JSON.stringify(response.error || response.result.errorText);
                root.log(root.lastError);
            } else if (root.pendingNav) {
                root.navigationHistory = CdpTarget.remember(root.navigationHistory,
                    root.pages.map(function (page) {
                        return page.id === root.pendingNav.id
                            ? {id: page.id, url: root.pendingNav.url} : page;
                    }));
            }
            root.pendingNav = null;
            pageSock.active = false;
            root.refresh();
        }
    }

    Instantiator {
        model: root.focusProbe ? root.focusProbe.candidates : []
        delegate: WebSocket {
            id: focusSocket
            required property var modelData
            url: modelData.page.ws || ""
            active: true
            onStatusChanged: function(status) {
                if (status === WebSocket.Open) {
                    focusSocket.sendTextMessage(JSON.stringify({id: 1, method: "Runtime.evaluate",
                        params: {expression: "document.hasFocus()", returnByValue: true}}));
                } else if (status === WebSocket.Error || status === WebSocket.Closed) {
                    root.focusReply(modelData.sequence, modelData.page.id, null);
                }
            }
            onTextMessageReceived: function(msg) {
                let response;
                try { response = JSON.parse(msg); } catch (e) { return; }
                if (response.id !== 1) return;
                const result = response.result;
                const value = !response.error && result && !result.exceptionDetails && result.result
                    && result.result.type === "boolean" && typeof result.result.value === "boolean" ? result.result.value : null;
                root.focusReply(modelData.sequence, modelData.page.id, value);
            }
        }
    }

    //--------------------------------------------------------------
    // ENFORCEMENT: one page, one window
    //--------------------------------------------------------------
    WebSocket {
        id: browserSock
        active: false

        function reconnect() {
            if (root.port <= 0) return;
            const xhr = new XMLHttpRequest();
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                if (xhr.status !== 200) return;
                try {
                    const v = JSON.parse(xhr.responseText);
                    browserSock.active = false;
                    browserSock.url = v.webSocketDebuggerUrl;
                    browserSock.active = true;
                } catch (e) { root.lastError = "" + e; }
            };
            xhr.open("GET", "http://127.0.0.1:" + root.port + "/json/version");
            xhr.send();
        }

        onStatusChanged: {
            if (status === WebSocket.Open) {
                root.live = true;
                root.log("browser socket open");
                browserSock.sendTextMessage(JSON.stringify({
                    id: 1,
                    method: "Target.setDiscoverTargets",
                    params: { discover: true }
                }));
            } else if (status === WebSocket.Closed || status === WebSocket.Error) {
                root.live = false;
            }
        }

        onTextMessageReceived: function (msg) {
            let m;
            try { m = JSON.parse(msg); } catch (e) { return; }
            if (m.method !== "Target.targetCreated") return;

            const info = m.params ? m.params.targetInfo : null;
            if (!info || info.type !== "page") return;

            // A target with no openerId came from a fresh `web-app`
            // launch and already owns a window. One WITH an openerId was
            // opened by another page, which is the case Chromium fails
            // to give a Wayland surface.
            if (!info.openerId) { root.refresh(); return; }

            root.log("stray target from opener " + info.openerId + ": " + info.url);
            root.adopt(info.targetId, info.url);
        }
    }

    function adopt(targetId, url) {
        // about:blank first, then a real url: window.open often creates
        // the target before navigating it. Re-read shortly after.
        if (!url || url === "" || url === "about:blank") {
            adoptTimer.pendingId = targetId;
            adoptTimer.restart();
            return;
        }
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            Launcher.launch(["web-app", url], {id: url, name: url, icon: "chromium", kind: "webapp"});
            root.refresh();
        };
        xhr.open("GET", "http://127.0.0.1:" + root.port + "/json/close/" + targetId);
        xhr.send();
    }

    Timer {
        id: adoptTimer
        property string pendingId: ""
        interval: 700
        onTriggered: {
            const want = adoptTimer.pendingId;
            adoptTimer.pendingId = "";
            if (want === "") return;
            const xhr = new XMLHttpRequest();
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                if (xhr.status !== 200) return;
                try {
                    const all = JSON.parse(xhr.responseText);
                    for (const t of all) {
                        if (t.id === want && t.url && t.url !== "about:blank") {
                            root.adopt(want, t.url);
                            return;
                        }
                    }
                } catch (e) { /* target vanished on its own */ }
            };
            xhr.open("GET", "http://127.0.0.1:" + root.port + "/json/list");
            xhr.send();
        }
    }

    // Keep the page list warm so targetFor() is answering from fresh
    // data when the omni bar opens.
    Timer {
        interval: 4000
        running: root.port > 0 || root.normalPort > 0
        repeat: true
        onTriggered: root.refresh()
    }
}
