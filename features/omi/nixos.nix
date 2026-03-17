{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.mountainous.features.omi;
in {
  config = mkIf cfg.enable {
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
      path = with pkgs;
        [curl jq coreutils bash util-linux gnused]
        ++ [pkgs.lifted-scripts.omi-pipeline pkgs.lifted-scripts.omi-cron];
      script = ''
        exec omi-cron
      '';
    };

    systemd.timers.omi-cron = {
      description = "Run Omi Pipeline on schedule";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = false;
        RandomizedDelaySec = "30s";
      };
    };
  };
}
