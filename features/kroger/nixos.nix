{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.mountainous.features.kroger;
in {
  config = mkIf cfg.enable {
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
    systemd.services.kroger-weekly-deals = mkIf cfg.weeklyDeals.enable {
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
      path = [pkgs.lifted-scripts.kroger-weekly-deals];
      script = ''
        exec kroger-weekly-deals
      '';
    };

    systemd.timers.kroger-weekly-deals = mkIf cfg.weeklyDeals.enable {
      description = "Run Kroger weekly deals scan on schedule";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.weeklyDeals.schedule;
        Persistent = true;
        RandomizedDelaySec = "5min";
      };
    };
  };
}
