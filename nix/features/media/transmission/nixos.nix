{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types;
  cfg = config.mountainous.media.transmission;
  mediaCfg = config.mountainous.media;
in {
  options.mountainous.media.transmission = {
    enable = mkEnableOption "Transmission BitTorrent client";

    user = mkOption {
      type = types.str;
      default = "media";
      description = "User to run Transmission as";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Group to run Transmission as";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/transmission";
      description = "Directory for Transmission data and downloads";
    };

    port = mkOption {
      type = types.port;
      default = 9091;
      description = "Port for Transmission web interface";
    };

    vpn = {
      enable = mkEnableOption "VPN isolation for torrent downloads";
    };

    proxy = {
      enable = mkEnableOption "Tailscale proxy for Transmission web UI";

      name = mkOption {
        type = types.str;
        default = "transmission";
        description = "Tailscale hostname";
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
      default = false;
      description = "Open firewall ports for transmission";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Declaratively create Transmission directories
      mountainous.directories.paths = {
        "${cfg.dataDir}" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
        "${cfg.dataDir}/Downloads" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
        "${cfg.dataDir}/.incomplete" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
      };

      services.transmission = {
        enable = true;
        package = pkgs.transmission_4;
        user = cfg.user;
        group = cfg.group;
        home = cfg.dataDir;
        openFirewall = cfg.openFirewall;
        settings =
          {
            rpc-port = cfg.port;
            rpc-bind-address = "0.0.0.0";
            rpc-whitelist-enabled = false;
            rpc-host-whitelist-enabled = false;
            # Use dataDir for downloads
            download-dir = "${cfg.dataDir}/Downloads";
            incomplete-dir = "${cfg.dataDir}/.incomplete";
            incomplete-dir-enabled = true;
            # Stop seeding immediately when download completes
            ratio-limit = 0;
            ratio-limit-enabled = true;
          }
          // cfg.settings;
      };

      # Wire up VPN and proxy internally
      mountainous.vpn-ns.services.transmission = mkIf cfg.vpn.enable {
        enable = true;
        unit = "transmission.service";
        port = cfg.port;
        tailscale = mkIf cfg.proxy.enable {
          enable = true;
          hostname = cfg.proxy.name;
          protocol = "http";
        };
      };

      # Impermanence integration
      environment.persistence."${config.mountainous.impermanence.persistPath}" =
        mkIf (config.mountainous.impermanence.enable or false)
        {
          directories = [
            {
              inherit (cfg) user group;
              directory = cfg.dataDir;
              mode = "0750";
            }
          ];
        };
    }
  ]);
}
