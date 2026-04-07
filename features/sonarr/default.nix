{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.sonarr;
  mediaCfg = config.mountainous.features.media;
  vpnNsAddress = config.mountainous.features.vpn-ns.vethAddress;
  nzbgetInVpn = (config.mountainous.features.vpn-ns.services.nzbget.enable or false);
  transmissionInVpn = (config.mountainous.features.vpn-ns.services.transmission.enable or false);
  nzbgetHost = if !cfg.vpn.enable && nzbgetInVpn then vpnNsAddress else "127.0.0.1";
  transmissionHost = if !cfg.vpn.enable && transmissionInVpn then vpnNsAddress else "127.0.0.1";
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.sonarr = {
    enable = mkEnableOption "Sonarr with Mountainous defaults";

    user = mkOption {
      type = types.str;
      default = "sonarr";
      description = "User account under which Sonarr runs.";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Primary group for Sonarr; usually the shared media group.";
    };

    port = mkOption {
      type = types.port;
      default = 8989;
      description = "Sonarr web UI and API port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Sonarr port in the firewall.";
    };

    auth = {
      enable = mkEnableOption "Sonarr web authentication";

      username = mkOption {
        type = types.str;
        default = "simonwjackson";
        description = "Username for Sonarr web authentication.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a secret file containing the Sonarr password.";
      };

      required = mkOption {
        type = types.enum ["Enabled" "DisabledForLocalAddresses"];
        default = "Enabled";
        description = "How broadly Sonarr auth is enforced.";
      };
    };

    vpn.enable = mkEnableOption "run Sonarr inside the VPN namespace";

    proxy = {
      enable = mkEnableOption "expose Sonarr through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "tv";
        description = "Tailscale hostname for Sonarr.";
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

    tvLibraryDir = mkOption {
      type = types.str;
      default = mediaCfg.tvDir;
      description = "Shared TV library path Sonarr should manage and import into.";
    };

    usenetCompletedDir = mkOption {
      type = types.str;
      default = mediaCfg.usenetCompletedDir;
      description = "Completed Usenet downloads path Sonarr should import from.";
    };

    torrentsCompletedDir = mkOption {
      type = types.str;
      default = mediaCfg.torrentsCompletedDir;
      description = "Completed torrent downloads path Sonarr should import from.";
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings forwarded to services.sonarr.settings.";
      example = {
        server = {
          bindaddress = "*";
          port = 8989;
        };
      };
    };

    downloadClients = {
      nzbget = {
        enable = mkEnableOption "seed NZBGet as a Sonarr download client";

        name = mkOption {
          type = types.str;
          default = "NZBGet";
          description = "Display name for the Sonarr NZBGet download client.";
        };

        priority = mkOption {
          type = types.int;
          default = 10;
          description = "Sonarr priority for this NZBGet client. Lower numbers sort earlier in the UI and are useful when multiple usenet clients exist.";
        };

        host = mkOption {
          type = types.str;
          default = nzbgetHost;
          description = "Host Sonarr should use to reach NZBGet.";
        };

        port = mkOption {
          type = types.port;
          default = config.mountainous.features.nzbget.port;
          description = "Port Sonarr should use to reach NZBGet.";
        };

        useSsl = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Sonarr should use TLS for NZBGet.";
        };

        urlBase = mkOption {
          type = types.str;
          default = "";
          description = "Optional NZBGet URL base.";
        };

        username = mkOption {
          type = types.str;
          default = config.mountainous.features.nzbget.controlUsername;
          description = "Username Sonarr should use for NZBGet.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Optional secret file containing the NZBGet password for Sonarr.";
        };

        category = mkOption {
          type = types.str;
          default = "Series";
          description = "NZBGet category Sonarr should assign to TV downloads.";
        };

        recentTvPriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Sonarr should send to NZBGet for recent episodes.";
        };

        olderTvPriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Sonarr should send to NZBGet for older episodes.";
        };

        addPaused = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Sonarr should add NZBGet jobs paused.";
        };
      };

      transmission = {
        enable = mkEnableOption "seed Transmission as a Sonarr download client";

        name = mkOption {
          type = types.str;
          default = "Transmission";
          description = "Display name for the Sonarr Transmission download client.";
        };

        priority = mkOption {
          type = types.int;
          default = 20;
          description = "Sonarr priority for this Transmission client. Lower numbers sort earlier in the UI and are useful when multiple torrent clients exist.";
        };

        host = mkOption {
          type = types.str;
          default = transmissionHost;
          description = "Host Sonarr should use to reach Transmission.";
        };

        port = mkOption {
          type = types.port;
          default = config.mountainous.features.transmission.port;
          description = "Port Sonarr should use to reach Transmission.";
        };

        useSsl = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Sonarr should use TLS for Transmission.";
        };

        urlBase = mkOption {
          type = types.str;
          default = "/transmission/";
          description = "Transmission RPC URL base Sonarr should use.";
        };

        username = mkOption {
          type = types.str;
          default = "";
          description = "Username Sonarr should use for Transmission.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Optional secret file containing the Transmission password for Sonarr.";
        };

        category = mkOption {
          type = types.str;
          default = "tv-sonarr";
          description = "Transmission category Sonarr should assign to TV torrents.";
        };

        importedCategory = mkOption {
          type = types.str;
          default = "";
          description = "Optional post-import Transmission category Sonarr should set.";
        };

        directory = mkOption {
          type = types.str;
          default = "";
          description = "Optional per-client download directory override for Transmission.";
        };

        recentTvPriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Sonarr should send to Transmission for recent episodes.";
        };

        olderTvPriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Sonarr should send to Transmission for older episodes.";
        };

        addPaused = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Sonarr should add Transmission torrents paused.";
        };
      };
    };

    notifications = {
      webhookRelay = {
        enable = mkEnableOption "send Sonarr events to the Matrix webhook relay";

        url = mkOption {
          type = types.str;
          default = "http://10.200.200.1:9100/hook/sonarr";
          description = ''
            Webhook relay URL for Sonarr notifications.
            Default uses the vpn-ns host-side veth address (10.200.200.1)
            since Sonarr typically runs inside the VPN namespace.
          '';
        };

        actionUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "https://tv.example.ts.net";
          description = ''
            Optional URL passed as ?url= query parameter. When set, clicking
            the desktop notification opens this URL (e.g., the Sonarr web UI).
          '';
        };
      };

      jellyfin = {
        enable = mkEnableOption "notify a Jellyfin server when Sonarr imports media";

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
