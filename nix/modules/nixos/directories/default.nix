{
  lib,
  config,
  ...
}: let
  cfg = config.mountainous.directories;

  # Convert a path to its systemd mount unit name
  pathToMountUnit = path: "${lib.replaceStrings ["/"] ["-"] (lib.removePrefix "/" path)}.mount";

  # Find the longest matching mount prefix for a path
  # Exported as a config option for use by other modules
  findMountPrefix = path:
    lib.foldl' (
      acc: prefix:
        if lib.hasPrefix prefix path && (builtins.stringLength prefix) > (builtins.stringLength acc)
        then prefix
        else acc
    ) ""
    (lib.attrNames cfg.mountPrefixes);

  # Get the mount service for a given path (if any)
  getMountServiceForPath = path: let
    prefix = findMountPrefix path;
  in
    if prefix != ""
    then cfg.mountPrefixes.${prefix}
    else null;

  # Generate all parent paths between a base and target path
  # e.g., getParentPaths "/mnt" "/mnt/a/b/c" -> ["/mnt/a" "/mnt/a/b" "/mnt/a/b/c"]
  getParentPaths = basePath: targetPath: let
    # Remove base from target to get relative part
    relative = lib.removePrefix basePath targetPath;
    # Split into components, filtering empty strings
    components = lib.filter (x: x != "") (lib.splitString "/" relative);
    # Build cumulative paths
    buildPaths = acc: component:
      acc
      ++ [
        (
          if acc == []
          then "${basePath}/${component}"
          else "${lib.last acc}/${component}"
        )
      ];
  in
    lib.foldl' buildPaths [] components;

  # Expand a single directory entry to include parents if requested
  expandEntry = path: dirCfg: let
    mountPrefix = findMountPrefix path;
    basePath =
      if mountPrefix != ""
      then mountPrefix
      else "";
    parentPaths =
      if dirCfg.parents
      then getParentPaths basePath path
      else [path];
  in
    map (p: {
      path = p;
      inherit dirCfg;
      mountPrefix = mountPrefix;
    })
    parentPaths;

  # Expand all entries
  allEntries = lib.flatten (lib.mapAttrsToList expandEntry cfg.paths);

  # Group directories by their mount dependency
  dirsByMount =
    lib.foldl' (
      acc: entry: let
        mountUnit =
          if entry.mountPrefix != ""
          then cfg.mountPrefixes.${entry.mountPrefix}
          else null;
        key =
          if mountUnit != null
          then mountUnit
          else "__no_mount__";
      in
        acc
        // {
          ${key} = (acc.${key} or []) ++ [entry];
        }
    ) {}
    allEntries;

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
          parents = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Create parent directories with the same ownership and mode";
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

    # Function to get mount service dependency for a path
    # Returns null if path doesn't need a mount dependency
    getMountService = lib.mkOption {
      type = lib.types.functionTo (lib.types.nullOr lib.types.str);
      default = getMountServiceForPath;
      readOnly = true;
      description = "Function to get the mount service for a given path";
    };

    # Function to get mount services for multiple paths
    # Returns list of unique mount services (non-null) for the given paths
    getMountServicesForPaths = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.str);
      default = paths: lib.unique (lib.filter (x: x != null) (map getMountServiceForPath paths));
      readOnly = true;
      description = "Function to get unique mount services for a list of paths";
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
