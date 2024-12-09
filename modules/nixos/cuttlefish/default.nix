{
  config,
  inputs,
  system,
  lib,
  pkgs,
  ...
}: let
  inherit (inputs.self.packages.${system}) cuttlefish;

  cfg = config.services.cuttlefish;
in {
  options.services.cuttlefish = {
    enable = lib.mkEnableOption "Cuttlefish service";

    package = lib.mkOption {
      type = lib.types.package;
      description = "cuttlefi.sh package";
      default = cuttlefish;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.cuttlefish = {
      description = "cuttlefi.sh Downloader Service";
      script = "${cuttlefish}/bin/cuttlefi.sh --config /snowscape/podcasts/subscriptions.yaml";

      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        StateDirectory = "cuttlefi.sh";
        ConfigurationDirectory = "cuttlefi.sh";
        # Add required capabilities and security hardening
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          "/var/lib/cuttlefi.sh"
          "/snowscape/podcasts"
        ];
        RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = ["@system-service"];
        # Ensure network access is available
        IPAddressDeny = [];
        IPAddressAllow = [];
      };
    };

    systemd.timers.cuttlefish = {
      description = "Timer for Podcast Downloader Service";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "5min";
      };
    };
  };
}
