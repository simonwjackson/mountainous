{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.sabnzbd;

  # Computed whitelist string
  whitelistStr = lib.concatStringsSep "," cfg.hostWhitelist;

  # Script to update host_whitelist in sabnzbd.ini
  updateWhitelist = pkgs.writeShellScript "sabnzbd-update-whitelist" ''
    INI_FILE="/var/lib/sabnzbd/sabnzbd.ini"
    if [ -f "$INI_FILE" ] && [ -n "${whitelistStr}" ]; then
      if ${pkgs.gnugrep}/bin/grep -q "^host_whitelist" "$INI_FILE"; then
        ${pkgs.gnused}/bin/sed -i "s/^host_whitelist.*/host_whitelist = ${whitelistStr}/" "$INI_FILE"
      else
        ${pkgs.gnused}/bin/sed -i "/^\[misc\]/a host_whitelist = ${whitelistStr}" "$INI_FILE"
      fi
    fi
  '';
in {
  options.mountainous.sabnzbd = {
    enable = mkEnableOption "SABnzbd Usenet downloader";

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

    hostWhitelist = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Hostnames to whitelist for SABnzbd access";
      example = ["usenet.hummingbird-lake.ts.net"];
    };
  };

  config = mkIf cfg.enable {
    services.sabnzbd = {
      enable = true;
      openFirewall = cfg.openFirewall;
    };

    systemd.services.sabnzbd = {
      serviceConfig = {
        ExecStart =
          lib.mkForce
          "${pkgs.sabnzbd}/bin/sabnzbd -d -s 0.0.0.0:${toString cfg.port} -f /var/lib/sabnzbd/sabnzbd.ini";
        ExecStartPre = lib.mkIf (cfg.hostWhitelist != []) [updateWhitelist];
      };
    };
  };
}
