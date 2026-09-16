# The omni bar: one field that runs every command.
#
# Kamoi's README, which is the only source for the behaviour below:
#
#   "Meta+Space opens one bar that runs every browser command. An empty field
#    leads with the windows behind the one in front, most recently focused
#    first, so opening the bar and pressing Enter returns to the last window.
#    Typing filters the commands and blends matching windows underneath them."
#
#   "`Go to window` is a mode: opening it scopes the field to the window list,
#    which is what Meta+Shift+Space opens directly. Escape leaves a mode
#    before it closes the bar, and Backspace on an empty field leaves it too."
#
#   "While the bar is on screen ... its full-screen veil owns touchscreen,
#    mouse, and touchpad input. A captured pointer event cannot reach a page
#    behind the bar."
#
# That last paragraph is why this is Quickshell and not fuzzel. It is the
# hyprland_focus_grab_v1 protocol, exposed as HyprlandFocusGrab.
#
# Scope of this file: the base bar only -- veil, field, command registry, the
# window list and the application list. Kamoi's Bookmarks, PWA apps and Files
# modes are not here. Files in particular is larger than everything else in
# the omni bar combined.
#
# The command registry lives in QML rather than in a generated data file.
# This whole document is already produced by Nix, so a command is still
# declared in one place; a second file would buy nothing.
{
  nixos.modules.desktop = {
    # shell.qml in modules/bars.nix instantiates OmniBar. QML resolves a
    # component by filename from the same directory, so the two files must
    # ship together -- both are in this one `desktop` layer.
    hjem.users.simon.files.".config/quickshell/cairn/OmniBar.qml".text = ''
      import Quickshell
      import Quickshell.Hyprland
      import Quickshell.Io
      import Quickshell.Widgets
      import QtQuick

      Scope {
          id: root

          property bool shown: false
          // "root" leads with windows and offers commands; the others scope
          // the field to one list, which is Kamoi's notion of a mode.
          property string mode: "root"
          property string query: ""

          function enterRoot() {
              // Kamoi's list is ordered by focus history, and Hyprland does
              // not push that on every change, so ask for it on open.
              Hyprland.refreshToplevels();
              root.mode = "root";
              root.query = "";
              root.shown = true;
          }

          function enterMode(m) {
              Hyprland.refreshToplevels();
              root.mode = m;
              root.query = "";
              root.shown = true;
          }

          function back() {
              if (root.mode !== "root") { root.mode = "root"; root.query = ""; }
              else root.shown = false;
          }

          IpcHandler {
              target: "omni"
              // Deliberately not named open/show/list/close: `qs ipc call`
              // owns those verbs and silently returns its own interface
              // listing instead of calling the function.
              function toggle(): void { if (root.shown) root.shown = false; else root.enterRoot(); }
              function reveal(): void { root.enterRoot(); }
              function gotowindow(): void { root.enterMode("window"); }
              function apps(): void { root.enterMode("app"); }
              function dismiss(): void { root.shown = false; }
          }

          //--------------------------------------------------------------
          // ROWS
          //--------------------------------------------------------------

          // Kamoi: "the windows behind the one in front, most recently
          // focused first". focusHistoryID is 0 for the focused window, 1 for
          // the one before it, so dropping 0 and sorting ascending makes
          // Enter on an untouched field return to the last window.
          readonly property var windowRows: {
              const out = [];
              const all = [...Hyprland.toplevels.values];
              for (const t of all) {
                  if (!t.workspace || t.workspace.id <= 0) continue;
                  const o = t.lastIpcObject;
                  const h = (o && o.focusHistoryID !== undefined) ? o.focusHistoryID : 9999;
                  if (h === 0) continue;
                  out.push({
                      kind: "window",
                      label: t.title && t.title !== "" ? t.title : "(untitled)",
                      detail: "page " + t.workspace.id,
                      order: h,
                      toplevel: t,
                      entry: null
                  });
              }
              out.sort(function (a, b) { return a.order - b.order; });
              return out;
          }

          readonly property var appRows: {
              const out = [];
              for (const e of DesktopEntries.applications.values) {
                  out.push({
                      kind: "app",
                      label: e.name,
                      detail: e.genericName && e.genericName !== "" ? e.genericName : (e.comment || ""),
                      order: 0,
                      toplevel: null,
                      entry: e
                  });
              }
              out.sort(function (a, b) { return a.label.localeCompare(b.label); });
              return out;
          }

          readonly property var commandRows: [
              { kind: "cmd", label: "New terminal",          detail: "Super+N",           act: "term" },
              { kind: "cmd", label: "Go to window",          detail: "mode",              act: "mode:window" },
              { kind: "cmd", label: "Applications",          detail: "mode",              act: "mode:app" },
              { kind: "cmd", label: "Close window",          detail: "Super+C",           act: "close" },
              { kind: "cmd", label: "Monocle",               detail: "Super+M",           act: "monocle" },
              { kind: "cmd", label: "Zen",                   detail: "Super+Shift+M",     act: "zen" },
              { kind: "cmd", label: "Mirror workspace",      detail: "Super+Shift+G",     act: "mirror" },
              { kind: "cmd", label: "Even / golden split",   detail: "Super+G",           act: "split" },
              { kind: "cmd", label: "Interface scale up",    detail: "Super+=",           act: "scaleup" },
              { kind: "cmd", label: "Interface scale down",  detail: "Super+-",           act: "scaledown" },
              { kind: "cmd", label: "Interface scale 100%",  detail: "Super+0",           act: "scalereset" },
              { kind: "cmd", label: "Toggle bars",           detail: "Super+I",           act: "chrome" },
              { kind: "cmd", label: "Screenshot",            detail: "Super+S",           act: "shot" }
          ]

          function matches(row, q) {
              if (q === "") return true;
              const needle = q.toLowerCase();
              return row.label.toLowerCase().includes(needle)
                  || (row.detail || "").toLowerCase().includes(needle);
          }

          readonly property var rows: {
              const q = root.query;
              if (root.mode === "window") return windowRows.filter(function (r) { return matches(r, q); });
              if (root.mode === "app")    return appRows.filter(function (r) { return matches(r, q); });

              // Root. Empty field leads with windows. Typing puts matching
              // commands first and blends matching windows underneath.
              const w = windowRows.filter(function (r) { return matches(r, q); });
              const c = commandRows.filter(function (r) { return matches(r, q); });
              return q === "" ? w.concat(c) : c.concat(w);
          }

          //--------------------------------------------------------------
          // ACTIVATION
          //--------------------------------------------------------------
          function run(row) {
              if (!row) return;

              if (row.kind === "window") {
                  const wl = row.toplevel ? row.toplevel.wayland : null;
                  // The Wayland toplevel protocol, not Hyprland.dispatch:
                  // dispatcher syntax differs under a Lua config, and
                  // activate() also pulls focus to that window's page.
                  if (wl) wl.activate();
                  root.shown = false;
                  return;
              }

              if (row.kind === "app") {
                  if (row.entry) row.entry.execute();
                  root.shown = false;
                  return;
              }

              const a = row.act;
              if (a === "mode:window") { root.enterMode("window"); return; }
              if (a === "mode:app")    { root.enterMode("app"); return; }

              if (a === "term")            Quickshell.execDetached(["alacritty"]);
              else if (a === "close") {
                  const w = Hyprland.activeToplevel;
                  if (w && w.wayland) w.wayland.close();
              }
              else if (a === "monocle")    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"toggle\" })"]);
              else if (a === "zen")        Quickshell.execDetached(["hypr-zen"]);
              else if (a === "mirror")     Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.layout(\"orientationcycle left right\")"]);
              else if (a === "split")      Quickshell.execDetached(["hypr-split"]);
              else if (a === "scaleup")    Quickshell.execDetached(["hypr-scale", "up"]);
              else if (a === "scaledown")  Quickshell.execDetached(["hypr-scale", "down"]);
              else if (a === "scalereset") Quickshell.execDetached(["hypr-scale", "reset"]);
              else if (a === "chrome")     Quickshell.execDetached(["qs", "-c", "cairn", "ipc", "call", "chrome", "toggle"]);
              else if (a === "shot")       Quickshell.execDetached(["sh", "-c",
                  "mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"]);

              root.shown = false;
          }

          //--------------------------------------------------------------
          // THE VEIL
          //--------------------------------------------------------------
          LazyLoader {
              active: root.shown

              PanelWindow {
                  id: veil
                  anchors { top: true; bottom: true; left: true; right: true }
                  // Cover the screen without reserving any of it; the bars
                  // own the exclusive zones.
                  exclusionMode: ExclusionMode.Ignore
                  focusable: true
                  color: "#b4000000"

                  // Kamoi: "a captured pointer event cannot reach a page
                  // behind the bar". hyprland_focus_grab_v1 keeps keyboard
                  // focus here and reports an outside click as `cleared`.
                  HyprlandFocusGrab {
                      active: root.shown
                      windows: [ veil ]
                      onCleared: root.shown = false
                  }

                  // A click on the veil itself dismisses, as Escape does.
                  MouseArea {
                      anchors.fill: parent
                      onClicked: root.shown = false
                  }

                  Rectangle {
                      id: card
                      anchors.horizontalCenter: parent.horizontalCenter
                      anchors.top: parent.top
                      anchors.topMargin: Math.round(parent.height * 0.12)
                      width: Math.min(680, parent.width - 80)
                      height: Math.min(field.height + list.contentHeight + 18,
                                       parent.height - anchors.topMargin - 60)
                      radius: 8
                      color: "#141414"
                      border.width: 1
                      border.color: "#2e2e2e"

                      // Swallow clicks on the card so the veil's dismiss
                      // handler does not fire underneath it.
                      MouseArea { anchors.fill: parent }

                      Column {
                          anchors.fill: parent
                          anchors.margins: 8
                          spacing: 6

                          Row {
                              id: field
                              width: parent.width
                              height: 30
                              spacing: 8

                              Text {
                                  anchors.verticalCenter: parent.verticalCenter
                                  text: root.mode === "root" ? ">"
                                      : root.mode === "window" ? "window"
                                      : "app"
                                  color: "#707070"
                                  font.pixelSize: 13
                                  font.family: "monospace"
                              }

                              TextInput {
                                  id: input
                                  anchors.verticalCenter: parent.verticalCenter
                                  width: parent.width - 80
                                  focus: true
                                  color: "#e8e8e8"
                                  font.pixelSize: 14
                                  font.family: "monospace"
                                  selectByMouse: true
                                  text: root.query
                                  onTextChanged: {
                                      root.query = text;
                                      list.currentIndex = 0;
                                  }

                                  Keys.onEscapePressed: root.back()
                                  Keys.onDownPressed: list.incrementCurrentIndex()
                                  Keys.onUpPressed: list.decrementCurrentIndex()
                                  Keys.onReturnPressed: root.run(root.rows[list.currentIndex])
                                  Keys.onEnterPressed: root.run(root.rows[list.currentIndex])
                                  Keys.onTabPressed: list.incrementCurrentIndex()

                                  // Kamoi: "Backspace on an empty field leaves
                                  // the mode too."
                                  Keys.onPressed: function (event) {
                                      if (event.key === Qt.Key_Backspace && text === "" && root.mode !== "root") {
                                          root.mode = "root";
                                          event.accepted = true;
                                      }
                                  }
                              }
                          }

                          ListView {
                              id: list
                              width: parent.width
                              height: parent.height - field.height - parent.spacing
                              clip: true
                              model: root.rows
                              currentIndex: 0
                              keyNavigationWraps: true

                              delegate: Rectangle {
                                  required property var modelData
                                  required property int index
                                  width: list.width
                                  height: 26
                                  color: index === list.currentIndex ? "#2a2a2a" : "transparent"
                                  radius: 4

                                  MouseArea {
                                      anchors.fill: parent
                                      onClicked: { list.currentIndex = index; root.run(modelData); }
                                  }

                                  Row {
                                      anchors.fill: parent
                                      anchors.leftMargin: 8
                                      anchors.rightMargin: 8
                                      spacing: 8

                                      Text {
                                          anchors.verticalCenter: parent.verticalCenter
                                          width: 20
                                          text: modelData.kind === "window" ? "\u25a0"
                                              : modelData.kind === "app" ? "\u25cf" : "\u203a"
                                          color: "#606060"
                                          font.pixelSize: 11
                                          font.family: "monospace"
                                      }

                                      Text {
                                          anchors.verticalCenter: parent.verticalCenter
                                          width: parent.width - 150
                                          elide: Text.ElideRight
                                          text: modelData.label
                                          color: "#e0e0e0"
                                          font.pixelSize: 12
                                          font.family: "monospace"
                                      }

                                      Text {
                                          anchors.verticalCenter: parent.verticalCenter
                                          text: modelData.detail || ""
                                          color: "#6a6a6a"
                                          font.pixelSize: 11
                                          font.family: "monospace"
                                      }
                                  }
                              }
                          }
                      }
                  }
              }
          }
      }
    '';
  };
}
