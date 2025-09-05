{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.tsnet-proxy;
in {
  options.mountainous.tsnet-proxy = {
    enable = mkEnableOption "tsnet-based Tailscale proxy services";

    authKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Default Tailscale auth key file for all services";
      example = "/run/secrets/tailscale";
    };

    services = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          hostname = mkOption {
            type = types.str;
            description = "Tailscale hostname for this proxy node";
            example = "mesh-aka";
          };

          protocol = mkOption {
            type = types.enum ["http" "https"];
            default = "http";
            description = "Backend protocol";
          };

          port = mkOption {
            type = types.int;
            description = "Backend port on localhost";
            example = 8080;
          };

          authKeyFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Tailscale auth key file (overrides top-level authKeyFile)";
            example = "/run/secrets/tailscale-mesh";
          };

          listenPort = mkOption {
            type = types.str;
            default = "443";
            description = "Port for tsnet to listen on (80 or 443)";
            example = "443";
          };

          package = mkOption {
            type = types.package;
            default = pkgs.callPackage ../../../packages/tsnet-proxy {};
            description = "tsnet-proxy package to use";
          };
        };
      });
      default = {};
      description = "tsnet proxy service configurations";
      example = {
        usenet = {
          hostname = "usenet";
          protocol = "http";
          port = 8080;
        };
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services = lib.mapAttrs' (serviceName: serviceConfig: {
      name = "tsnet-proxy-${serviceName}";
      value = {
        description = "tsnet proxy service for ${serviceName}";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        
        serviceConfig = {
          Type = "simple";
          User = "tsnet-proxy";
          Group = "tsnet-proxy";
          Restart = "always";
          RestartSec = "10";
          
          # Create state directory
          StateDirectory = "tsnet-proxy-${serviceName}";
          StateDirectoryMode = "0700";
          
          # Security hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectHostname = true;
          ProtectClock = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
          RestrictNamespaces = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          RemoveIPC = true;
        };

        environment = {
          TS_STATE_DIR = "/var/lib/tsnet-proxy-${serviceName}";
          HOME = "/var/lib/tsnet-proxy-${serviceName}";
        };

        script = let
          effectiveAuthKeyFile = if serviceConfig.authKeyFile != null 
            then serviceConfig.authKeyFile 
            else cfg.authKeyFile;
          backendUrl = "${serviceConfig.protocol}://localhost:${toString serviceConfig.port}";
        in ''
          # Debug environment
          echo "HOME=$HOME"
          echo "TS_STATE_DIR=$TS_STATE_DIR"
          
          export TS_AUTHKEY="$(cat ${effectiveAuthKeyFile} | tr -d '\n')"
          
          # Debug auth key (show first and last few chars for security)
          echo "TS_AUTHKEY length: ''${#TS_AUTHKEY}"
          echo "TS_AUTHKEY start: ''${TS_AUTHKEY:0:15}..."
          echo "TS_AUTHKEY end: ...''${TS_AUTHKEY: -10}"
          
          # Create the full path for tsnet state directory
          mkdir -p "$TS_STATE_DIR/.config"
          
          exec ${serviceConfig.package}/bin/tsnet-proxy \
            -hostname "${serviceConfig.hostname}" \
            -backend "${backendUrl}" \
            -port "${serviceConfig.listenPort}"
        '';
      };
    }) cfg.services;

    # Create user for tsnet-proxy services
    users.users.tsnet-proxy = {
      description = "tsnet-proxy service user";
      isSystemUser = true;
      group = "tsnet-proxy";
    };

    users.groups.tsnet-proxy = {};

    # Allow tsnet-proxy to create network connections
    networking.firewall = {
      allowedTCPPorts = lib.flatten (
        lib.mapAttrsToList (serviceName: serviceConfig:
          if serviceConfig.listenPort == "80" then [ 80 ]
          else if serviceConfig.listenPort == "443" then [ 443 ]
          else [ (lib.toInt serviceConfig.listenPort) ]
        ) cfg.services
      );
    };
  };
}