{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.services.tsnet-proxy;
in {
  options.mountainous.services.tsnet-proxy = {
    enable = mkEnableOption "tsnet-based Tailscale proxy services";

    package = mkOption {
      type = types.package;
      description = "tsnet-proxy package to use";
    };

    authKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Default Tailscale auth key file for all services";
    };

    services = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          hostname = mkOption {
            type = types.str;
            description = "Tailscale hostname for this proxy node";
          };

          protocol = mkOption {
            type = types.enum ["http" "https"];
            default = "http";
          };

          port = mkOption {
            type = types.int;
            description = "Backend port";
          };

          host = mkOption {
            type = types.str;
            default = "localhost";
          };

          authKeyFile = mkOption {
            type = types.nullOr types.path;
            default = null;
          };

          listenPort = mkOption {
            type = types.str;
            default = "443";
          };

          openFirewall = mkOption {
            type = types.bool;
            default = false;
            description = "Open the host firewall for this proxy listener.";
          };
        };
      });
      default = {};
    };
  };

  config = mkIf cfg.enable {
    systemd.services =
      lib.mapAttrs' (serviceName: serviceConfig: {
        name = "tsnet-proxy-${serviceName}";
        value = {
          description = "tsnet proxy service for ${serviceName}";
          after = ["network.target" "local-fs.target"];
          requires = ["local-fs.target"];
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            Type = "simple";
            User = "tsnet-proxy";
            Group = "tsnet-proxy";
            Restart = "always";
            RestartSec = "10";
            StateDirectory = "tsnet-proxy-${serviceName}";
            StateDirectoryMode = "0700";
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
            RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
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
            effectiveAuthKeyFile =
              if serviceConfig.authKeyFile != null
              then serviceConfig.authKeyFile
              else cfg.authKeyFile;
            backendUrl = "${serviceConfig.protocol}://${serviceConfig.host}:${toString serviceConfig.port}";
          in ''
            export TS_AUTHKEY="$(cat ${effectiveAuthKeyFile} | tr -d '\n')"
            mkdir -p "$TS_STATE_DIR/.config"
            exec ${cfg.package}/bin/tsnet-proxy \
              -hostname "${serviceConfig.hostname}" \
              -backend "${backendUrl}" \
              -port "${serviceConfig.listenPort}"
          '';
        };
      })
      cfg.services;

    users.users.tsnet-proxy = {
      description = "tsnet-proxy service user";
      isSystemUser = true;
      group = "tsnet-proxy";
    };

    users.groups.tsnet-proxy = {};

    networking.firewall.allowedTCPPorts = lib.flatten (
      lib.mapAttrsToList (
        _: serviceConfig:
          if !serviceConfig.openFirewall
          then []
          else if serviceConfig.listenPort == "80"
          then [80]
          else if serviceConfig.listenPort == "443"
          then [443]
          else [(lib.toInt serviceConfig.listenPort)]
      )
      cfg.services
    );
  };
}
