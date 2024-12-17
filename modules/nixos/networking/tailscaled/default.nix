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
        "--netfilter-mode=off"
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
            ''
              #!${pkgs.bash}/bin/bash
              set -euo pipefail

              # Trap signals
              trap 'echo "Received signal, exiting..."; exit 1' TERM INT

              echo "Starting Tailscale connection process..."

              # Function to check if tailscaled is fully ready
              check_tailscale_ready() {
                ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1
                return $?
              }

              # Wait for tailscaled to be fully ready
              max_attempts=30
              attempt=1
              while ! check_tailscale_ready; do
                if [ $attempt -ge $max_attempts ]; then
                  echo "Tailscale daemon not ready after $max_attempts attempts, failing!"
                  exit 1
                fi
                echo "Waiting for tailscale daemon (attempt $attempt/$max_attempts)..."
                sleep 2
                attempt=$((attempt + 1))
              done

              # Function to check network connectivity
              check_network() {
                ${pkgs.iproute2}/bin/ip route | grep -q default && \
                ${pkgs.iputils}/bin/ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1
                return $?
              }

              # Wait for network connectivity
              max_attempts=30
              attempt=1
              while ! check_network; do
                if [ $attempt -ge $max_attempts ]; then
                  echo "Network not ready after $max_attempts attempts, failing!"
                  exit 1
                fi
                echo "Waiting for network connectivity (attempt $attempt/$max_attempts)..."
                sleep 2
                attempt=$((attempt + 1))
              done

              echo "Network and Tailscale daemon are ready, proceeding with authentication..."

              # Check if we need to authenticate
              if ${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -e '.BackendState == "NeedsLogin"' >/dev/null; then
                if [ ! -f ${cfg.authKeyFile} ] || [ ! -r ${cfg.authKeyFile} ]; then
                  echo "Auth key file missing or not readable!"
                  exit 1
                fi

                echo "Authenticating with Tailscale..."
                # Run tailscale up with a timeout
                timeout 30s ${pkgs.tailscale}/bin/tailscale up ${args} --authkey="$(cat ${cfg.authKeyFile})"
                exit_code=$?

                if [ $exit_code -ne 0 ]; then
                  echo "Tailscale authentication failed with exit code $exit_code"
                  exit $exit_code
                fi
              else
                echo "Tailscale already authenticated"
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
      ];

      requires = [
        "network-online.target"
        "tailscaled.service"
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
