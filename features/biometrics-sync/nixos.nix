{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  cfg = config.mountainous.features.biometrics-sync;
  home = "/home/${cfg.user}";

  commonPath = with pkgs; [
    curl
    jq
    coreutils
    bash
    python3
  ];
in {
  config = mkIf cfg.enable (mkMerge [
    # Always install CLI tools when the feature is enabled
    {
      environment.systemPackages = with pkgs.lifted-scripts; [
        biometrics-oura-sync
        biometrics-withings-sync
        biometrics-ketomojo-sync
        biometrics-import-saa
        biometrics-withings-auth
      ];
    }

    # ── Oura ────────────────────────────────────────────────────────────
    (mkIf cfg.oura.enable {
      systemd.services.biometrics-oura-sync = {
        description = "Sync Oura Ring data";
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
        };
        path = commonPath ++ [pkgs.lifted-scripts.biometrics-oura-sync];
        script = ''
          export HOME=${home}
          biometrics-oura-sync
        '';
      };

      systemd.timers.biometrics-oura-sync = {
        description = "Oura Ring sync timer";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cfg.oura.schedule;
          Persistent = true;
        };
      };
    })

    # ── Withings ────────────────────────────────────────────────────────
    (mkIf cfg.withings.enable {
      systemd.services.biometrics-withings-sync = {
        description = "Sync Withings scale data";
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
        };
        path = commonPath ++ [pkgs.lifted-scripts.biometrics-withings-sync];
        script = ''
          export HOME=${home}
          biometrics-withings-sync
        '';
      };

      systemd.timers.biometrics-withings-sync = {
        description = "Withings sync timer";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cfg.withings.schedule;
          Persistent = true;
        };
      };
    })

    # ── Keto-Mojo ──────────────────────────────────────────────────────
    (mkIf cfg.ketomojo.enable {
      systemd.services.biometrics-ketomojo-sync = {
        description = "Sync Keto-Mojo readings";
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
        };
        path = commonPath ++ [pkgs.lifted-scripts.biometrics-ketomojo-sync];
        script = ''
          export HOME=${home}
          biometrics-ketomojo-sync
        '';
      };

      systemd.timers.biometrics-ketomojo-sync = {
        description = "Keto-Mojo sync timer";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cfg.ketomojo.schedule;
          Persistent = true;
        };
      };
    })
  ]);
}
