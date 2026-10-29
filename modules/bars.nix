# The top bar and the window dock, as Quickshell.
#
# Kamoi's two bars: top bar (title, clock, battery, wifi) and bottom dock
# (all windows, all workspaces, click=activate, middle-click=close, drag-to-move).
# Each screen gets its own pair, and each pair shows only that screen's
# windows. See quickshell/lanes.js.
# Meta+I toggles both for immersive browsing.
{ inputs, ... }:
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
      userRuntimeDir = "/run/user/${toString config.users.users.simon.uid}";
      # Quickshell with a runtime icon-theme setter (lib/quickshell.nix):
      # the bars' app icons follow the desktop theme's icon theme live.
      quickshell = import ../lib/quickshell.nix { inherit pkgs; };
      runtimeOverride =
        (config.systemd.globalEnvironment // config.systemd.user.services.quickshell.environment)
        .XDG_RUNTIME_DIR or null;
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
      assertions = [
        {
          assertion = runtimeOverride == null || runtimeOverride == userRuntimeDir;
          message = "Quickshell Launcher scopes require the real user-manager XDG_RUNTIME_DIR (${userRuntimeDir}); a private runtime needs an explicit manager transport adapter.";
        }
      ];

      environment.systemPackages = [
        quickshell
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
        # Hjem's ordered hook is the only switch-time restart owner. The NixOS
        # user switch runs earlier, before sysinit-reactivation links the home.
        restartIfChanged = false;
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];

        environment = {
          # Pin the platform plugin so Qt never guesses xcb before WAYLAND_DISPLAY
          # reaches the unit.
          QT_QPA_PLATFORM = "wayland";
          QML2_IMPORT_PATH = "${
            inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
          }/lib/qt-6/qml:${pkgs.qt6.qtwebsockets}/lib/qt-6/qml";
          OCI_EGRESS_ENABLED = "1";
        };

        # Ensure user profile binaries (web-app, qs, hypr-scale) resolve on PATH.
        path = [
          "/run/current-system/sw"
          pkgs.systemd
          pkgs.coreutils
        ];

        serviceConfig = {
          ExecStart = "${quickshell}/bin/qs -c mountainous";
          Restart = "on-failure";
          RestartSec = 2;
          Slice = "session.slice";
          # GUI apps live in app.slice scopes. Kill leftover service helpers
          # too, including a recorder whose QML owner no longer runs.
          # Legacy apps need the deploy-time runtime override in desktop-safety.md.
          KillMode = "mixed";
          WatchdogSec = "20s";
          WatchdogSignal = "SIGKILL";
          NotifyAccess = "all";
        };
      };

      # Hjem's system unit completes all links, then reloads user units. A user
      # service cannot order itself After= a system-manager unit. Restart here,
      # after the reload phase, so Quickshell never relies on an inotify reload
      # part way through linking a generation. Do not start a stopped desktop.
      systemd.services."hjem-reload@".serviceConfig.ExecStartPost = [
        "${
          lib.getExe (
            pkgs.writeShellApplication {
              name = "quickshell-after-hjem";
              runtimeInputs = [
                pkgs.systemd
                pkgs.coreutils
              ];
              text = builtins.readFile ../scripts/quickshell-after-hjem;
            }
          )
        } %i"
      ];

      # Discover new controls and icons without a second Nix file list. The
      # notification view retains ownership of its files and generated schema.
      hjem.users.simon.files =
        let
          notificationFiles = [
            "Notifications.qml"
            "NotificationPopups.qml"
            "panels/NotificationCentre.qml"
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
                      "theme-dev"
                      # themes/win98/dev: the control gallery and its scripts.
                      "dev"
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
            && (
              lib.hasSuffix ".qml" name
              || lib.hasSuffix ".js" name
              || name == "themes.json"
              || lib.hasPrefix "themes/" name
              || lib.hasPrefix "icons/" name
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
