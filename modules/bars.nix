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
        # QtWebSockets is not in Quickshell's own closure -- it is built
        # against qtbase, qtdeclarative, qtsvg and qtwayland only. Adding it
        # here is what lets modules/browser.nix speak the DevTools protocol
        # from QML with no helper binary. The version must match Quickshell's
        # Qt exactly; both are 6.11.2.
        environment = {
          QML2_IMPORT_PATH = "${pkgs.qt6.qtwebsockets}/lib/qt-6/qml";

          # Pin the platform plugin. Without it Qt guesses, and on a login it
          # guessed wrong and took the whole shell down:
          #
          #   WARN qt.qpa.xcb: could not connect to display
          #   FATAL: This application failed to start because no Qt platform
          #          plugin could be initialized.
          #   ERROR: Quickshell crashed within 10 seconds of launching.
          #          Not restarting to avoid a crash loop.
          #
          # Two things made that fatal rather than transient. Qt tried xcb
          # because WAYLAND_DISPLAY had not reached the unit's environment
          # yet, and Quickshell's own guard then refused to retry, so nothing
          # brought the bars back even once the session was up. Naming the
          # plugin removes the guess entirely.
          QT_QPA_PLATFORM = "wayland";
        };

        # A systemd user service is handed a minimal PATH. Measured on hiyori
        # it carried only coreutils, findutils, gnugrep, gnused and systemd,
        # so anything the shell spawns -- web-app, qs, hypr-scale, grim --
        # failed with "Process failed to start, likely because the binary
        # could not be found", and did so at warning level with exit status 0
        # from the caller's point of view.
        path = [ "/run/current-system/sw" ];

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
        import Quickshell.Networking
        import Quickshell.Widgets
        import Quickshell.Services.UPower
        import QtQuick
        import QtQuick.Layouts

        ShellRoot {
            id: root

            // Kamoi Meta+I hides the top bar and the dock together.
            property bool chromeVisible: true

            // The omni bar. Its component lives in modules/omni.nix, which
            // QML resolves by filename from this directory.
            OmniBar { id: omniBar }

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

            // Which page a window is on, or -1 while it is between pages.
            //
            // allWindows filters on t.workspace before building the list, but
            // that only makes the list safe at the moment it is built. Each
            // delegate binding re-runs when the property changes, and Hyprland
            // nulls workspace while it moves or closes a window, so the filter
            // cannot protect the delegate. Reproduced on hiyori by moving one
            // window across pages and closing it:
            //
            //   WARN scene: @shell.qml[242]: TypeError: Cannot read property
            //                                'id' of null
            //   WARN scene: @shell.qml[272]: same
            //
            // -1 is safe as the unknown value because allWindows keeps only
            // ids above zero; special workspaces are already excluded.
            function pageOf(toplevel) {
                return (toplevel && toplevel.workspace) ? toplevel.workspace.id : -1;
            }

            // Hyprland addresses a window as address:0x... in a dispatcher.
            // The Wayland handle carries no address, so it comes from the last
            // IPC payload, which is empty until Hyprland has reported the
            // window once.
            function addressOf(toplevel) {
                const o = toplevel ? toplevel.lastIpcObject : null;
                return (o && o.address) ? o.address : "";
            }

            // Kamoi's dock shows one page, so dragging an icon onto another
            // swaps two window positions. This dock shows every page, which
            // makes a drop across a page boundary mean something else: send
            // the window to that page. Inside one page it still swaps.
            //
            // Both actions go through hyprctl rather than the Wayland toplevel
            // protocol, because neither has a protocol equivalent. The two
            // dispatchers differ in shape, measured on hiyori:
            //
            //   window.move accepts `window`, so it names its own subject.
            //   window.swap does not. It acts on the focused window, so the
            //   dragged window has to be focused first, in the same batch to
            //   keep the two steps from racing.
            function dropOnto(fromIndex, toIndex) {
                if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return;

                const from = root.allWindows[fromIndex];
                const to   = root.allWindows[toIndex];
                const a = root.addressOf(from);
                const b = root.addressOf(to);
                if (a === "" || b === "") return;

                const fromPage = root.pageOf(from);
                const toPage   = root.pageOf(to);
                if (fromPage < 0 || toPage < 0) return;

                if (fromPage === toPage) {
                    Quickshell.execDetached(["hyprctl", "--batch",
                        'dispatch hl.dsp.focus({ window = "address:' + a + '" }) ; '
                        + 'dispatch hl.dsp.window.swap({ target = "address:' + b + '" })']);
                } else {
                    Quickshell.execDetached(["hyprctl", "dispatch",
                        'hl.dsp.window.move({ window = "address:' + a + '", '
                        + 'workspace = ' + toPage + ' })']);
                }
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
                    //
                    // Both items here are readouts, not controls, so they may
                    // shrink or truncate if they ever compete for width. They
                    // cannot collide with the centred clock above roughly
                    // 290px of panel width, which no real display is below.
                    // Noted rather than defended with machinery.
                    RowLayout {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 10
                        spacing: 12

                        // Wi-Fi strength. The one status item Kamoi's README
                        // actually specifies, at line 32:
                        //
                        //   "The top bar shows Wi-Fi and cellular signal
                        //    strength as fixed-width Lucide icons. It does not
                        //    show a network name, carrier name, or cell
                        //    identity."
                        //
                        // Strength only, never the SSID, and a fixed 11px so
                        // the bar never reflows as the signal moves. No
                        // cellular rung: the Galaxy Book3 has no cellular
                        // radio, and Kamoi draws no icon for an absent radio.
                        //
                        // Written against Quickshell 0.3.1's own
                        // quickshell-network.qmltypes:
                        //   Networking    singleton, devices UntypedObjectModel
                        //   NetworkDevice type DeviceType::Enum, connected,
                        //                 networks
                        //   WifiDevice  : NetworkDevice
                        //   WifiNetwork : Network, signalStrength double
                        //
                        // signalStrength is 0.0 to 1.0, not 0 to 100. Measured
                        // on hiyori against nmcli on the same association:
                        // nmcli said 81, this said 0.8.
                        //
                        // The NetworkManager backend fills in over D-Bus after
                        // the engine loads. Sampled on hiyori: at 1.5s
                        // devices=0 and wifiEnabled=false, at 3.0s the device
                        // is present. Every property read here is notifiable,
                        // so the bindings simply fill in and nothing polls.
                        Row {
                            id: wifi
                            spacing: 1
                            height: 9
                            Layout.alignment: Qt.AlignVCenter
                            visible: Networking.wifiHardwareEnabled

                            readonly property var device: {
                                if (!Networking.devices) return null;
                                const found = [...Networking.devices.values].filter(function (d) {
                                    return d.type === DeviceType.Wifi;
                                });
                                return found.length > 0 ? found[0] : null;
                            }

                            readonly property var network: {
                                const d = wifi.device;
                                if (!d || !d.connected || !d.networks) return null;
                                const up = [...d.networks.values].filter(function (n) {
                                    return n.connected;
                                });
                                return up.length > 0 ? up[0] : null;
                            }

                            // Four rungs, so one bar is a quarter of the scale.
                            // Zero bars means the radio is on with no link,
                            // which is a different fact from having no radio.
                            readonly property int level: {
                                if (!wifi.network) return 0;
                                const s = wifi.network.signalStrength;
                                if (s >= 0.75) return 4;
                                if (s >= 0.5) return 3;
                                if (s >= 0.25) return 2;
                                return 1;
                            }

                            Repeater {
                                model: 4
                                Rectangle {
                                    required property int index
                                    width: 2
                                    height: 3 + index * 2
                                    y: wifi.height - height
                                    color: index < wifi.level ? "#e0e0e0" : "#404040"
                                }
                            }
                        }

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
                        id: dock
                        anchors.centerIn: parent
                        implicitWidth: dockRow.implicitWidth + 16
                        implicitHeight: 38
                        radius: 6
                        color: "#141414"
                        visible: root.allWindows.length > 0

                        // -1 means no drag is in progress. Holding both ends
                        // here rather than in each icon keeps one owner for the
                        // gesture, so the icons only read it.
                        property int dragIndex: -1
                        property int dropIndex: -1

                        // The row is one flat strip, so the icon under the
                        // pointer is whatever child sits at that x. childAt
                        // returns the slot, and each slot knows its own index.
                        function slotIndexAt(x, y) {
                            const item = dockRow.childAt(x, y);
                            return (item && item.slotIndex !== undefined) ? item.slotIndex : -1;
                        }

                        RowLayout {
                            id: dockRow
                            anchors.centerIn: parent
                            spacing: 6

                            Repeater {
                                model: ScriptModel { values: root.allWindows }

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    // dock.slotIndexAt reads this off whatever
                                    // childAt returns, so a drop can name the
                                    // window it landed on.
                                    readonly property int slotIndex: index

                                    // A hairline before the first window of each
                                    // workspace, so the strip's shape is visible
                                    // without labelling every group.
                                    readonly property bool startsWorkspace: {
                                        if (index === 0) return false;
                                        const here = root.pageOf(modelData);
                                        const prev = root.pageOf(root.allWindows[index - 1]);
                                        // While either window is between pages,
                                        // draw nothing rather than a separator
                                        // that moves again a moment later.
                                        if (here < 0 || prev < 0) return false;
                                        return here !== prev;
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
                                        opacity: {
                                            const page = root.pageOf(modelData);
                                            // A window between pages is not on
                                            // the focused one as far as anybody
                                            // can tell, so it stays dimmed.
                                            if (page < 0 || !Hyprland.focusedWorkspace) return 0.45;
                                            return page === Hyprland.focusedWorkspace.id ? 1.0 : 0.45;
                                        }

                                        // A toplevel has no wayland handle until
                                        // Hyprland reports its address, so appId
                                        // is briefly empty. iconPath("") builds a
                                        // malformed url and the journal fills up
                                        // with: Could not load icon "?fallback="
                                        readonly property string appId: {
                                            const wl = modelData.wayland;
                                            return wl && wl.appId ? wl.appId : "";
                                        }

                                        // A window class is not an icon name.
                                        // Chromium reports the class
                                        // chromium-browser while its icon is
                                        // named chromium, so asking the theme
                                        // for the class filled the journal
                                        // with: Could not load icon
                                        // "chromium-browser?fallback=...".
                                        //
                                        // The desktop entry is the mapping
                                        // between the two. heuristicLookup
                                        // matches on id, name and
                                        // StartupWMClass, which is how the
                                        // --app web apps resolve: their class
                                        // is chrome-<host>__-Default and only
                                        // their entry knows that.
                                        readonly property string iconName: {
                                            if (cell.appId === "") return "";
                                            const e = DesktopEntries.heuristicLookup(cell.appId);
                                            return (e && e.icon) ? e.icon : cell.appId;
                                        }

                                        IconImage {
                                            anchors.centerIn: parent
                                            implicitSize: 20
                                            visible: source !== ""
                                            source: cell.iconName === ""
                                                ? ""
                                                : Quickshell.iconPath(cell.iconName, "application-x-executable")
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

                                        // The icon lifts while it is dragged, and
                                        // the icon under the pointer lights up, so
                                        // the drop target is never a guess.
                                        scale: dock.dragIndex === index ? 1.18 : 1.0
                                        border.width: dock.dropIndex === index
                                                      && dock.dragIndex !== index ? 1 : 0
                                        border.color: "#6a9fb5"

                                        MouseArea {
                                            id: grip
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                            // A click and a drag start the same
                                            // way, so the gesture only becomes a
                                            // drag after the pointer travels far
                                            // enough to rule out a shaky click.
                                            readonly property int threshold: 8
                                            property real pressX: 0
                                            property bool dragging: false

                                            function targetAt(mx, my) {
                                                const p = grip.mapToItem(dockRow, mx, my);
                                                return dock.slotIndexAt(p.x, p.y);
                                            }

                                            onPressed: function (mouse) {
                                                grip.pressX = mouse.x;
                                                grip.dragging = false;
                                            }

                                            onPositionChanged: function (mouse) {
                                                if (!(mouse.buttons & Qt.LeftButton)) return;
                                                if (!grip.dragging
                                                    && Math.abs(mouse.x - grip.pressX) < grip.threshold) return;
                                                grip.dragging = true;
                                                dock.dragIndex = index;
                                                dock.dropIndex = grip.targetAt(mouse.x, mouse.y);
                                            }

                                            onReleased: function (mouse) {
                                                if (!grip.dragging) return;
                                                root.dropOnto(index, grip.targetAt(mouse.x, mouse.y));
                                                dock.dragIndex = -1;
                                                dock.dropIndex = -1;
                                            }

                                            // A release after a drag still emits
                                            // clicked, and activating the window
                                            // there would undo the drop by pulling
                                            // focus to the old page.
                                            onClicked: function (mouse) {
                                                if (grip.dragging) { grip.dragging = false; return; }
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

                                            onCanceled: {
                                                grip.dragging = false;
                                                dock.dragIndex = -1;
                                                dock.dropIndex = -1;
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
