{ config, lib, pkgs, ... }:

let
  cfg = config.services.omi;
in {
  options.services.omi = {
    enable = lib.mkEnableOption "Omi wearable transcript pipeline";

    interval = lib.mkOption {
      type = lib.types.str;
      default = "15min";
      description = "How often to run the pipeline (systemd OnUnitActiveSec format)";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*:0/15:00";
      description = "Systemd OnCalendar expression for the timer";
    };

    chatId = lib.mkOption {
      type = lib.types.str;
      default = "6371873126";
      description = "Telegram chat ID to send notifications to";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the Telegram bot token";
    };

    groqEnvFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to Groq API environment file";
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
      description = "Omi Pipeline - Sync, process, and notify via Telegram";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.omiDir;
        EnvironmentFile = cfg.groqEnvFile;
      };
      environment = {
        HOME = "/home/${cfg.user}";
        TELEGRAM_BOT_TOKEN_FILE = toString cfg.tokenFile;
        TELEGRAM_CHAT_ID = cfg.chatId;
      };
      path = with pkgs; [ curl jq coreutils bash util-linux gnugrep gnused ]
        ++ [ pkgs.lifted-scripts.omi-pipeline pkgs.lifted-scripts.omi-notify pkgs.lifted-scripts.omi-cron ];
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
