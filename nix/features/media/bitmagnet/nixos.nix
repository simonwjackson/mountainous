{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types literalExpression;
  cfg = config.mountainous.media.bitmagnet;
  mediaCfg = config.mountainous.media;

  # Environment variables for bitmagnet service
  envVars =
    {
      # PostgreSQL via local socket (peer authentication)
      # User/database/service all use same name for simplicity
      POSTGRES_HOST = "/run/postgresql";
      POSTGRES_NAME = cfg.user;
      POSTGRES_USER = cfg.user;
      HTTP_SERVER_LOCAL_ADDRESS = ":${toString cfg.port}";
      DHT_SERVER_PORT = toString cfg.dhtPort;
      DHT_CRAWLER_SCALING_FACTOR = toString cfg.crawler.scalingFactor;
      DHT_CRAWLER_SAVE_FILES_THRESHOLD = toString cfg.crawler.saveFilesThreshold;
      DHT_CRAWLER_RESCRAPE_THRESHOLD = cfg.crawler.rescrapeThreshold;
      LOG_LEVEL = "info";
    }
    // lib.optionalAttrs cfg.tmdb.enable {
      TMDB_ENABLED = "true";
    }
    // cfg.settings;
in {
  options.mountainous.media.bitmagnet = {
    enable = mkEnableOption "Bitmagnet self-hosted BitTorrent indexer and DHT crawler";

    user = mkOption {
      type = types.str;
      default = "media";
      description = "User to run Bitmagnet as";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Group to run Bitmagnet as";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/bitmagnet";
      description = "Directory for Bitmagnet data";
    };

    port = mkOption {
      type = types.port;
      default = 3333;
      description = "Port for Bitmagnet web UI and API";
    };

    dhtPort = mkOption {
      type = types.port;
      default = 3334;
      description = "Port for DHT server (TCP and UDP)";
    };

    vpn = {
      enable = mkEnableOption "VPN isolation for DHT crawling (strongly recommended)";
    };

    proxy = {
      enable = mkEnableOption "Tailscale proxy for Bitmagnet web UI";

      name = mkOption {
        type = types.str;
        default = "bitmagnet";
        description = "Tailscale hostname";
      };
    };

    # Database uses service user name (cfg.user) for both db name and pg user
    # This enables peer authentication without password

    tmdb = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable TMDB metadata integration";
      };

      apiKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing TMDB API key";
      };
    };

    crawler = {
      scalingFactor = mkOption {
        type = types.int;
        default = 10;
        description = "DHT crawler scaling factor (higher = more aggressive crawling)";
      };

      saveFilesThreshold = mkOption {
        type = types.int;
        default = 100;
        description = "Minimum number of files in a torrent to save metadata";
      };

      rescrapeThreshold = mkOption {
        type = types.str;
        default = "720h";
        description = "Minimum time before re-scraping a torrent (e.g., 720h = 30 days)";
      };
    };

    settings = mkOption {
      type = types.attrsOf (types.oneOf [types.bool types.int types.str]);
      default = {};
      description = ''
        Additional environment variables to pass to Bitmagnet.
        See https://bitmagnet.io/setup/configuration.html for available options.
      '';
      example = literalExpression ''
        {
          LOG_LEVEL = "debug";
          DHT_CRAWLER_SAVE_PIECES = "true";
        }
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall ports for DHT server (TCP and UDP)";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Assertions
      assertions = [
        {
          assertion = !cfg.vpn.enable -> cfg.openFirewall;
          message = ''
            Bitmagnet DHT crawler without VPN isolation exposes your IP address to the DHT network.
            Either enable VPN isolation (mountainous.media.bitmagnet.vpn.enable = true)
            or explicitly open firewall ports (mountainous.media.bitmagnet.openFirewall = true)
            to acknowledge this risk.
          '';
        }
      ];

      # Declaratively create Bitmagnet directory
      mountainous.directories.paths.${cfg.dataDir} = {
        owner = cfg.user;
        group = cfg.group;
        mode = "0750";
      };

      # Bitmagnet systemd service
      systemd.services.bitmagnet = {
        description = "Bitmagnet BitTorrent indexer and DHT crawler";
        after = ["network.target" "postgresql.service"];
        requires = ["postgresql.service"];
        wantedBy = ["multi-user.target"];

        environment = envVars;

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.dataDir;
          ExecStart = "${pkgs.bitmagnet}/bin/bitmagnet worker run --all";
          Restart = "on-failure";
          RestartSec = "10s";

          # Hardening
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [cfg.dataDir];
        };

        preStart = let
          configFile = "${cfg.dataDir}/.bitmagnet.env";
          # Inject TMDB API key if provided
          tmdbInjection = lib.optionalString (cfg.tmdb.enable && cfg.tmdb.apiKeyFile != null) ''
            TMDB_API_KEY=$(cat ${cfg.tmdb.apiKeyFile})
            export TMDB_API_KEY
            echo "TMDB_API_KEY=$TMDB_API_KEY" >> ${configFile}
          '';
        in ''
          # Ensure data directory exists
          mkdir -p ${cfg.dataDir}
          chown ${cfg.user}:${cfg.group} ${cfg.dataDir}

          # Create environment file for secret injection
          rm -f ${configFile}
          touch ${configFile}
          chmod 600 ${configFile}

          ${tmdbInjection}

          # Source the environment file if it exists
          if [ -f ${configFile} ]; then
            set -a
            source ${configFile}
            set +a
          fi
        '';
      };

      # Wire up VPN and proxy internally
      mountainous.vpn-ns.services.bitmagnet = mkIf cfg.vpn.enable {
        enable = true;
        unit = "bitmagnet.service";
        port = cfg.port;
        tailscale = mkIf cfg.proxy.enable {
          enable = true;
          hostname = cfg.proxy.name;
          protocol = "http";
        };
      };

      # Firewall configuration for DHT port (both TCP and UDP)
      networking.firewall = mkIf cfg.openFirewall {
        allowedTCPPorts = [cfg.dhtPort];
        allowedUDPPorts = [cfg.dhtPort];
      };

      # Impermanence integration for Bitmagnet data
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

      # Ensure media user/group exists
      users.users.${cfg.user} = lib.mkIf (cfg.user == "media") (lib.mkDefault {
        isSystemUser = true;
        group = cfg.group;
        description = "Media services user";
      });

      users.groups.${cfg.group} = lib.mkIf (cfg.group == "media") (lib.mkDefault {});
    }

    # PostgreSQL database (always local, peer authentication)
    {
      services.postgresql = {
        enable = true;
        # Database name must match user for ensureDBOwnership
        ensureDatabases = [cfg.user];
        ensureUsers = [
          {
            name = cfg.user; # Must match service user for peer auth
            ensureDBOwnership = true;
          }
        ];
      };

      # Grant schema permissions (required for PostgreSQL 15+)
      systemd.services.bitmagnet-db-setup = {
        description = "Setup Bitmagnet database permissions";
        after = ["postgresql.service"];
        before = ["bitmagnet.service"];
        requiredBy = ["bitmagnet.service"];
        serviceConfig = {
          Type = "oneshot";
          User = "postgres";
          ExecStart = pkgs.writeShellScript "bitmagnet-db-grant-schema" ''
            ${config.services.postgresql.package}/bin/psql -d ${cfg.user} -c "GRANT ALL ON SCHEMA public TO ${cfg.user};" 2>/dev/null || true
          '';
        };
      };

      # Impermanence integration for PostgreSQL data
      environment.persistence."${config.mountainous.impermanence.persistPath}" = mkIf (config.mountainous.impermanence.enable or false) {
        directories = [
          {
            user = "postgres";
            group = "postgres";
            directory = "/var/lib/postgresql";
            mode = "0700";
          }
        ];
      };
    }
  ]);
}
