# The browser spine: a CDP client in QML.
#
# An --app window has no address bar, so it cannot be pointed at a new page
# through its own interface. Kamoi has the same shape and solves it the same
# way -- its README describes driving pages "over the WebView DevTools
# socket". This is that socket, spoken from Quickshell.
#
# It is pure QML. Measured on ridge: a Quickshell config imported QtWebSockets
# 6.11.2, opened a socket to Chromium's DevTools endpoint, sent Page.navigate
# and the window moved. No helper binary is involved.
#
# Two jobs:
#
#   navigate()   Kamoi's Ctrl+L, for the ACTIVE window only. Resolving which
#                CDP target the focused window is took two attempts. Title
#                looked sufficient until the enforcement test produced two
#                windows both called "Example Domain":
#
#                  windows=2 distinct_titles=1 distinct_app_ids=2
#                    title=Example Domain  app_id=chrome-example.com__-Default
#                    title=Example Domain  app_id=chrome-example.net__-Default
#
#                Chromium derives app_id from the URL, so the host inside
#                app_id is the reliable key and the title is only a tiebreak.
#
#   enforcement  "Every tab gets its own window" is not Chromium's default,
#                even in --app mode. window.open and target=_blank produced
#                three page targets with three distinct Chromium window ids
#                but only two Wayland windows -- a window Wayland never
#                mapped, so the page existed and could not be seen. Any target
#                carrying an openerId was opened by another page; it is closed
#                and relaunched through `web-app` as a window of its own.
#                Verified: close + relaunch ended at 3 windows / 3 pages.
#
# Cost that cannot be engineered away: enforcement means a link opens, closes
# and reopens. A POST-generated page cannot be re-requested from a URL and is
# lost. Kamoi documents the same limitation.
{
  nixos.modules.desktop = {
    hjem.users.simon.files.".config/quickshell/cairn/CdpBrowser.qml".text = ''
      pragma Singleton

      import Quickshell
      import Quickshell.Io
      import Quickshell.Hyprland
      import QtWebSockets
      import QtQuick

      Singleton {
          id: root

          readonly property string profile:
              Quickshell.env("HOME") + "/.local/share/cairn/browser"

          property int port: 0
          property var pages: []          // [{ id, url, title, host, ws }]
          property string lastError: ""

          readonly property bool ready: port > 0

          function log(msg) { console.log("[cdp] " + msg); }

          //--------------------------------------------------------------
          // PORT DISCOVERY
          //--------------------------------------------------------------
          // Chromium writes the port it chose into the profile. Read it with
          // a process rather than FileView so the whole path is one proven
          // mechanism; the file appears only once a browser is running.
          Process {
              id: portReader
              command: ["sh", "-c", "head -1 '" + root.profile + "/DevToolsActivePort' 2>/dev/null || true"]
              stdout: StdioCollector {
                  onStreamFinished: {
                      const n = parseInt(this.text.trim());
                      if (!isNaN(n) && n > 0 && n !== root.port) {
                          root.port = n;
                          root.log("port " + n);
                          root.refresh();
                          browserSock.reconnect();
                      } else if (isNaN(n) || n <= 0) {
                          root.port = 0;
                      }
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
              onTriggered: portReader.running = true
          }

          //--------------------------------------------------------------
          // TARGET LIST over plain HTTP
          //--------------------------------------------------------------
          function hostOf(url) {
              const m = /^[a-z]+:\/\/([^\/]+)/.exec(url || "");
              return m ? m[1] : "";
          }

          function refresh() {
              if (root.port <= 0) return;
              const xhr = new XMLHttpRequest();
              xhr.onreadystatechange = function () {
                  if (xhr.readyState !== XMLHttpRequest.DONE) return;
                  if (xhr.status !== 200) { root.port = 0; return; }
                  try {
                      const all = JSON.parse(xhr.responseText);
                      const out = [];
                      for (const t of all) {
                          if (t.type !== "page") continue;
                          out.push({
                              id: t.id,
                              url: t.url,
                              title: t.title,
                              host: root.hostOf(t.url),
                              ws: t.webSocketDebuggerUrl
                          });
                      }
                      root.pages = out;
                  } catch (e) { root.lastError = "" + e; }
              };
              xhr.open("GET", "http://127.0.0.1:" + root.port + "/json/list");
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
              const host = root.hostOfAppId(wl ? wl.appId : "");
              if (host === "") return null;

              const byHost = root.pages.filter(function (p) { return p.host === host; });
              if (byHost.length === 1) return byHost[0];
              if (byHost.length === 0) return null;

              // Same host in more than one window: fall back to the title.
              const t = toplevel.title || "";
              const byTitle = byHost.filter(function (p) { return p.title === t; });
              return byTitle.length > 0 ? byTitle[0] : byHost[0];
          }

          function isBrowserWindow(toplevel) {
              if (!toplevel) return false;
              const wl = toplevel.wayland;
              return root.hostOfAppId(wl ? wl.appId : "") !== "";
          }

          //--------------------------------------------------------------
          // NAVIGATE
          //--------------------------------------------------------------
          property var pendingNav: null    // { ws, url }

          function navigate(toplevel, url) {
              if (url === "") return false;
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
                  // Not a browser window, or the browser is not running:
                  // open the address as a window of its own instead.
                  Quickshell.execDetached(["web-app", target]);
                  return true;
              }

              root.pendingNav = { ws: t.ws, url: target };
              pageSock.active = false;
              pageSock.url = t.ws;
              pageSock.active = true;
              return true;
          }

          WebSocket {
              id: pageSock
              active: false
              onStatusChanged: {
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
                  root.pendingNav = null;
                  pageSock.active = false;
                  root.refresh();
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
                      root.log("browser socket open");
                      browserSock.sendTextMessage(JSON.stringify({
                          id: 1,
                          method: "Target.setDiscoverTargets",
                          params: { discover: true }
                      }));
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
                  Quickshell.execDetached(["web-app", url]);
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
              running: root.ready
              repeat: true
              onTriggered: root.refresh()
          }
      }
    '';
  };
}
