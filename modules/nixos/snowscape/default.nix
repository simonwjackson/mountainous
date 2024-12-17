{
  config,
  host,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.mountainous.snowscape;

  # Common MergerFS options
  commonMergerFSOptions = [
    "defaults"
    "allow_other"
    "use_ino"
    "cache.files=partial"
    "dropcacheonclose=true"
    "category.create=epff"
    "category.search=ff"
    "moveonenospc=true"
    "posix_acl=true"
    "atomic_o_trunc=true"
    "big_writes=true"
    "auto_cache=true"
    "cache.symlinks=true"
    "cache.readdir=true"
  ];

  # Helper to determine if we need MergerFS
  needsMergerFS = length cfg.paths > 1;

  # Helper to determine if we need a bind mount
  needsBindMount =
    cfg.mountPath
    != (
      if needsMergerFS
      then cfg.poolPath
      else head cfg.paths
    );
in {
  options.mountainous.snowscape = {
    enable = mkEnableOption "MergerFS pools configuration";

    glacier = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Glacier host name. If set, enables the glacier pool";
    };

    paths = mkOption {
      type = types.listOf types.str;
      description = "List of paths to merge";
      example = [
        "/avalanche/volumes/blizzard"
        "/avalanche/disks/sleet/0/00"
      ];
    };

    poolPath = mkOption {
      type = types.str;
      default = "/avalanche/pools/snowscape";
      description = "Path to the merged pool";
    };

    mountPath = mkOption {
      type = types.str;
      default = "/snowscape";
      description = "Path where the pool will be mounted";
    };

    user = mkOption {
      type = types.str;
      default = "media";
      description = "User who owns the directories";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Group who owns the directories";
    };
  };

  config = mkIf cfg.enable {
    # Validate that paths is not empty
    assertions = [
      {
        assertion = cfg.paths != [];
        message = "mountainous.snowscape.paths must not be empty";
      }
    ];

    fileSystems = mkMerge [
      # Main storage configuration
      (
        if needsBindMount
        then {
          "${cfg.mountPath}" = {
            device =
              if needsMergerFS
              then cfg.poolPath
              else head cfg.paths;
            options = ["bind"];
          };
        }
        else {}
      )

      (
        if needsMergerFS
        then {
          "${cfg.poolPath}" = {
            device = concatStringsSep ":" cfg.paths;
            fsType = "fuse.mergerfs";
            options = commonMergerFSOptions ++ ["fsname=pools-snowscape"];
            noCheck = true;
          };
        }
        else {}
      )

      # Glacier configuration (unchanged)
      (mkIf (cfg.glacier != null) {
        "/glacier" = {
          device = "/avalanche/pools/glacier";
          options = ["bind"];
        };

        "/avalanche/pools/glacier" = {
          device = "/net/${host}/nfs/snowscape:/net/${cfg.glacier}/nfs/snowscape";
          fsType = "fuse.mergerfs";
          options =
            commonMergerFSOptions
            ++ [
              "minfreespace=256M"
              "fsname=pools-glacier"
            ];
          noCheck = true;
        };
      })
    ];

    systemd.services.prepare-snowscape-dirs = {
      description = "Prepare directories for snowscape pool";
      after = [
        "avalanche-volumes-blizzard.mount"
        "avalanche-disks-sleet-0-00.mount"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${concatMapStrings (path: ''
            mkdir -p ${path}/snowscape
            chmod 2775 ${path}/snowscape
            chown ${cfg.user}:${cfg.group} ${path}/snowscape
          '')
          cfg.paths}
      '';
    };
  };
}
