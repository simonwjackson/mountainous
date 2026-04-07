{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkAfter mkIf optional;

  cfg = config.mountainous.features.transmission;
  mediaCfg = config.mountainous.features.media;
  stateDir = "/var/lib/transmission";
in {
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = mediaCfg.enable;
        message = "mountainous.features.transmission requires mountainous.features.media.enable = true";
      }
      {
        assertion = config.mountainous.features.vpn-ns.enable;
        message = "mountainous.features.transmission requires mountainous.features.vpn-ns.enable = true";
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
          "umask" = "002";
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

    mountainous.features.vpn-ns.services.transmission = {
      enable = true;
      unit = "transmission.service";
      port = cfg.port;
      tailscale = {
        enable = true;
        hostname = "torrents";
        protocol = "http";
      };
    };

    mountainous.features.tsnet-proxy.services.transmission.openFirewall = false;

    networking.firewall.allowedTCPPorts = optional cfg.openFirewall cfg.port;
  };
}
