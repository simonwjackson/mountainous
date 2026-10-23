# The top bar and the window dock, as Quickshell.
#
# Kamoi's two bars: top bar (title, clock, battery, wifi) and bottom dock
# (all windows, all workspaces, click=activate, middle-click=close, drag-to-move).
# Each screen gets its own pair, and each pair shows only that screen's
# windows. See quickshell/lanes.js.
# Meta+I toggles both for immersive browsing.
{
  perSystem =
    { pkgs, ... }:
    {
      # The builder control's words, actions, focus order and layout plans,
      # run under node from the same file QML loads.
      checks.builder-gate-view =
        pkgs.runCommand "builder-gate-view" { nativeBuildInputs = [ pkgs.nodejs ]; }
          ''
            node ${./quickshell/builder-gate.test.js} ${./quickshell/builder-gate.js}
            touch $out
          '';
    };

  nixos.modules.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      ociEgress = pkgs.writeShellApplication {
        name = "oci-egress-status";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.oci-cli
        ];
        text = builtins.readFile ./quickshell/oci-egress-status.sh;
      };
    in
    {
      environment.systemPackages = [
        pkgs.quickshell
        ociEgress
      ];

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
          OCI_EGRESS_ENABLED = "1";
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

      # Discover new controls and icons without a second Nix file list. The
      # notification view retains ownership of its files and generated schema.
      hjem.users.simon.files =
        let
          notificationFiles = [
            "Notifications.qml"
            "NotificationPopups.qml"
            "NotificationCentre.qml"
            "NotificationCard.qml"
            "NotificationButton.qml"
            "NotificationStyle.qml"
            "notification-model.js"
            "notification-schema.js"
          ];
          collect =
            prefix: directory:
            lib.concatLists (
              lib.mapAttrsToList (
                name: type:
                let
                  relative = prefix + name;
                in
                if type == "directory" then
                  lib.optionals (
                    !(builtins.elem name [
                      "notification-dev"
                      "builder-dev"
                    ])
                  ) (collect (relative + "/") (directory + "/${name}"))
                else
                  lib.optional (type == "regular") relative
              ) (builtins.readDir directory)
            );
          deliver =
            name:
            !(builtins.elem name notificationFiles)
            && !(lib.hasSuffix ".test.js" name)
            && !(lib.hasSuffix ".py" name)
            && !(lib.hasSuffix ".sh" name)
            # Test-only scene for the Win98 controls (themes/win98/dev/).
            && name != "themes/win98/Win98Gallery.qml"
            && (
              lib.hasSuffix ".qml" name
              || lib.hasSuffix ".js" name
              || lib.hasPrefix "icons/" name
              || lib.hasInfix "/icons/" name
            );
        in
        builtins.listToAttrs (
          map (name: {
            name = ".config/quickshell/mountainous/${name}";
            value.source = ./quickshell + "/${name}";
          }) (builtins.filter deliver (collect "" ./quickshell))
        );
      # Quickshell discovers pragma Singleton files itself. A partial qmldir
      # would hide the other local types (including Theme) from that scan.
    };
}
