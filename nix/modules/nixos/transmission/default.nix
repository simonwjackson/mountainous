{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types;
  cfg = config.mountainous.transmission;
in
{
  options.mountainous.transmission = {
    enable = mkEnableOption "Transmission BitTorrent client";

    vpn = {
      enable = mkEnableOption "Run Transmission inside VPN namespace";

      configFile = mkOption {
        type = types.path;
        description = "Path to WireGuard configuration file for VPN namespace";
        example = "config.age.secrets.\"fastest-vpn\".path";
      };
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings to pass to services.transmission.settings";
      example = {
        download-dir = "/media/downloads";
        speed-limit-up = 100;
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for transmission";
    };

    tailscale = {
      enable = mkEnableOption "Expose transmission via Tailscale (requires mountainous.tsnet-proxy)";

      hostname = mkOption {
        type = types.str;
        default = "transmission";
        description = "Tailscale hostname for transmission";
      };
    };
  };

  config = mkIf cfg.enable {
    # Enable and configure the shared VPN namespace (if VPN enabled)
    mountainous.vpn-ns = mkIf cfg.vpn.enable {
      enable = true;
      configFile = cfg.vpn.configFile;
      dependentServices = [ "transmission.service" ];
    };

    # Transmission service
    services.transmission = {
      enable = true;
      package = pkgs.transmission_4;
      openFirewall = cfg.openFirewall;
      settings = {
        rpc-bind-address = "0.0.0.0";
        rpc-whitelist-enabled = false;
        rpc-host-whitelist-enabled = false;
      } // cfg.settings;
    };

    # Configure transmission systemd service
    systemd.services.transmission = mkIf cfg.vpn.enable {
      after = [ "vpn-ns.service" ];
      bindsTo = [ "vpn-ns.service" ];
      partOf = [ "vpn-ns.service" ];
      serviceConfig = {
        NetworkNamespacePath = "/run/netns/vpn";
        BindReadOnlyPaths = [ "/etc/netns/vpn/resolv.conf:/etc/resolv.conf" ];
      };
    };

    # Tailscale integration
    mountainous.tsnet-proxy.services.transmission = mkIf cfg.tailscale.enable {
      hostname = cfg.tailscale.hostname;
      port = 9091;
      protocol = "http";
      host = if cfg.vpn.enable then "10.200.200.2" else "127.0.0.1";
    };
  };
}
