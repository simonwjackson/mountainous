{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.vpn-ns;
in
{
  options.mountainous.vpn-ns = {
    enable = mkEnableOption "VPN network namespace for isolating services";

    configFile = mkOption {
      type = types.path;
      description = "Path to WireGuard configuration file";
      example = "config.age.secrets.\"fastest-vpn\".path";
    };

    localNetworks = mkOption {
      type = types.listOf types.str;
      default = [ "192.168.0.0/16" ];
      description = "CIDRs that should route through host (not VPN)";
    };

    # Internal option for dependent services to register
    dependentServices = mkOption {
      type = types.listOf types.str;
      default = [];
      internal = true;
      description = "Services that depend on the VPN namespace";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.vpn-ns = {
      description = "VPN Network Namespace";
      wantedBy = [ "multi-user.target" ];
      wants = cfg.dependentServices;
      before = cfg.dependentServices;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.vpn-ns}/bin/vpn-ns --setup";
        ExecStop = "${pkgs.vpn-ns}/bin/vpn-ns --cleanup";
      };
      environment = {
        VPN_NS_CONFIG = cfg.configFile;
        VPN_NS_LOCAL_NETS = lib.concatStringsSep " " cfg.localNetworks;
      };
    };
  };
}
