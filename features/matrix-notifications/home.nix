{
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  cfg = osConfig.mountainous.features.matrix-notifications or {};
  enabled = cfg.enable or false;

  # Build the ExecStart command via a wrapper script to avoid systemd
  # quoting issues with room IDs (which contain ! and : characters).
  startScript = pkgs.writeShellScript "matrix-notify-daemon-start" ''
    exec ${pkgs.matrix-notify-daemon}/bin/matrix-notify-daemon \
      --homeserver ${lib.escapeShellArg cfg.homeserverUrl} \
      --user-id ${lib.escapeShellArg cfg.userId} \
      --access-token-file ${lib.escapeShellArg (toString cfg.accessTokenFile)} \
      --rooms ${lib.escapeShellArgs cfg.rooms}
  '';
in {
  config = lib.mkIf enabled {
    systemd.user.services.matrix-notify-daemon = {
      Unit = {
        Description = "Matrix desktop notification daemon with dismiss sync";
        # Start after the graphical session is ready (Hyprland + mako running).
        # PartOf ensures the daemon stops when the session ends.
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };

      Service = {
        ExecStart = "${startScript}";
        Restart = "on-failure";
        RestartSec = 10;
      };

      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}
