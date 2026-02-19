{ config, lib, pkgs, ... }:

let
  cfg = config.services.kroger;
in {
  options.services.kroger = {
    enable = lib.mkEnableOption "Kroger/King Soopers grocery API tools";

    storeId = lib.mkOption {
      type = lib.types.str;
      default = "62000082";
      description = "Kroger location ID (default: King Soopers Golden Road)";
    };

    clientIdFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing Kroger API client ID";
    };

    clientSecretFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing Kroger API client secret";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "simonwjackson";
      description = "User to run Kroger services as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = "Group to run Kroger services as";
    };

    weeklyDeals = {
      enable = lib.mkEnableOption "weekly keto deals scan";

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "Wed *-*-* 09:00:00";
        description = "Systemd OnCalendar expression for weekly deals scan";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Secrets
    age.secrets."kroger-client-id" = {
      file = ../../secrets/kroger-client-id.age;
      owner = cfg.user;
      mode = "0400";
    };

    age.secrets."kroger-client-secret" = {
      file = ../../secrets/kroger-client-secret.age;
      owner = cfg.user;
      mode = "0400";
    };

    # Put kroger tools in system PATH
    environment.systemPackages = [
      pkgs.lifted-scripts.kroger
      pkgs.lifted-scripts.kroger-weekly-deals
      pkgs.lifted-scripts.kroger-weekly-keto
      pkgs.lifted-scripts.kroger-add-to-cart
      pkgs.lifted-scripts.kroger-analyze-prices
      pkgs.lifted-scripts.kroger-fix-search
    ];

    # Weekly deals timer (optional)
    systemd.services.kroger-weekly-deals = lib.mkIf cfg.weeklyDeals.enable {
      description = "Scan King Soopers for keto-friendly sale items";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
      };
      environment = {
        HOME = "/home/${cfg.user}";
        KROGER_CLIENT_ID_FILE = toString cfg.clientIdFile;
        KROGER_CLIENT_SECRET_FILE = toString cfg.clientSecretFile;
        KROGER_STORE_ID = cfg.storeId;
      };
      path = [ pkgs.lifted-scripts.kroger-weekly-deals ];
      script = ''
        exec kroger-weekly-deals
      '';
    };

    systemd.timers.kroger-weekly-deals = lib.mkIf cfg.weeklyDeals.enable {
      description = "Run Kroger weekly deals scan on schedule";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.weeklyDeals.schedule;
        Persistent = true;
        RandomizedDelaySec = "5min";
      };
    };
  };
}
