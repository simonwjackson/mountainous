{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.vpn-proxy;
in
{
  options.services.vpn-proxy = {
    enable = mkEnableOption "VPN Proxy";

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
