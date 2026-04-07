{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.jellyswarrm;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.jellyswarrm = {
    enable = mkEnableOption "Jellyswarrm reverse proxy for merging multiple Jellyfin servers";

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for the Jellyswarrm web UI and proxy.";
    };

    username = mkOption {
      type = types.str;
      default = "admin";
      description = "Admin username for the Jellyswarrm management UI.";
    };

    passwordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a secret file containing the Jellyswarrm admin password.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Jellyswarrm port in the firewall.";
    };

    serverName = mkOption {
      type = types.str;
      default = "Jellyswarrm Proxy";
      description = "Display name shown to Jellyfin clients.";
    };

    servers = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Display name for this Jellyfin server.";
          };

          url = mkOption {
            type = types.str;
            description = "URL of the Jellyfin server (e.g. http://zao:8096).";
          };

          priority = mkOption {
            type = types.int;
            description = "Priority for this server. Lower number = higher priority. Used for deduplication.";
          };

          streamingMode = mkOption {
            type = types.enum ["Proxy" "Redirect"];
            default = "Proxy";
            description = "Whether to proxy media through Jellyswarrm or redirect clients directly.";
          };
        };
      });
      default = [];
      description = "Jellyfin servers to preconfigure. Seeded into the database on first start.";
    };

    bootstrap = {
      enable = mkEnableOption "seed a Jellyswarrm user by performing an initial login after all backends are healthy";

      username = mkOption {
        type = types.str;
        default = "simonwjackson";
        description = "Username to log into Jellyswarrm with during bootstrap.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Secret file containing the bootstrap user's password.";
      };
    };

    proxy = {
      enable = mkEnableOption "expose Jellyswarrm through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "watch";
        description = "Tailscale hostname for Jellyswarrm.";
      };

      protocol = mkOption {
        type = types.enum ["http" "https"];
        default = "http";
        description = "Backend protocol used by tsnet-proxy.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the host firewall for the tsnet-proxy listener.";
      };
    };
  };
}
