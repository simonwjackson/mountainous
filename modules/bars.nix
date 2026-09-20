# The top bar and the window dock, as Quickshell.
#
# Kamoi's two bars: top bar (title, clock, battery, wifi) and bottom dock
# (all windows, all workspaces, click=activate, middle-click=close, drag-to-move).
# Meta+I toggles both for immersive browsing.
{
  nixos.modules.desktop =
    { config, lib, pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.quickshell ];

      # UPower is required for accurate battery percentage reporting.
      services.upower.enable = true;

      # A user service rather than exec-once, so the bars restart on their own
      # and their logs land in the journal instead of Hyprland's stdout.
      # Quickshell 0.3.1 can request pairing but cannot answer BlueZ
      # authentication callbacks. This no-input agent covers devices that use
      # Just Works pairing. The adapter remains non-pairable for unsolicited
      # incoming requests.
      systemd.user.services.bluetooth-pairing-agent = lib.mkIf config.hardware.bluetooth.enable {
        description = "BlueZ pairing agent for Quickshell";
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];

        serviceConfig = {
          ExecStart = "${pkgs.bluez-tools}/bin/bt-agent -c NoInputNoOutput";
          Restart = "on-failure";
          RestartSec = 2;
          Slice = "session.slice";
        };
      };

      systemd.user.services.quickshell = {
        description = "Quickshell: top bar and window dock";
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];

        environment = {
          # Pin the platform plugin so Qt never guesses xcb before WAYLAND_DISPLAY
          # reaches the unit.
          QT_QPA_PLATFORM = "wayland";
        };

        # Ensure user profile binaries (web-app, qs, hypr-scale) resolve on PATH.
        path = [ "/run/current-system/sw" ];

        serviceConfig = {
          ExecStart = "${pkgs.quickshell}/bin/qs -c mountainous";
          Restart = "on-failure";
          RestartSec = 2;
          Slice = "session.slice";
        };
      };

      hjem.users.simon.files.".config/quickshell/mountainous/shell.qml".source =
        ./quickshell/shell.qml;
      hjem.users.simon.files.".config/quickshell/mountainous/Theme.qml".source =
        ./quickshell/Theme.qml;
      hjem.users.simon.files.".config/quickshell/mountainous/TogglePill.qml".source =
        ./quickshell/TogglePill.qml;
      hjem.users.simon.files.".config/quickshell/mountainous/BluetoothPanel.qml".source =
        ./quickshell/BluetoothPanel.qml;
      hjem.users.simon.files.".config/quickshell/mountainous/WifiPanel.qml".source =
        ./quickshell/WifiPanel.qml;
    };
}
