{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (lib) literalExpression mkEnableOption mkOption types;
  cfg = config.mountainous.features.pyxis;
in {
  imports = [
    inputs.pyxis.nixosModules.default
    ./nixos.nix
  ];

  options.mountainous.features.pyxis = {
    enable = mkEnableOption "Pyxis music streaming server";

    package = mkOption {
      type = types.package;
      default = inputs.pyxis.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = literalExpression "inputs.pyxis.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "Pyxis package to use.";
    };

    port = mkOption {
      type = types.port;
      default = 8765;
      description = "Port used by the Pyxis HTTP server.";
    };

    hostname = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Hostname Pyxis should advertise for local URLs and non-proxied access.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the host firewall for the Pyxis service port.";
    };

    allowedHosts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional allowed web hosts for Pyxis.";
    };

    logLevel = mkOption {
      type = types.enum ["trace" "debug" "info" "warn" "error" "fatal"];
      default = "info";
      description = "Pyxis log level.";
    };

    sources = {
      pandora = {
        username = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Pandora username for Pyxis.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Secret file containing the Pandora password.";
        };
      };

      discogs = {
        tokenFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Secret file containing the Discogs API token.";
        };
      };
    };

    sonos = {
      enable = mkEnableOption "Sonos playback output";

      lanStreamBaseUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "LAN HTTP base URL Sonos speakers use to fetch Pyxis streams.";
        example = "http://192.168.1.243:8765";
      };

      seedHosts = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Known Sonos hosts used when SSDP discovery is unavailable.";
        example = ["192.168.1.118"];
      };

      discoveryIntervalSeconds = mkOption {
        type = types.ints.positive;
        default = 30;
        description = "Seconds to cache Sonos topology discovery.";
      };

      pollIntervalMs = mkOption {
        type = types.ints.positive;
        default = 1000;
        description = "Sonos transport polling interval in milliseconds.";
      };

      requestTimeoutMs = mkOption {
        type = types.ints.positive;
        default = 3000;
        description = "Timeout for Sonos HTTP and SOAP requests.";
      };
    };

    proxy = {
      enable = mkEnableOption "expose Pyxis through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "pyxis";
        description = "Tailscale hostname for the Pyxis proxy.";
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

    backup = {
      enable = mkEnableOption "borg backup of Pyxis state";

      passphraseFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the borg repo passphrase.";
      };

      repoPath = mkOption {
        type = types.str;
        default = "/var/lib/borg/pyxis";
        description = "Local borg repository path for Pyxis backups.";
      };

      startAt = mkOption {
        type = types.str;
        default = "daily";
        description = "Systemd calendar expression for the Pyxis backup schedule.";
      };
    };
  };
}
