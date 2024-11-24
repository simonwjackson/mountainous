{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.mountainous.networking.tailscaled;
  args =
    cfg.extraArgs
    + " "
    + "--advertise-exit-node="
    + (
      if cfg.exit-node
      then "true"
      else "false"
    );
in {
  options.mountainous.networking.tailscaled = {
    enable = lib.mkEnableOption "Tailscale Daemon";

    extraArgs = lib.mkOption {
      type = lib.types.str;
      description = "Extra args";
      default = "";
    };

    exit-node = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Exit node
      '';
    };

    serve = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = ''
        Port number to enable Tailscale serve service.
        If null, the serve service will be disabled.
      '';
    };

    authKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the file containing the Tailscale authentication key";
      example = "/run/secrets/tailscale-authkey";
    };

    waitForNetworkOnline = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to wait for network-online.target before starting Tailscale.
        Recommended to keep enabled unless you have specific reasons not to.
      '';
    };

    autoConnect = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to automatically connect to Tailscale at boot using the provided authkey.
        Enabled by default.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      tailscale
    ];

    services.tailscale = {
      enable = true;
      useRoutingFeatures =
        if cfg.exit-node
        then "both"
        else "client";
      authKeyFile =
        lib.mkIf (
          !config.boot.isContainer && cfg.autoConnect
        )
        cfg.authKeyFile;
      extraUpFlags = [
        "--socket=/var/run/tailscale/tailscaled.sock"
        "--operator=root"
      ];
    };

    systemd.services.tailscale-autoconnect =
      lib.mkIf (
        config.boot.isContainer && cfg.autoConnect
      ) {
        description = "Automatic connection to Tailscale";

        after = [
          "network-online.target"
          "tailscaled.service"
          "network.target"
          "network-pre.target"
          "systemd-networkd.service"
        ];
        requires = ["network-online.target" "tailscaled.service"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = "yes";
          Restart = "on-failure";
          RestartSec = "10s";
          RestartMaxDelay = "60s";
          StartLimitIntervalSec = "5min";
          StartLimitBurst = "3";

          # Add signal handling and timeout configuration
          TimeoutStartSec = "30s";
          TimeoutStopSec = "10s";
          KillMode = "mixed";
          KillSignal = "SIGTERM";
          SendSIGKILL = "yes";

          # Execute the script directly instead of through bash
          ExecStart =
            pkgs.writeScript "tailscale-connect"
            # bash
            ''
              #!${pkgs.bash}/bin/bash
              set -euo pipefail
              # x

              # Trap signals
              trap 'echo "Received signal, exiting..."; exit 1' TERM INT

              # Check tailscale service
              if ! ${pkgs.systemd}/bin/systemctl is-active --quiet tailscaled.service; then
                echo "Tailscale service not active!"
                exit 1
              fi

              # Wait a bit for network setup
              sleep 2

              # Check if we need to authenticate
              if ${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -e '.BackendState == "NeedsLogin"' >/dev/null; then
                if [ ! -f ${cfg.authKeyFile} ] || [ ! -r ${cfg.authKeyFile} ]; then
                  echo "Auth key file missing or not readable!"
                  exit 1
                fi

                # Run tailscale up with a timeout
                timeout 20s ${pkgs.tailscale}/bin/tailscale up ${args} --authkey="$(cat ${cfg.authKeyFile})"
                exit_code=$?

                if [ $exit_code -ne 0 ]; then
                  echo "Tailscale authentication failed with exit code $exit_code"
                  exit $exit_code
                fi
              fi

              echo "Tailscale connection completed successfully"
            '';
        };
      };

    systemd.services."tailscale-serve-${toString cfg.serve}" = lib.mkIf (cfg.serve != null) {
      description = "Tailscale serve on port ${toString cfg.serve}";

      after = [
        "network-online.target"
        "tailscaled.service"
        "network.target"
        "network-pre.target"
        "systemd-networkd.service"
        # "slskd.service"
      ];

      requires = [
        "network-online.target"
        "tailscaled.service"
        # "slskd.service"
      ];

      bindsTo = ["tailscaled.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        RemainAfterExit = "yes";
        Restart = "on-failure";
        RestartSec = "10s";
        RestartMaxDelay = "60s";
        StartLimitIntervalSec = "5min";
        StartLimitBurst = "3";

        TimeoutStartSec = "60s";
        TimeoutStopSec = "10s";
        KillMode = "mixed";
        KillSignal = "SIGTERM";
        SendSIGKILL = "yes";

        # Run as root to ensure proper permissions
        User = "root";
        Group = "root";

        Environment = "TS_SOCKET=/var/run/tailscale/tailscaled.sock";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve ${toString cfg.serve}";

        # Root needs access to these directories
        ReadWritePaths = [
          "/var/run/tailscale"
          "/var/lib/tailscale"
          "/var/cache/tailscale"
        ];
      };
    };

    boot.kernelModules = ["tun"];

    networking.firewall = {
      allowedTCPPortRanges = [
        {
          from = 1;
          to = 65535;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 1;
          to = 65535;
        }
      ];

      allowPing = true;
      trustedInterfaces = lib.mkAfter ["tailscale0"];
      allowedUDPPorts = [config.services.tailscale.port];
    };
  };
}
