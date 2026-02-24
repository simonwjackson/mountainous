{ config, lib, pkgs, ... }:

let
  cfg = config.services.ado-sync;

  ado-sync = pkgs.writeShellApplication {
    name = "ado-sync";
    runtimeInputs = with pkgs; [ curl jq coreutils ];
    text = builtins.readFile ./ado-sync.sh;
  };

in {
  options.services.ado-sync = {
    enable = lib.mkEnableOption "ado-sync — Azure DevOps work item sync";

    refreshTokenFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/ado-refresh-token";
      description = "Path to the agenix-managed ADO refresh token seed.";
    };

    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/simonwjackson/.cache/flakey/ado";
      description = "Directory for cached ADO data and mutable refresh token.";
    };

    calendar = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "*-*-* 15:00:00" "*-*-* 19:00:00" "*-*-* 00:00:00" ];
      description = "systemd OnCalendar expressions for sync frequency.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "simonwjackson";
      description = "User to run the sync as.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.ado-sync = {
      description = "Sync Azure DevOps work items";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        XDG_CACHE_HOME = "/home/${cfg.user}/.cache";
      };

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        ExecStart = "${ado-sync}/bin/ado-sync";
        # Ensure cache dir exists
        CacheDirectory = "";
        WorkingDirectory = "/home/${cfg.user}";
      };
    };

    systemd.timers.ado-sync = {
      description = "ADO sync timer";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = cfg.calendar;  # list of expressions
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };
  };
}
