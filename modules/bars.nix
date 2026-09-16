# The top bar and the window dock, as Quickshell.
#
# Kamoi's two bars, from its README:
#
#   "The page sits directly below the legacy top bar by default, while a
#    floating window dock reserves space at the bottom. The top bar shows
#    Wi-Fi and cellular signal strength as fixed-width Lucide icons. It does
#    not show a network name, carrier name, or cell identity."
#
#   "Middle-click a dock icon: close that window"
#   "Press Meta+I to hide both for immersive browsing."
#
# Quickshell rather than Waybar because the omni bar comes next. Kamoi's omni
# bar is a full-screen veil that "owns touchscreen, mouse, and touchpad input"
# while visible, which no bar toolkit can express. Quickshell ships
# HyprlandFocusGrab for exactly that, so one toolkit covers both jobs.
#
# Two deliberate departures from Kamoi, both because this is a laptop:
#   - no cellular icon: the Galaxy Book3 has no cellular radio.
#   - a battery readout: Kamoi had Android's status bar above it. We do not.
{
  nixos.modules.desktop =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.quickshell ];

      # Without this the battery readout is a confident lie. Quickshell says
      # so plainly in the journal:
      #   "Could not launch service org.freedesktop.UPower: ServiceUnknown"
      #   "Could not start UPower. The UPower service will not work."
      # and UPower.displayDevice.percentage then reads 0, which renders as a
      # flat 0% rather than as an error.
      services.upower.enable = true;

      # A user service rather than exec-once, so the bars restart on their own
      # and their logs land in the journal instead of Hyprland's stdout.
      systemd.user.services.quickshell = {
        description = "Quickshell: top bar and window dock";
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.quickshell}/bin/qs -c cairn";
          Restart = "on-failure";
          RestartSec = 2;
          Slice = "session.slice";
        };
      };

      hjem.users.simon.files.".config/quickshell/cairn/shell.qml".text = ''
        // Kamoi's two bars. See modules/bars.nix for provenance.
        import Quickshell
        import Quickshell.Io
        import Quickshell.Hyprland
        import Quickshell.Widgets
        import Quickshell.Services.UPower
        import QtQuick
        import QtQuick.Layouts

        ShellRoot {
            id: root

            // Kamoi Meta+I hides the top bar and the dock together.
            property bool chromeVisible: true

            // Reached from the compositor with:  qs -c cairn ipc call chrome toggle
            IpcHandler {
                target: "chrome"
                function toggle(): void { root.chromeVisible = !root.chromeVisible; }
                function hide(): void   { root.chromeVisible = false; }
                // Named reveal, not show: `qs ipc call chrome show` returns the
                // interface listing and does nothing, because `show` collides
                // with the qs CLI's own introspection verb. toggle and hide
                // both work, and Meta+I uses toggle.
                function reveal(): void { root.chromeVisible = true; }
            }

            // Every window on every workspace, ordered along the strip.
            //
            // Not just the focused workspace: the dock is how you see the
            // whole session at once, so a window two pages away is reachable
            // in one click rather than by walking the strip to find it.
            // Special workspaces are excluded; they are not part of the strip.
            readonly property var allWindows: {
                const list = [...Hyprland.toplevels.values].filter(function (t) {
                    return t.workspace && t.workspace.id > 0;
                });
                list.sort(function (a, b) { return a.workspace.id - b.workspace.id; });
                return list;
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            //----------------------------------------------------------------
            // TOP BAR
            //----------------------------------------------------------------
            Variants {
                model: Quickshell.screens

                PanelWindow {
                    required property var modelData
                    screen: modelData
                    visible: root.chromeVisible

                    anchors { top: true; left: true; right: true }
                    implicitHeight: 26
                    color: "#000000"

                    // Left: the focused window's title. Elided, and stopping
                    // well short of the clock so a long title never collides
                    // with it.
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, parent.width / 2 - 90)
                        elide: Text.ElideRight
                        text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
                        color: "#c8c8c8"
                        font.pixelSize: 11
                        font.family: "monospace"
                    }

                    // Centre: the time.
                    Text {
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(clock.date, "ddd d MMM  hh:mm")
                        color: "#e0e0e0"
                        font.pixelSize: 11
                        font.family: "monospace"
                    }

                    // Right: status only. Kamoi shows no network name, no
                    // carrier and no cell identity, so neither do we.
                    RowLayout {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 10
                        spacing: 12

                        Text {
                            text: UPower.onBattery ? "BAT" : "AC"
                            color: "#808080"
                            font.pixelSize: 11
                            font.family: "monospace"
                        }

                        Text {
                            readonly property var dev: UPower.displayDevice
                            text: dev ? Math.round(dev.percentage * 100) + "%" : ""
                            visible: text !== ""
                            color: "#e0e0e0"
                            font.pixelSize: 11
                            font.family: "monospace"
                        }
                    }
                }
            }

            //----------------------------------------------------------------
            // BOTTOM DOCK
            //----------------------------------------------------------------
            Variants {
                model: Quickshell.screens

                PanelWindow {
                    required property var modelData
                    screen: modelData
                    visible: root.chromeVisible

                    anchors { bottom: true; left: true; right: true }
                    implicitHeight: 44
                    // Kamoi: "a floating window dock reserves space at the
                    // bottom". The margin floats it; the anchors reserve it.
                    margins { bottom: 6; left: 6; right: 6 }
                    color: "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        implicitWidth: dockRow.implicitWidth + 16
                        implicitHeight: 38
                        radius: 6
                        color: "#141414"
                        visible: root.allWindows.length > 0

                        RowLayout {
                            id: dockRow
                            anchors.centerIn: parent
                            spacing: 6

                            Repeater {
                                model: ScriptModel { values: root.allWindows }

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    // A hairline before the first window of each
                                    // workspace, so the strip's shape is visible
                                    // without labelling every group.
                                    readonly property bool startsWorkspace: {
                                        if (index === 0) return false;
                                        const prev = root.allWindows[index - 1];
                                        return !prev || prev.workspace.id !== modelData.workspace.id;
                                    }

                                    implicitWidth: 30 + (startsWorkspace ? 9 : 0)
                                    implicitHeight: 30
                                    radius: 4
                                    color: "transparent"

                                    Rectangle {
                                        visible: parent.startsWorkspace
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 1
                                        height: 18
                                        color: "#3a3a3a"
                                    }

                                    Rectangle {
                                        id: cell
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 30
                                        height: 30
                                        radius: 4
                                        // The focused window is marked. Windows
                                        // on other pages are dimmed rather than
                                        // hidden, so the whole session reads at
                                        // a glance.
                                        color: modelData.activated ? "#303030" : "transparent"
                                        opacity: (Hyprland.focusedWorkspace
                                                  && modelData.workspace.id === Hyprland.focusedWorkspace.id)
                                                 ? 1.0 : 0.45

                                        // A toplevel has no wayland handle until
                                        // Hyprland reports its address, so appId
                                        // is briefly empty. iconPath("") builds a
                                        // malformed url and the journal fills up
                                        // with: Could not load icon "?fallback="
                                        readonly property string appId: {
                                            const wl = modelData.wayland;
                                            return wl && wl.appId ? wl.appId : "";
                                        }

                                        IconImage {
                                            anchors.centerIn: parent
                                            implicitSize: 20
                                            visible: source !== ""
                                            source: cell.appId === ""
                                                ? ""
                                                : Quickshell.iconPath(cell.appId, "application-x-executable")
                                        }

                                        // Until the icon resolves, show the first
                                        // letter rather than an empty square.
                                        Text {
                                            anchors.centerIn: parent
                                            visible: cell.appId === ""
                                            text: (modelData.title || "?").charAt(0).toUpperCase()
                                            color: "#c0c0c0"
                                            font.pixelSize: 13
                                            font.family: "monospace"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                            onClicked: function (mouse) {
                                                const wl = modelData.wayland;
                                                if (!wl) return;
                                                // Go through the Wayland toplevel
                                                // protocol, not Hyprland.dispatch:
                                                // dispatcher syntax differs under
                                                // a Lua config (Hyprland.usingLua)
                                                // and this path avoids the issue.
                                                // activate() also pulls the focus
                                                // to that window's workspace.
                                                if (mouse.button === Qt.MiddleButton) wl.close();
                                                else wl.activate();
                                            }
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
