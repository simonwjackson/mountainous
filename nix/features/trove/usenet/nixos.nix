{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types mapAttrsToList concatStringsSep;
  cfg = config.mountainous.trove.usenet;
  mediaCfg = config.mountainous.media;

  # Internal path requirements for this module
  requiredPaths = ["movies" "series" "comics"];

  # Server submodule
  serverOpts = {name, ...}: {
    options = {
      host = mkOption {
        type = types.str;
        description = "News server hostname";
        example = "news.newsdemon.com";
      };

      port = mkOption {
        type = types.port;
        default = 563;
        description = "News server port";
      };

      username = mkOption {
        type = types.str;
        description = "Username for authentication";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing password (use agenix)";
      };

      encryption = mkOption {
        type = types.bool;
        default = true;
        description = "Use TLS/SSL encryption";
      };

      connections = mkOption {
        type = types.int;
        default = 20;
        description = "Number of connections to use";
      };

      retention = mkOption {
        type = types.int;
        default = 0;
        description = "Server retention in days (0 = unlimited)";
      };
    };
  };

  # Generate server settings for nzbget.conf
  serverSettings = let
    servers = lib.attrValues cfg.servers;
    mkServerSetting = idx: srv: {
      "Server${toString idx}.Active" = true;
      "Server${toString idx}.Host" = srv.host;
      "Server${toString idx}.Port" = srv.port;
      "Server${toString idx}.Username" = srv.username;
      "Server${toString idx}.Encryption" = srv.encryption;
      "Server${toString idx}.Connections" = srv.connections;
      "Server${toString idx}.Retention" = srv.retention;
    };
  in
    lib.foldl' (acc: srv: acc // mkServerSetting (lib.length (lib.attrNames acc) / 7 + 1) srv) {} servers;

  # Servers with password files
  serversWithPasswords = lib.filterAttrs (_: srv: srv.passwordFile != null) cfg.servers;

  # Auto-configure category destinations from media paths
  categorySettings = {
    "Category1.Name" = "Movies";
    "Category1.DestDir" = mediaCfg.paths.movies;
    "Category1.Aliases" = "Movies *, movies, movie";
    "Category2.Name" = "Series";
    "Category2.DestDir" = mediaCfg.paths.series;
    "Category2.Aliases" = "TV *, Series *, series, tv, TV";
    "Category3.Name" = "Comics";
    "Category3.DestDir" = mediaCfg.paths.comics;
    "Category3.Aliases" = "Comics *, comics, comic";
  };
in {
  options.mountainous.trove.usenet = {
    enable = mkEnableOption "Usenet binary downloader with VPN isolation";

    user = mkOption {
      type = types.str;
      default = "media";
      description = "User to run NZBGet as";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Group to run NZBGet as";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/nzbget";
      description = "Directory for NZBGet data and downloads queue";
    };

    port = mkOption {
      type = types.port;
      default = 6789;
      description = "Port for NZBGet web interface";
    };

    vpn = {
      enable = mkEnableOption "VPN isolation for usenet downloads";
    };

    proxy = {
      enable = mkEnableOption "Tailscale proxy for usenet web UI";

      name = mkOption {
        type = types.str;
        default = "usenet";
        description = "Tailscale hostname";
      };
    };

    servers = mkOption {
      type = types.attrsOf (types.submodule serverOpts);
      default = {};
      description = "News servers to configure";
      example = lib.literalExpression ''
        {
          newsdemon = {
            host = "news.newsdemon.com";
            port = 563;
            username = "myuser";
            passwordFile = config.age.secrets.newsdemon-pass.path;
            connections = 50;
          };
        }
      '';
    };

    settings = mkOption {
      type = types.attrsOf (types.oneOf [types.bool types.int types.str]);
      default = {};
      description = ''
        NZBGet configuration settings. These are passed as command-line options.
        See https://github.com/nzbgetcom/nzbget/blob/develop/nzbget.conf for options.
        Category destinations are auto-configured from mountainous.media.paths.
      '';
      example = lib.literalExpression ''
        {
          UMask = "0022";
        }
      '';
    };

    downloadDir = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Directory for completed downloads (sets DestDir)";
    };

    intermediateDir = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Directory for in-progress downloads (sets InterDir)";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Validate required paths exist
      assertions =
        map (path: {
          assertion = mediaCfg.paths ? ${path};
          message = "NZBGet requires mountainous.media.paths.${path} to be defined";
        })
        requiredPaths;

      # Declaratively create NZBGet directories
      mountainous.directories.paths = {
        "${cfg.dataDir}/downloads" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
        "${cfg.dataDir}/downloads/completed" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
        "${cfg.dataDir}/downloads/intermediate" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
        "${cfg.dataDir}/downloads/nzb" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
        "${cfg.dataDir}/downloads/queue" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
        "${cfg.dataDir}/downloads/tmp" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
      };

      # Enable NZBGet service
      services.nzbget = {
        enable = true;
        inherit (cfg) user group;
        settings =
          {
            # Use explicit paths instead of ~/downloads (media user has no home)
            MainDir = "${cfg.dataDir}/downloads";
            DestDir =
              if cfg.downloadDir != null
              then cfg.downloadDir
              else "${cfg.dataDir}/downloads/completed";
            InterDir =
              if cfg.intermediateDir != null
              then cfg.intermediateDir
              else "${cfg.dataDir}/downloads/intermediate";
            NzbDir = "${cfg.dataDir}/downloads/nzb";
            QueueDir = "${cfg.dataDir}/downloads/queue";
            TempDir = "${cfg.dataDir}/downloads/tmp";

            # Bind to all interfaces for access from veth
            ControlIP = "0.0.0.0";
            ControlPort = cfg.port;
          }
          // serverSettings
          // categorySettings
          // cfg.settings;
      };

      # Inject passwords from secret files into nzbget.conf
      systemd.services.nzbget = mkIf (serversWithPasswords != {}) {
        preStart = let
          configFile = "${cfg.dataDir}/nzbget.conf";
          serverList = lib.attrNames cfg.servers;
          # Generate password injection commands
          injectCommands = lib.concatStringsSep "\n" (lib.imap1 (
              idx: name: let
                srv = cfg.servers.${name};
              in
                lib.optionalString (srv.passwordFile != null) ''
                  PASSWORD=$(cat ${srv.passwordFile})
                  ${pkgs.gnused}/bin/sed -i "s|^Server${toString idx}.Password=.*|Server${toString idx}.Password=$PASSWORD|" ${configFile}
                  if ! grep -q "^Server${toString idx}.Password=" ${configFile}; then
                    echo "Server${toString idx}.Password=$PASSWORD" >> ${configFile}
                  fi
                ''
            )
            serverList);
        in
          lib.mkAfter ''
            ${injectCommands}
          '';
      };

      # Wire up VPN and proxy internally
      mountainous.vpn-ns.services.nzbget = mkIf cfg.vpn.enable {
        enable = true;
        unit = "nzbget.service";
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
