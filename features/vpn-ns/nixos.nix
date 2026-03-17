{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) attrValues concatStringsSep filterAttrs mapAttrs' mkIf mkMerge nameValuePair optionalAttrs removeSuffix;

  cfg = config.mountainous.features.vpn-ns;

  enabledServices = filterAttrs (_: service: service.enable) cfg.services;
  enabledUnits = map (service: service.unit) (attrValues enabledServices);
  tailscaleServices = filterAttrs (_: service: service.tailscale.enable) enabledServices;
in {
  config = mkIf cfg.enable {
    # Trust the host-side veth so VPN-namespaced services can reach host services
    networking.firewall.trustedInterfaces = ["veth-vpn-host"];

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
      (optionalAttrs (config.mountainous.features.tsnet-proxy.enable or false) (
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

    mountainous.features.tsnet-proxy.services =
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
