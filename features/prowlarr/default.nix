{
  config,
  lib,
  ...
}: let
  inherit (lib) attrByPath mkEnableOption mkOption types;
  cfg = config.mountainous.features.prowlarr;
  sonarrPort = attrByPath ["mountainous" "features" "sonarr" "port"] 8989 config;
  sonarrVpnEnabled = attrByPath ["mountainous" "features" "sonarr" "vpn" "enable"] false config;
  radarrPort = attrByPath ["mountainous" "features" "radarr" "port"] 7878 config;
  radarrVpnEnabled = attrByPath ["mountainous" "features" "radarr" "vpn" "enable"] false config;
  vpnHostAddress = "10.200.200.1";
  vpnNsAddress = config.mountainous.features.vpn-ns.vethAddress;
  sonarrHost = if cfg.vpn.enable && !sonarrVpnEnabled then vpnHostAddress else "127.0.0.1";
  radarrHost = if cfg.vpn.enable && !radarrVpnEnabled then vpnHostAddress else "127.0.0.1";
  prowlarrHostForSonarr = if cfg.vpn.enable && !sonarrVpnEnabled then vpnNsAddress else "127.0.0.1";
  prowlarrHostForRadarr = if cfg.vpn.enable && !radarrVpnEnabled then vpnNsAddress else "127.0.0.1";
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.prowlarr = {
    enable = mkEnableOption "Prowlarr with Mountainous defaults";

    port = mkOption {
      type = types.port;
      default = 9696;
      description = "Prowlarr web UI and API port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Prowlarr port in the firewall.";
    };

    auth = {
      enable = mkEnableOption "Prowlarr web authentication";

      username = mkOption {
        type = types.str;
        default = "simonwjackson";
        description = "Username for Prowlarr web authentication.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a secret file containing the Prowlarr password.";
      };

      required = mkOption {
        type = types.enum ["Enabled" "DisabledForLocalAddresses"];
        default = "Enabled";
        description = "How broadly Prowlarr auth is enforced.";
      };
    };

    indexers.nzbgeek = {
      enable = mkEnableOption "seed NZBGeek in Prowlarr";

      name = mkOption {
        type = types.str;
        default = "NZBGeek";
        description = "Display name for the NZBGeek indexer in Prowlarr.";
      };

      apiKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a secret file containing the NZBGeek API key.";
      };

      baseUrl = mkOption {
        type = types.str;
        default = "https://api.nzbgeek.info";
        description = "Base URL for the NZBGeek Newznab endpoint.";
      };

      apiPath = mkOption {
        type = types.str;
        default = "/api";
        description = "API path for the NZBGeek Newznab endpoint.";
      };

      priority = mkOption {
        type = types.int;
        default = 25;
        description = "Priority to assign to the seeded NZBGeek indexer.";
      };
    };

    applications.sonarr = {
      enable = mkEnableOption "seed Sonarr as a managed application in Prowlarr";

      name = mkOption {
        type = types.str;
        default = "Sonarr";
        description = "Display name for the Sonarr application in Prowlarr.";
      };

      prowlarrUrl = mkOption {
        type = types.str;
        default = "http://${prowlarrHostForSonarr}:${toString cfg.port}";
        description = "URL Sonarr should use to reach Prowlarr.";
      };

      baseUrl = mkOption {
        type = types.str;
        default = "http://${sonarrHost}:${toString sonarrPort}";
        description = "URL Prowlarr should use to reach Sonarr.";
      };

      syncLevel = mkOption {
        type = types.str;
        default = "fullSync";
        description = "Sync level passed to the Prowlarr Sonarr application integration.";
      };
    };

    applications.radarr = {
      enable = mkEnableOption "seed Radarr as a managed application in Prowlarr";

      name = mkOption {
        type = types.str;
        default = "Radarr";
        description = "Display name for the Radarr application in Prowlarr.";
      };

      prowlarrUrl = mkOption {
        type = types.str;
        default = "http://${prowlarrHostForRadarr}:${toString cfg.port}";
        description = "URL Radarr should use to reach Prowlarr.";
      };

      baseUrl = mkOption {
        type = types.str;
        default = "http://${radarrHost}:${toString radarrPort}";
        description = "URL Prowlarr should use to reach Radarr.";
      };

      syncLevel = mkOption {
        type = types.str;
        default = "fullSync";
        description = "Sync level passed to the Prowlarr Radarr application integration.";
      };
    };

    vpn.enable = mkEnableOption "run Prowlarr inside the VPN namespace";

    proxy = {
      enable = mkEnableOption "expose Prowlarr through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "prowlarr";
        description = "Tailscale hostname for Prowlarr.";
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

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings forwarded to services.prowlarr.settings.";
      example = {
        server = {
          bindaddress = "*";
          port = 9696;
        };
      };
    };
  };
}
