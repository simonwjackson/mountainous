{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) attrValues concatStringsSep filterAttrs mapAttrs' mkEnableOption mkIf mkMerge mkOption nameValuePair optionalAttrs removeSuffix types;

  cfg = config.mountainous.vpn-ns;

  serviceType = types.submodule ({name, ...}: {
    options = {
      enable = mkEnableOption "run ${name} inside the VPN namespace";

      unit = mkOption {
        type = types.str;
        default = "${name}.service";
        description = "Systemd unit name to run inside the VPN namespace.";
      };

      port = mkOption {
        type = types.port;
        description = "Port the service listens on inside the VPN namespace.";
      };

      tailscale = {
        enable = mkEnableOption "expose the service through tsnet-proxy";

        hostname = mkOption {
          type = types.str;
          default = name;
          description = "Tailscale hostname for this proxied service.";
        };

        protocol = mkOption {
          type = types.enum ["http" "https"];
          default = "http";
          description = "Backend protocol used by tsnet-proxy.";
        };
      };
    };
  });

  enabledServices = filterAttrs (_: service: service.enable) cfg.services;
  enabledUnits = map (service: service.unit) (attrValues enabledServices);
  tailscaleServices = filterAttrs (_: service: service.tailscale.enable) enabledServices;
in {
  options.mountainous.vpn-ns = {
    enable = mkEnableOption "VPN namespace for leak-resistant service isolation";

    configFile = mkOption {
      type = types.path;
      description = "Path to the WireGuard configuration file used by vpn-ns.";
      example = "config.age.secrets.\"fastest-vpn\".path";
    };

    localNetworks = mkOption {
      type = types.listOf types.str;
      default = ["192.168.0.0/16"];
      description = "CIDRs that should bypass the tunnel via the host veth route.";
    };

    vethAddress = mkOption {
      type = types.str;
      default = "10.200.200.2";
      readOnly = true;
      description = "Address of the namespace-side veth interface.";
    };

    services = mkOption {
      type = types.attrsOf serviceType;
      default = {};
      description = "Services that must run inside the VPN namespace.";
    };
  };

  config = mkIf cfg.enable {
    # Trust the host-side veth so VPN-namespaced services can reach host services
    networking.firewall.trustedInterfaces = [ "veth-vpn-host" ];

    systemd.services = mkMerge [
      {
        vpn-ns = {
          description = "VPN Network Namespace";
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"] ++ enabledUnits;
          after = ["network-online.target"];
          before = enabledUnits;
          serviceConfig = {
            Type = "notify";
            NotifyAccess = "all";
            ExecStart = "${pkgs.vpn-ns}/bin/vpn-ns --setup";
            ExecStop = "${pkgs.vpn-ns}/bin/vpn-ns --cleanup";
            Restart = "always";
            RestartSec = "10s";
          };
          environment = {
            VPN_NS_CONFIG = cfg.configFile;
            VPN_NS_LOCAL_NETS = concatStringsSep " " cfg.localNetworks;
          };
        };
      }
      (mapAttrs' (
          _: service:
            nameValuePair (removeSuffix ".service" service.unit) {
              after = ["vpn-ns.service"];
              bindsTo = ["vpn-ns.service"];
              partOf = ["vpn-ns.service"];
              serviceConfig = {
                NetworkNamespacePath = "/run/netns/vpn";
                BindReadOnlyPaths = ["/etc/netns/vpn/resolv.conf:/etc/resolv.conf"];
              };
            }
        )
        enabledServices)
      (optionalAttrs (config.mountainous.services.tsnet-proxy.enable or false) (
        mapAttrs' (
          name: _:
            nameValuePair "tsnet-proxy-${name}" {
              after = ["vpn-ns.service"];
              requires = ["vpn-ns.service"];
              partOf = ["vpn-ns.service"];
            }
        )
        tailscaleServices
      ))
    ];

    mountainous.services.tsnet-proxy.services =
      mapAttrs' (
        name: service:
          nameValuePair name {
            hostname = service.tailscale.hostname;
            protocol = service.tailscale.protocol;
            host = cfg.vethAddress;
            port = service.port;
          }
      )
      tailscaleServices;
  };
}
