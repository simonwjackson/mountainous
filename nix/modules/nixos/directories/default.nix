{
  lib,
  config,
  ...
}: let
  cfg = config.mountainous.directories;

  # Convert a path to its systemd mount unit name
  pathToMountUnit = path: "${lib.replaceStrings ["/"] ["-"] (lib.removePrefix "/" path)}.mount";

  # Find the longest matching mount prefix for a path
  findMountPrefix = path:
    lib.foldl' (
      acc: prefix:
        if lib.hasPrefix prefix path && (builtins.stringLength prefix) > (builtins.stringLength acc)
        then prefix
        else acc
    ) ""
    (lib.attrNames cfg.mountPrefixes);

  # Group directories by their mount dependency
  dirsByMount = lib.foldl' (
    acc: path: let
      dirCfg = cfg.paths.${path};
      mountPrefix = findMountPrefix path;
      mountUnit =
        if mountPrefix != ""
        then cfg.mountPrefixes.${mountPrefix}
        else null;
      key =
        if mountUnit != null
        then mountUnit
        else "__no_mount__";
    in
      acc
      // {
        ${key} = (acc.${key} or []) ++ [{inherit path dirCfg mountUnit;}];
      }
  ) {} (lib.attrNames cfg.paths);

  # Generate tmpfiles rules for directories without mount dependencies
  tmpfilesRules = lib.optionals (dirsByMount ? "__no_mount__") (
    map (
      entry: "d ${entry.path} ${entry.dirCfg.mode} ${entry.dirCfg.owner} ${entry.dirCfg.group} - -"
    )
    dirsByMount.__no_mount__
  );

  # Generate systemd services for directories with mount dependencies
  mountServices = lib.filterAttrs (name: _: name != "__no_mount__") dirsByMount;
in {
  options.mountainous.directories = {
    paths = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          owner = lib.mkOption {
            type = lib.types.str;
            default = "root";
            description = "Owner of the directory";
          };
          group = lib.mkOption {
            type = lib.types.str;
            default = "root";
            description = "Group of the directory";
          };
          mode = lib.mkOption {
            type = lib.types.str;
            default = "0755";
            description = "Permissions mode for the directory";
          };
        };
      });
      default = {};
      description = "Directories to ensure exist with specified ownership and permissions";
      example = lib.literalExpression ''
        {
          "/tundra/merged/iceberg/media" = {
            owner = "media";
            group = "media";
            mode = "0755";
          };
        }
      '';
    };

    mountPrefixes = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Map of path prefixes to their systemd mount unit names";
      example = lib.literalExpression ''
        {
          "/tundra/merged/iceberg" = "tundra-merged-iceberg.mount";
        }
      '';
    };
  };

  config = lib.mkIf (cfg.paths != {}) {
    # Directories without mount dependencies use tmpfiles
    systemd.tmpfiles.rules = tmpfilesRules;

    # Directories with mount dependencies get dedicated services
    systemd.services =
      lib.mapAttrs' (
        mountUnit: entries:
          lib.nameValuePair "ensure-dirs-${lib.replaceStrings [".mount" "/"] ["" "-"] mountUnit}" {
            description = "Ensure directories exist after ${mountUnit}";
            after = [mountUnit];
            requires = [mountUnit];
            wantedBy = ["multi-user.target"];
            serviceConfig.Type = "oneshot";
            serviceConfig.RemainAfterExit = true;
            script =
              lib.concatMapStringsSep "\n" (
                entry: "install -d -m ${entry.dirCfg.mode} -o ${entry.dirCfg.owner} -g ${entry.dirCfg.group} ${entry.path}"
              )
              entries;
          }
      )
      mountServices;
  };
}
