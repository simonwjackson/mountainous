{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.jellyfin;
  mediaCfg = config.mountainous.features.media;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.jellyfin = {
    enable = mkEnableOption "Jellyfin with Mountainous defaults";

    user = mkOption {
      type = types.str;
      default = "jellyfin";
      description = "User account under which Jellyfin runs.";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Primary group for Jellyfin; usually the shared media group.";
    };

    port = mkOption {
      type = types.port;
      default = 8096;
      description = "Jellyfin web UI and API port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Jellyfin port in the firewall.";
    };

    moviesLibraryDir = mkOption {
      type = types.str;
      default = mediaCfg.moviesDir;
      description = "Shared movies library path Jellyfin should expose.";
    };

    tvLibraryDir = mkOption {
      type = types.str;
      default = mediaCfg.tvDir;
      description = "Shared TV library path Jellyfin should expose.";
    };

    bootstrap = {
      enable = mkEnableOption "seed Jellyfin first-run state declaratively";

      admin = {
        username = mkOption {
          type = types.str;
          default = "admin";
          description = "Initial Jellyfin admin username to create during bootstrap.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to a secret file containing the initial Jellyfin admin password.";
        };
      };

      serverName = mkOption {
        type = types.str;
        default = config.networking.hostName;
        description = "Server name to set through Jellyfin's startup wizard API.";
      };

      remoteAccess = mkOption {
        type = types.bool;
        default = false;
        description = "Whether Jellyfin remote access should be enabled during bootstrap.";
      };

      libraries = {
        tv = {
          name = mkOption {
            type = types.str;
            default = "TV";
            description = "Display name for the initial Jellyfin TV library.";
          };

          path = mkOption {
            type = types.str;
            default = cfg.tvLibraryDir;
            description = "Filesystem path for the initial Jellyfin TV library.";
          };
        };

        movies = {
          name = mkOption {
            type = types.str;
            default = "Movies";
            description = "Display name for the initial Jellyfin movies library.";
          };

          path = mkOption {
            type = types.str;
            default = cfg.moviesLibraryDir;
            description = "Filesystem path for the initial Jellyfin movies library.";
          };
        };
      };
    };

    proxy = {
      enable = mkEnableOption "expose Jellyfin through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "jellyfin";
        description = "Tailscale hostname for Jellyfin.";
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

    watchedCleaner = {
      enable = mkEnableOption "automatic deletion of media watched beyond a configurable age";

      maxAgeDays = mkOption {
        type = types.int;
        default = 7;
        description = "Number of days after an item was last played before it becomes eligible for automatic deletion.";
      };

      interval = mkOption {
        type = types.str;
        default = "daily";
        description = "Systemd calendar expression controlling how often the cleaner runs.";
      };

      mediaTypes = mkOption {
        type = types.listOf (types.enum ["Movie" "Episode"]);
        default = ["Movie" "Episode"];
        description = "Jellyfin media types eligible for automatic cleanup.";
      };
    };
  };
}
