{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;

  cfg = config.mountainous.services.gamescope-reaper;
  package = pkgs.callPackage ./gamescope-reaper-package.nix {};
in {
  options.mountainous.services.gamescope-reaper = {
    enable = mkEnableOption "Gamescope process monitor service";

    interval = mkOption {
      type = types.int;
      default = 5;
      description = "Check interval in seconds";
    };

    duration = mkOption {
      type = types.int;
      default = 10;
      description = "Minimum runtime in seconds before termination";
    };

    processNames = mkOption {
      type = types.listOf types.str;
      default = ["gamescope-wl" "gamescope"];
      description = "List of process names to monitor";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.gamescope-reaper = {
      description = "Gamescope Process Monitor";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${package}/bin/gamescope-reaper ${toString (builtins.concatStringsSep " " cfg.processNames)} -d ${toString cfg.duration} -i ${toString cfg.interval}";
        Restart = "always";
        RestartSec = 10;

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        MemoryDenyWriteExecute = true;
      };
    };
  };
}
