{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge mkDefault types;
  cfg = config.mountainous.trove.flexget;
  mediaCfg = config.mountainous.media;

  # Module-internal path requirements
  requiredPaths = ["movies" "series"];

  # YAML format for type-safe configuration
  yamlFormat = pkgs.formats.yaml {};

  # Overlay to patch flexget with web UI assets and bug fixes
  flexgetOverlay = final: prev: {
    flexget = prev.flexget.overridePythonAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          # Fix torznab plugin bug: uses BeautifulSoup syntax on ElementTree
          # item.title.string -> item.find('title').text
          substituteInPlace flexget/plugins/input/torznab.py \
            --replace-fail "item.title.string" "(item.find('title').text if item.find('title') is not None else 'Unknown')"

          # Fix torznab enclosure matching: support magnet MIME type from Bitmagnet
          # Bitmagnet returns type="application/x-bittorrent;x-scheme-handler/magnet"
          # FlexGet only matches exact "application/x-bittorrent"
          substituteInPlace flexget/plugins/input/torznab.py \
            --replace-fail \
              "enclosure = item.find(\"enclosure[@type='application/x-bittorrent']\")" \
              "enclosure = item.find(\"enclosure[@type='application/x-bittorrent']\") or item.find(\"enclosure[@type='application/x-bittorrent;x-scheme-handler/magnet']\")"
        '';
      postInstall =
        (old.postInstall or "")
        + ''
          # Install web UI assets
          mkdir -p $out/${prev.python3.sitePackages}/flexget/ui/v2/dist
          cp -r ${final.flexget-webui}/* $out/${prev.python3.sitePackages}/flexget/ui/v2/dist/
        '';
    });
  };
in {
  options.mountainous.trove.flexget = {
    enable = mkEnableOption "FlexGet media automation";

    user = mkOption {
      type = types.str;
      default = "media";
      description = "User to run FlexGet as";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Group to run FlexGet as";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/flexget";
      description = "Directory for FlexGet database and state";
    };

    interval = mkOption {
      type = types.str;
      default = "15m";
      description = "How often to run FlexGet tasks (systemd time format)";
    };

    config = mkOption {
      type = yamlFormat.type;
      default = {};
      description = "FlexGet configuration as a Nix attribute set (converted to YAML)";
      example = {
        tasks = {
          download-shows = {
            rss = "https://example.com/rss";
            series = ["Breaking Bad"];
            download = "/downloads/tv/";
          };
        };
      };
    };

    webUI = {
      enable = mkEnableOption "FlexGet web UI";

      port = mkOption {
        type = types.port;
        default = 5050;
        description = "Port for FlexGet web UI";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing the web UI password (use agenix)";
        example = "config.age.secrets.flexget-password.path";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall port for FlexGet web UI";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Validation: error if required paths not defined
      assertions =
        map (path: {
          assertion = mediaCfg.paths ? ${path};
          message = "mountainous.trove.flexget requires mountainous.media.paths.${path} to be defined";
        })
        requiredPaths;

      # Declaratively create FlexGet directory
      mountainous.directories.paths.${cfg.dataDir} = {
        owner = cfg.user;
        group = cfg.group;
        mode = "0700";
      };

      # Apply overlay to patch flexget with web UI
      nixpkgs.overlays = [flexgetOverlay];

      # Create flexget user/group
      users.users.${cfg.user} = mkIf (cfg.user == "flexget") {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        createHome = true;
        description = "FlexGet daemon user";
      };

      users.groups.${cfg.group} = mkIf (cfg.group == "flexget") {};

      # Add dependencies on mount services for any media paths that require them
      # This ensures flexget waits for mounts like iceberg mergerfs
      systemd.services.flexget = let
        mountServices =
          config.mountainous.directories.getMountServicesForPaths
          (lib.attrValues mediaCfg.paths);
      in
        lib.mkIf (mountServices != []) {
          after = mountServices;
          requires = mountServices;
        };

      # Use upstream NixOS module
      services.flexget = {
        inherit (cfg) user interval;

        enable = true;
        homeDir = cfg.dataDir;
        # Use FlexGet's internal scheduler when schedules are defined in config
        # systemScheduler=true appends "schedules: no" which conflicts with JSON output
        systemScheduler = !(cfg.config ? schedules && cfg.config.schedules != []);
        config = let
          # Merge web_server config if webUI is enabled
          mergedConfig =
            cfg.config
            // lib.optionalAttrs cfg.webUI.enable {
              web_server = {
                bind = "0.0.0.0";
                port = cfg.webUI.port;
              };
            };
        in
          lib.generators.toYAML {} mergedConfig;
      };

      # Firewall for web UI
      networking.firewall.allowedTCPPorts =
        lib.optional (cfg.openFirewall && cfg.webUI.enable) cfg.webUI.port;

      # Impermanence integration - persist FlexGet data
      environment.persistence."${config.mountainous.impermanence.persistPath}" =
        mkIf (config.mountainous.impermanence.enable or false)
        {
          directories = [
            {
              inherit (cfg) user group;
              directory = cfg.dataDir;
              mode = "0700";
            }
          ];
        };
    }

    # Set web UI password from agenix secret
    # Runs BEFORE flexget starts to avoid lock file conflicts
    (mkIf (cfg.webUI.enable && cfg.webUI.passwordFile != null) {
      systemd.services.flexget-set-password = {
        description = "Set FlexGet web UI password";
        before = ["flexget.service"];
        requiredBy = ["flexget.service"];
        unitConfig.ConditionPathExists = "${cfg.dataDir}/db-config.sqlite";
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.group;
          ExecStart = pkgs.writeShellScript "flexget-set-password" ''
            set -e
            PASSWORD=$(cat ${cfg.webUI.passwordFile})
            ${pkgs.flexget}/bin/flexget -c "${cfg.dataDir}/flexget.yml" web passwd "$PASSWORD"
          '';
        };
      };
    })
  ]);
}
