{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.radarr;
  mediaCfg = config.mountainous.features.media;
  vpnNsAddress = config.mountainous.features.vpn-ns.vethAddress;
  nzbgetInVpn = config.mountainous.features.vpn-ns.services.nzbget.enable or false;
  transmissionInVpn = config.mountainous.features.vpn-ns.services.transmission.enable or false;
  nzbgetHost =
    if !cfg.vpn.enable && nzbgetInVpn
    then vpnNsAddress
    else "127.0.0.1";
  transmissionHost =
    if !cfg.vpn.enable && transmissionInVpn
    then vpnNsAddress
    else "127.0.0.1";
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.radarr = {
    enable = mkEnableOption "Radarr with Mountainous defaults";

    user = mkOption {
      type = types.str;
      default = "radarr";
      description = "User account under which Radarr runs.";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Primary group for Radarr; usually the shared media group.";
    };

    port = mkOption {
      type = types.port;
      default = 7878;
      description = "Radarr web UI and API port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Radarr port in the firewall.";
    };

    auth = {
      enable = mkEnableOption "Radarr web authentication";

      username = mkOption {
        type = types.str;
        default = "simonwjackson";
        description = "Username for Radarr web authentication.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a secret file containing the Radarr password.";
      };

      required = mkOption {
        type = types.enum ["Enabled" "DisabledForLocalAddresses"];
        default = "Enabled";
        description = "How broadly Radarr auth is enforced.";
      };
    };

    vpn.enable = mkEnableOption "run Radarr inside the VPN namespace";

    proxy = {
      enable = mkEnableOption "expose Radarr through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "movies";
        description = "Tailscale hostname for Radarr.";
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

    moviesLibraryDir = mkOption {
      type = types.str;
      default = mediaCfg.moviesDir;
      description = "Shared movies library path Radarr should manage and import into.";
    };

    usenetCompletedDir = mkOption {
      type = types.str;
      default = mediaCfg.usenetCompletedDir;
      description = "Completed Usenet downloads path Radarr should import from.";
    };

    torrentsCompletedDir = mkOption {
      type = types.str;
      default = mediaCfg.torrentsCompletedDir;
      description = "Completed torrent downloads path Radarr should import from.";
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings forwarded to services.radarr.settings.";
      example = {
        server = {
          bindaddress = "*";
          port = 7878;
        };
      };
    };

    downloadClients = {
      nzbget = {
        enable = mkEnableOption "seed NZBGet as a Radarr download client";

        name = mkOption {
          type = types.str;
          default = "NZBGet";
          description = "Display name for the Radarr NZBGet download client.";
        };

        priority = mkOption {
          type = types.int;
          default = 10;
          description = "Radarr priority for this NZBGet client. Lower numbers sort earlier in the UI and are useful when multiple usenet clients exist.";
        };

        host = mkOption {
          type = types.str;
          default = nzbgetHost;
          description = "Host Radarr should use to reach NZBGet.";
        };

        port = mkOption {
          type = types.port;
          default = config.mountainous.features.nzbget.port;
          description = "Port Radarr should use to reach NZBGet.";
        };

        useSsl = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Radarr should use TLS for NZBGet.";
        };

        urlBase = mkOption {
          type = types.str;
          default = "";
          description = "Optional NZBGet URL base.";
        };

        username = mkOption {
          type = types.str;
          default = config.mountainous.features.nzbget.controlUsername;
          description = "Username Radarr should use for NZBGet.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Optional secret file containing the NZBGet password for Radarr.";
        };

        category = mkOption {
          type = types.str;
          default = "Movies";
          description = "NZBGet category Radarr should assign to movie downloads.";
        };

        recentMoviePriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Radarr should send to NZBGet for recent movies.";
        };

        olderMoviePriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Radarr should send to NZBGet for older movies.";
        };

        addPaused = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Radarr should add NZBGet jobs paused.";
        };
      };

      transmission = {
        enable = mkEnableOption "seed Transmission as a Radarr download client";

        name = mkOption {
          type = types.str;
          default = "Transmission";
          description = "Display name for the Radarr Transmission download client.";
        };

        priority = mkOption {
          type = types.int;
          default = 20;
          description = "Radarr priority for this Transmission client. Lower numbers sort earlier in the UI and are useful when multiple torrent clients exist.";
        };

        host = mkOption {
          type = types.str;
          default = transmissionHost;
          description = "Host Radarr should use to reach Transmission.";
        };

        port = mkOption {
          type = types.port;
          default = config.mountainous.features.transmission.port;
          description = "Port Radarr should use to reach Transmission.";
        };

        useSsl = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Radarr should use TLS for Transmission.";
        };

        urlBase = mkOption {
          type = types.str;
          default = "/transmission/";
          description = "Transmission RPC URL base Radarr should use.";
        };

        username = mkOption {
          type = types.str;
          default = "";
          description = "Username Radarr should use for Transmission.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Optional secret file containing the Transmission password for Radarr.";
        };

        category = mkOption {
          type = types.str;
          default = "movies-radarr";
          description = "Transmission category Radarr should assign to movie torrents.";
        };

        importedCategory = mkOption {
          type = types.str;
          default = "";
          description = "Optional post-import Transmission category Radarr should set.";
        };

        directory = mkOption {
          type = types.str;
          default = "";
          description = "Optional per-client download directory override for Transmission.";
        };

        recentMoviePriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Radarr should send to Transmission for recent movies.";
        };

        olderMoviePriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Radarr should send to Transmission for older movies.";
        };

        addPaused = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Radarr should add Transmission torrents paused.";
        };
      };
    };

    notifications = {
      webhookRelay = {
        enable = mkEnableOption "send Radarr events to the Matrix webhook relay";

        url = mkOption {
          type = types.str;
          default = "http://10.200.200.1:9100/hook/radarr";
          description = ''
            Webhook relay URL for Radarr notifications.
            Default uses the vpn-ns host-side veth address (10.200.200.1)
            since Radarr may run inside the VPN namespace.
          '';
        };

        actionUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "https://movies.example.ts.net";
          description = ''
            Optional URL passed as ?url= query parameter. When set, clicking
            the desktop notification opens this URL (e.g., the Radarr web UI).
          '';
        };
      };

      jellyfin = {
        enable = mkEnableOption "notify a Jellyfin server when Radarr imports media";

        host = mkOption {
          type = types.str;
          description = "Jellyfin server hostname or IP.";
          example = "zao";
        };

        port = mkOption {
          type = types.port;
          default = 8096;
          description = "Jellyfin server port.";
        };

        useSsl = mkOption {
          type = types.bool;
          default = false;
          description = "Whether the Jellyfin server uses HTTPS.";
        };

        username = mkOption {
          type = types.str;
          default = "simonwjackson";
          description = "Jellyfin username used to authenticate notification requests.";
        };

        passwordFile = mkOption {
          type = types.path;
          description = "Path to a file containing the Jellyfin password for the notification user.";
        };
      };
    };
  };
}
