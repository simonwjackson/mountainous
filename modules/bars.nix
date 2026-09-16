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

            // The windows on the focused workspace, in Hyprland's own order.
            // Kamoi's dock lists exactly the windows of the current page.
            readonly property var pageWindows: {
                const ws = Hyprland.focusedWorkspace;
                if (!ws) return [];
                return [...Hyprland.toplevels.values].filter(function (t) {
                    return t.workspace && t.workspace.id === ws.id;
                });
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

                    // Kamoi's top bar carries status only, on the right.
                    // No network name, no carrier, no cell identity.
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
                        visible: root.pageWindows.length > 0

                        RowLayout {
                            id: dockRow
                            anchors.centerIn: parent
                            spacing: 6

                            Repeater {
                                model: ScriptModel { values: root.pageWindows }

                                delegate: Rectangle {
                                    required property var modelData
                                    implicitWidth: 30
                                    implicitHeight: 30
                                    radius: 4
                                    // The active window is the only one marked,
                                    // matching Kamoi's borderless look.
                                    color: modelData.activated ? "#303030" : "transparent"

                                    // A toplevel has no wayland handle until
                                    // Hyprland reports its address, so appId is
                                    // briefly empty. Calling iconPath("") builds
                                    // a malformed url and the journal fills with
                                    //   Could not load icon "?fallback=..."
                                    readonly property string appId: {
                                        const wl = modelData.wayland;
                                        return wl && wl.appId ? wl.appId : "";
                                    }

                                    IconImage {
                                        anchors.centerIn: parent
                                        implicitSize: 20
                                        visible: source !== ""
                                        source: parent.appId === ""
                                            ? ""
                                            : Quickshell.iconPath(parent.appId, "application-x-executable")
                                    }

                                    // Until the icon resolves, show the first
                                    // letter rather than an empty square.
                                    Text {
                                        anchors.centerIn: parent
                                        visible: parent.appId === ""
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
                                            // dispatcher syntax differs under a
                                            // Lua config (Hyprland.usingLua),
                                            // and this path avoids the question.
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
      '';
    };
}
