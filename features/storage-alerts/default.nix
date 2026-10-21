# Push storage failures from Zao to the ntfy hub on Rakku.
#
# A copy of `modules/storage-alerts.nix` on the cairn branch, kept identical
# until Zao moves to cairn. The probe and the notify CLI come from the pinned
# cairn source (`inputs.notify-sync-src`); see that module for the rules.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  script = ./storage-alert.py;
  probe = "${inputs.notify-sync-src}/modules/storage-health-probe.sh";
  cfg = config.mountainous.features.storage-alerts;
  trigger = "storage-alert-trigger@%n.service";
  isMount = lib.hasSuffix ".mount";
  services = lib.filter (u: lib.hasSuffix ".service" u) cfg.units;
  mounts = lib.filter isMount cfg.units;
in {
  options.mountainous.features.storage-alerts = {
    enable = lib.mkEnableOption "storage failure alerts to the ntfy hub";
    profile = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Storage probe profile (zao, unzen).";
    };
    units = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [
        "towada-snapraid-sync.service"
        "srv-lakes-towada.mount"
      ];
      description = "Storage units whose failure starts an immediate check.";
    };
    notify = lib.mkOption {
      type = lib.types.package;
      description = "Package providing bin/notify.";
    };
    probe = lib.mkOption {
      type = lib.types.path;
      default = probe;
      description = "Storage health probe script.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "https://ntfy.hummingbird-lake.ts.net";
    };
    tokenFile = lib.mkOption {
      type = lib.types.str;
      description = "Runtime path of the storage-alerts publish-only token.";
    };
    buttonTokenFile = lib.mkOption {
      type = lib.types.str;
      description = "Runtime path of the write-only notify-ctl token used by the Done button.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services = lib.mkMerge [
      {
        storage-alert = {
          description = "Push new storage findings to the ntfy hub";
          after = ["network-online.target"];
          wants = ["network-online.target"];
          # The probe reads systemd, the journal, mounts and sysfs as root.
          path = with pkgs; [
            bash
            coreutils
            gawk
            gnugrep
            gnused
            util-linux
            systemd
            jq
            procps
            "/run/current-system/sw"
          ];
          environment = {
            NOTIFY_URL = cfg.url;
            NOTIFY_TOKEN_FILE = "%d/token";
            NOTIFY_BUTTON_TOKEN_FILE = "%d/button";
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.escapeShellArgs [
              "${pkgs.python3}/bin/python3"
              "${script}"
              "--probe"
              "${cfg.probe}"
              "--profile"
              cfg.profile
              "--state-dir"
              "/var/lib/storage-alerts"
              "--notify"
              "${cfg.notify}/bin/notify"
            ];
            LoadCredential = [
              "token:${cfg.tokenFile}"
              "button:${cfg.buttonTokenFile}"
            ];
            StateDirectory = "storage-alerts";
            StateDirectoryMode = "0700";
            TimeoutStartSec = "5min";
            Nice = 10;
            PrivateTmp = true;
            NoNewPrivileges = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            UMask = "0077";
          };
        };
        # Started by OnFailure. --no-block: never wait on the check.
        "storage-alert-trigger@" = {
          description = "Check storage now after %i failed";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.systemd}/bin/systemctl start --no-block storage-alert.service";
          };
        };
      }
      (lib.genAttrs (map (lib.removeSuffix ".service") services) (_: {
        onFailure = [trigger];
      }))
    ];
    # Mount units come from generators; a drop-in adds the hook.
    systemd.units = lib.genAttrs mounts (_: {
      overrideStrategy = "asDropin";
      text = ''
        [Unit]
        OnFailure=${trigger}
      '';
    });
    systemd.timers.storage-alert = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "5min";
        RandomizedDelaySec = "30s";
      };
    };
  };
}
