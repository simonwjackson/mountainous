{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.vpn-proxy;
in
{
  options.services.vpn-proxy = {
    enable = mkEnableOption "VPN Proxy";

    # steamcmdPackage = mkOption {
    #   type = types.package;
    #   default = pkgs.steamcmd;
    #   defaultText = "pkgs.steamcmd";
    #   description = ''
    #     The package implementing SteamCMD
    #   '';
    # };

    # dataDir = mkOption {
    #   type = types.path;
    #   description = "Directory to store game server";
    #   default = "/var/lib/satisfactory";
    # };

    host = mkOption {
      type = types.str;
      description = "Remote host";
      default = "";
    };

    localUser = mkOption {
      type = types.str;
      description = "Local user";
      default = "";
    };

    remoteUser = mkOption {
      type = types.str;
      description = "Remote user";
      default = "${cfg.localUser}";
    };

    localPort = mkOption {
      type = types.int;
      description = "Local port";
    };

    # openFirewall = mkOption {
    #   type = types.bool;
    #   default = false;
    #   description = ''
    #     Whether to open ports in the firewall for the server
    #   '';
    # };
  };

  config = mkIf cfg.enable {
    systemd.services.vpn-proxy =
      let
        autossh = "${pkgs.autossh}/bin/autossh";
      in
      {
        description = "VPN Proxy";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          User = "${cfg.localUser}";
          Environment = "AUTOSSH_GATETIME=0";
          ExecStart = "${autossh} -M 0 -N -o 'ServerAliveInterval 30' -o 'ServerAliveCountMax 3' -D ${builtins.toString cfg.localPort} ${cfg.remoteUser}@${cfg.host}";
        };
      };

    networking.extraHosts = ''
      ${cfg.host} www.local.hilton.com
    '';

    programs.proxychains = {
      enable = true;
      quietMode = true;
      proxies = {
        ushiro = {
          enable = true;
          type = "socks5";
          host = "127.0.0.1";
          port = cfg.localPort;
        };
      };
    };
  };
}
