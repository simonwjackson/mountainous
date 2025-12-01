{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types;
  cfg = config.mountainous.database.postgresql;
in {
  options.mountainous.database.postgresql = {
    enable = mkEnableOption "PostgreSQL database server";

    user = mkOption {
      type = types.str;
      default = "postgres";
      description = "User to run PostgreSQL as";
    };

    group = mkOption {
      type = types.str;
      default = "postgres";
      description = "Group to run PostgreSQL as";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/postgresql";
      description = "Directory for PostgreSQL data";
    };

    port = mkOption {
      type = types.port;
      default = 5432;
      description = "Port for PostgreSQL server";
    };

    ensureDatabases = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of database names to create automatically";
      example = ["myapp" "nextcloud"];
    };

    ensureUsers = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Name of the user to create";
          };
          ensureDBOwnership = mkOption {
            type = types.bool;
            default = false;
            description = "Ensure user owns a database with the same name";
          };
          ensureClauses = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Additional SQL clauses for user creation";
            example = {
              superuser = "true";
              createrole = "true";
            };
          };
        };
      });
      default = [];
      description = "List of users to create automatically";
      example = lib.literalExpression ''
        [
          {
            name = "myapp";
            ensureDBOwnership = true;
          }
          {
            name = "admin";
            ensureClauses = {
              superuser = "true";
            };
          }
        ]
      '';
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings to pass to services.postgresql.settings";
      example = {
        max_connections = 200;
        shared_buffers = "256MB";
      };
    };

    authentication = mkOption {
      type = types.lines;
      default = "";
      description = "Additional authentication rules for pg_hba.conf";
      example = ''
        host all all 192.168.1.0/24 md5
      '';
    };

    enableTCPIP = mkOption {
      type = types.bool;
      default = false;
      description = "Enable TCP/IP connections";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.postgresql = {
        enable = true;
        dataDir = cfg.dataDir;
        ensureDatabases = cfg.ensureDatabases;
        ensureUsers = cfg.ensureUsers;
        enableTCPIP = cfg.enableTCPIP;
        settings = {port = cfg.port;} // cfg.settings;
        authentication = mkIf (cfg.authentication != "") cfg.authentication;
      };

      # Impermanence integration
      environment.persistence."${config.mountainous.impermanence.persistPath}" = mkIf (config.mountainous.impermanence.enable or false) {
        directories = [
          {
            inherit (cfg) user group;
            directory = cfg.dataDir;
            mode = "0700";
          }
        ];
      };
    }
  ]);
}
