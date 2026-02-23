{ config, lib, pkgs, ... }:

let
  cfg = config.services.omi;
in {
  options.services.omi = {
    enable = lib.mkEnableOption "Omi wearable transcript pipeline";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*:0/15:00";
      description = "Systemd OnCalendar expression for the timer";
    };

    omiDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/simonwjackson/omi";
      description = "Working directory for Omi data";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "simonwjackson";
      description = "User to run the service as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = "Group to run the service as";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.omi-cron = {
      description = "Omi Pipeline - Sync transcripts from Omi API";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.omiDir;
      };
      environment = {
        HOME = "/home/${cfg.user}";
        OMI_API_KEY_FILE = config.age.secrets."omi-api-key".path;
      };
      path = with pkgs; [ curl jq coreutils bash util-linux gnused ]
        ++ [ pkgs.lifted-scripts.omi-pipeline pkgs.lifted-scripts.omi-cron ];
      script = ''
        exec omi-cron
      '';
    };

    systemd.timers.omi-cron = {
      description = "Run Omi Pipeline on schedule";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = false;
        RandomizedDelaySec = "30s";
      };
    };
  };
}
