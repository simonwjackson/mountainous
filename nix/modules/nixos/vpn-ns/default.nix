{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types mapAttrs' nameValuePair filterAttrs attrValues;
  cfg = config.mountainous.vpn-ns;

  # Service submodule options
  serviceOpts = {name, ...}: {
    options = {
      enable = mkEnableOption "Include ${name} in VPN namespace";

      unit = mkOption {
        type = types.str;
        default = "${name}.service";
        description = "Systemd unit name to run in VPN namespace";
      };

      port = mkOption {
        type = types.port;
        description = "Port the service listens on (for tailscale proxy)";
      };

      tailscale = {
        enable = mkEnableOption "Expose service via Tailscale";

        hostname = mkOption {
          type = types.str;
          default = name;
          description = "Tailscale hostname for this service";
        };

        protocol = mkOption {
          type = types.enum ["http" "https"];
          default = "http";
          description = "Backend protocol (WebSockets work over both)";
        };
      };

      preStart = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Additional ExecStartPre script for this service";
      };

      hostWhitelist = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Hostnames to add to service's whitelist (service-specific)";
      };
    };
  };

  # Get enabled services
  enabledServices = filterAttrs (_: svc: svc.enable) cfg.services;
  enabledServiceNames = map (svc: svc.unit) (attrValues enabledServices);
in {
  options.mountainous.vpn-ns = {
    enable = mkEnableOption "VPN network namespace for isolating services";

    configFile = mkOption {
      type = types.path;
      description = "Path to WireGuard configuration file";
      example = "config.age.secrets.\"fastest-vpn\".path";
    };

    localNetworks = mkOption {
      type = types.listOf types.str;
      default = ["192.168.0.0/16"];
      description = "CIDRs that should route through host (not VPN)";
    };

    tailscaleDomain = mkOption {
      type = types.str;
      example = "hummingbird-lake.ts.net";
      description = "Your Tailscale domain for all services";
    };

    vethAddress = mkOption {
      type = types.str;
      default = "10.200.200.2";
      description = "IP address of the veth interface inside the namespace";
      readOnly = true;
    };

    services = mkOption {
      type = types.attrsOf (types.submodule serviceOpts);
      default = {};
      description = "Services to run inside the VPN namespace";
    };
  };

  config = mkIf cfg.enable {
    # Systemd services configuration
    systemd.services =
      {
        # VPN namespace service
        vpn-ns = {
          description = "VPN Network Namespace";
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"] ++ enabledServiceNames;
          after = ["network-online.target"];
          before = enabledServiceNames;
          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.vpn-ns}/bin/vpn-ns --setup";
            ExecStop = "${pkgs.vpn-ns}/bin/vpn-ns --cleanup";
            # Restart on failure (tunnel dies, DNS issues, etc.)
            Restart = "always";
            RestartSec = "10s";
          };
          environment = {
            VPN_NS_CONFIG = cfg.configFile;
            VPN_NS_LOCAL_NETS = lib.concatStringsSep " " cfg.localNetworks;
          };
        };
      }
      // mapAttrs' (name: svc:
        nameValuePair (lib.removeSuffix ".service" svc.unit) (mkMerge [
          {
            after = ["vpn-ns.service"];
            bindsTo = ["vpn-ns.service"];
            partOf = ["vpn-ns.service"];
            serviceConfig = {
              NetworkNamespacePath = "/run/netns/vpn";
              BindReadOnlyPaths = ["/etc/netns/vpn/resolv.conf:/etc/resolv.conf"];
            };
          }
          (mkIf (svc.preStart != null) {
            serviceConfig.ExecStartPre = [svc.preStart];
          })
        ]))
      enabledServices;

    # Tailscale proxy integration for enabled services
    mountainous.tsnet-proxy.services = mapAttrs' (
      name: svc:
        nameValuePair name {
          hostname = svc.tailscale.hostname;
          port = svc.port;
          protocol = svc.tailscale.protocol;
          host = cfg.vethAddress;
        }
    ) (filterAttrs (_: svc: svc.tailscale.enable) enabledServices);
  };
}
