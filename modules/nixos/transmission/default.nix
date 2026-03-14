{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkAfter mkEnableOption mkIf mkOption optional types;

  cfg = config.mountainous.transmission;
  mediaCfg = config.mountainous.media;
  stateDir = "/var/lib/transmission";
in {
  options.mountainous.transmission = {
    enable = mkEnableOption "Transmission with Mountainous defaults";

    user = mkOption {
      type = types.str;
      default = "transmission";
      description = "User account under which Transmission runs.";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Primary group for Transmission; usually the shared media group.";
    };

    port = mkOption {
      type = types.port;
      default = 9091;
      description = "Transmission RPC and web UI port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Transmission RPC port in the firewall.";
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings forwarded to services.transmission.settings.";
      example = {
        "download-dir" = "/srv/storage/downloads/torrents/completed";
        "watch-dir-enabled" = true;
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = mediaCfg.enable;
        message = "mountainous.transmission requires mountainous.media.enable = true";
      }
      {
        assertion = config.mountainous.vpn-ns.enable;
        message = "mountainous.transmission requires mountainous.vpn-ns.enable = true";
      }
    ];

    services.transmission = {
      enable = true;
      package = pkgs.transmission_4;
      inherit (cfg) user group;
      home = stateDir;
      settings =
        {
          "download-dir" = mediaCfg.torrentsCompletedDir;
          "incomplete-dir" = mediaCfg.torrentsIncompleteDir;
          "incomplete-dir-enabled" = true;
          "rpc-authentication-required" = false;
          "rpc-bind-address" = "0.0.0.0";
          "rpc-host-whitelist-enabled" = false;
          "rpc-password" = "";
          "rpc-port" = cfg.port;
          "rpc-username" = "";
          "rpc-whitelist-enabled" = false;
          "watch-dir" = mediaCfg.torrentsWatchDir;
          "watch-dir-enabled" = false;
        }
        // cfg.settings;
    };

    users.users.${cfg.user}.extraGroups = optional (cfg.group != mediaCfg.group) mediaCfg.group;

    systemd.services.transmission.serviceConfig.BindPaths = mkAfter [
      mediaCfg.torrentsRoot
      mediaCfg.torrentsCompletedDir
      mediaCfg.torrentsIncompleteDir
      mediaCfg.torrentsWatchDir
    ];

    mountainous.vpn-ns.services.transmission = {
      enable = true;
      unit = "transmission.service";
      port = cfg.port;
      tailscale = {
        enable = true;
        hostname = "torrents";
        protocol = "http";
      };
    };

    mountainous.services.tsnet-proxy.services.transmission.openFirewall = false;

    networking.firewall.allowedTCPPorts = optional cfg.openFirewall cfg.port;
  };
}
