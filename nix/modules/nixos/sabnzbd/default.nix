{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.sabnzbd;
in
{
  options.mountainous.sabnzbd = {
    enable = mkEnableOption "SABnzbd Usenet downloader";

    vpn = {
      enable = mkEnableOption "Run SABnzbd inside VPN namespace";

      configFile = mkOption {
        type = types.path;
        description = "Path to WireGuard configuration file for VPN namespace";
        example = "config.age.secrets.\"fastest-vpn\".path";
      };
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port for SABnzbd web interface";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for SABnzbd";
    };

    tailscale = {
      enable = mkEnableOption "Expose SABnzbd via Tailscale (requires mountainous.tsnet-proxy)";

      hostname = mkOption {
        type = types.str;
        default = "usenet";
        description = "Tailscale hostname for SABnzbd";
      };

      domain = mkOption {
        type = types.str;
        example = "hummingbird-lake.ts.net";
        description = "Tailscale domain suffix for host whitelist (your tailnet domain)";
      };
    };

    hostWhitelist = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional hostnames to whitelist for SABnzbd access";
    };
  };

  config = mkIf cfg.enable (let
    # Build the full host whitelist
    tailscaleHost = "${cfg.tailscale.hostname}.${cfg.tailscale.domain}";
    fullWhitelist = cfg.hostWhitelist
      ++ lib.optional cfg.tailscale.enable tailscaleHost;
    whitelistStr = lib.concatStringsSep "," fullWhitelist;

    # Script to update host_whitelist in sabnzbd.ini
    updateWhitelist = pkgs.writeShellScript "sabnzbd-update-whitelist" ''
      INI_FILE="/var/lib/sabnzbd/sabnzbd.ini"
      if [ -f "$INI_FILE" ]; then
        # Check if host_whitelist exists and update it, or add it
        if ${pkgs.gnugrep}/bin/grep -q "^host_whitelist" "$INI_FILE"; then
          ${pkgs.gnused}/bin/sed -i "s/^host_whitelist.*/host_whitelist = ${whitelistStr}/" "$INI_FILE"
        else
          # Add under [misc] section
          ${pkgs.gnused}/bin/sed -i "/^\[misc\]/a host_whitelist = ${whitelistStr}" "$INI_FILE"
        fi
      fi
    '';
  in {
    # Enable and configure the shared VPN namespace (if VPN enabled)
    mountainous.vpn-ns = mkIf cfg.vpn.enable {
      enable = true;
      configFile = cfg.vpn.configFile;
      dependentServices = [ "sabnzbd.service" ];
    };

    # SABnzbd service
    services.sabnzbd = {
      enable = true;
      openFirewall = cfg.openFirewall;
    };

    # Configure sabnzbd systemd service
    systemd.services.sabnzbd = lib.mkMerge [
      {
        # Listen on all interfaces
        serviceConfig.ExecStart = lib.mkForce
          "${pkgs.sabnzbd}/bin/sabnzbd -d -s 0.0.0.0:${toString cfg.port} -f /var/lib/sabnzbd/sabnzbd.ini";
      }
      # Update host whitelist if needed
      (mkIf (fullWhitelist != []) {
        serviceConfig.ExecStartPre = [ updateWhitelist ];
      })
      (mkIf cfg.vpn.enable {
        # Run inside the VPN namespace
        after = [ "vpn-ns.service" ];
        bindsTo = [ "vpn-ns.service" ];
        partOf = [ "vpn-ns.service" ];
        serviceConfig = {
          NetworkNamespacePath = "/run/netns/vpn";
          BindReadOnlyPaths = [ "/etc/netns/vpn/resolv.conf:/etc/resolv.conf" ];
        };
      })
    ];

    # Tailscale integration
    mountainous.tsnet-proxy.services.sabnzbd = mkIf cfg.tailscale.enable {
      hostname = cfg.tailscale.hostname;
      port = cfg.port;
      protocol = "http";
      host = if cfg.vpn.enable then "10.200.200.2" else "127.0.0.1";
    };
  });
}
