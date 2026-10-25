# Step 1 universal remote: no source credentials or playback service changes.
{ inputs, ... }:
{
  nixos.modules.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.pyxamp;
      sessionService =
        after:
        lib.mapAttrsRecursive (_: lib.mkDefault) {
          partOf = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ] ++ after;
          wantedBy = [ "graphical-session.target" ];
          # Wayland and Hyprland variables come from the user manager, populated
          # before hyprland-session.target starts (modules/hyprland.nix).
          environment.DBUS_SESSION_BUS_ADDRESS = "unix:path=%t/bus";
          path = [ "/run/current-system/sw" ];
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = 2;
            Slice = "session.slice";
          };
        };
    in
    {
      options.mountainous.features.pyxamp = {
        enable = lib.mkEnableOption "Pyxamp universal MPRIS remote and separate face";
        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.pyxamp.packages.${pkgs.stdenv.hostPlatform.system}.default;
          description = "Combined daemon and face, with its verified Quickshell runtime.";
        };
      };

      config = lib.mkMerge [
        { mountainous.features.pyxamp.enable = lib.mkDefault true; }
        (lib.mkIf cfg.enable {
          environment.systemPackages = [ cfg.package ];
          # Bare qs -c pyxamp IPC resolves the same config as the wrapper.
          # Keep global qs for the desktop bars; pyxamp runs its own qs 0.3.2.
          hjem.users.simon.files.".config/quickshell/pyxamp".source =
            lib.mkDefault "${cfg.package}/etc/xdg/quickshell/pyxamp";

          systemd.user.services.pyxamp-daemon = lib.mkMerge [
            (sessionService [ "pipewire.service" ])
            {
              description = lib.mkDefault "Pyxamp universal MPRIS remote";
              serviceConfig = {
                ExecStart = lib.mkDefault "${cfg.package}/bin/pyxamp-daemon";
                UMask = lib.mkDefault "0077";
                NoNewPrivileges = lib.mkDefault true;
              };
            }
          ];
          systemd.user.services.pyxamp = lib.mkMerge [
            (sessionService [ "pyxamp-daemon.service" ])
            {
              description = lib.mkDefault "Pyxamp Quickshell face";
              wants = [ "pyxamp-daemon.service" ];
              environment.QT_QPA_PLATFORM = lib.mkDefault "wayland";
              serviceConfig.ExecStart = lib.mkDefault "${cfg.package}/bin/pyxamp";
            }
          ];
        })
      ];
    };
}
