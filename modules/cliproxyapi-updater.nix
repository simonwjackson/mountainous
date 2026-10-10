# Unzen builds applications. This timer never rebuilds Rakku's NixOS system.
{
  nixos.modules.base =
    { config, lib, ... }:
    let
      cfg = config.mountainous.features.cliproxyapi-updater;
      state = "/var/lib/cliproxyapi-updater";
    in
    {
      options.mountainous.features.cliproxyapi-updater.enable =
        lib.mkEnableOption "nightly CLIProxyAPI releases built and deployed from Unzen";
      config = lib.mkIf cfg.enable {
        systemd.services.cliproxyapi-update = {
          description = "Build, check, and deploy latest stable CLIProxyAPI application";
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          unitConfig.ConditionPathExists = "${state}/enabled";
          environment = {
            HOME = state;
            LOCAL_KEY = "${state}/signing-key";
            NIX_REMOTE = "daemon";
          };
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            UMask = "0077";
            StateDirectory = "cliproxyapi-updater";
            StateDirectoryMode = "0700";
            WorkingDirectory = "${state}/repository";
            ExecStart = "/nix/var/nix/profiles/cliproxyapi-updater/bin/cliproxy-nightly-update";
            TimeoutStartSec = "90min";
            Nice = 10;
            CPUQuota = "400%";
            MemoryMax = "8G";
            TasksMax = 512;
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [
              state
              "/nix/var"
            ];
            PrivateTmp = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictRealtime = true;
          };
        };
        systemd.timers.cliproxyapi-update = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 03:00:00 UTC";
            RandomizedDelaySec = "15min";
            Persistent = true;
            Unit = "cliproxyapi-update.service";
          };
        };
      };
    };
}
