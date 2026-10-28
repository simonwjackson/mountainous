pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtWebSockets
import QtQuick
import "cdp-target.js" as CdpTarget

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
    property var pages: []          // [{ id, url, title, host, ws }]
    property string lastError: ""
    property var navigationHistory: ({})

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
                    root.publishPages("web", []);
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
        root.navigationHistory = CdpTarget.remember(root.navigationHistory, root.pages);
    }

    function refresh() {
        root.refreshEndpoint("web", root.port);
        root.refreshEndpoint("normal", root.normalPort);
    }

    function refreshEndpoint(endpoint, port) {
        if (port <= 0) { root.publishPages(endpoint, []); return; }
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

        root.pendingNav = { id: t.id, ws: t.ws, url: target };
        pageSock.active = false;
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
            } else if (status === WebSocket.Error) {
                root.lastError = "page socket: " + pageSock.errorString;
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

    // Window ownership belongs to Chromium. In particular, never close an
    // opener target and relaunch its URL: that destroys OAuth/window.open
    // state. The no-tab prototype stays disabled until it retains origin UI.

    // Keep the page list warm so targetFor() is answering from fresh
    // data when the omni bar opens.
    Timer {
        interval: 4000
        running: root.port > 0 || root.normalPort > 0
        repeat: true
        onTriggered: root.refresh()
    }
}
