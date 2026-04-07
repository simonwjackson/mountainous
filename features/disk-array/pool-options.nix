{lib}: {
  name,
  config,
  ...
}: let
  inherit (lib) mkOption types mkEnableOption;
  poolName = name;
in {
  options = {
    disks = mkOption {
      type = types.listOf (types.submodule {
        options = {
          id = mkOption {
            type = types.str;
            description = "Disk identifier (e.g. '00', '01'). Used in mount path.";
          };
          device = mkOption {
            type = types.str;
            description = "Device path (by-id recommended), without partition suffix.";
            example = "/dev/disk/by-id/usb-TerraMas_TDAS_SERIAL-0:0";
          };
          partition = mkOption {
            type = types.str;
            default = "1";
            description = "Partition number to mount.";
          };
          mountOptions = mkOption {
            type = types.listOf types.str;
            default = ["defaults" "nofail" "noatime" "lazytime" "x-systemd.device-timeout=90"];
            description = "Mount options for this disk.";
          };
        };
      });
      default = [];
      description = "List of disks in this pool.";
    };

    fsType = mkOption {
      type = types.str;
      default = "xfs";
      description = "Filesystem type of the individual disks.";
    };

    mountBase = mkOption {
      type = types.str;
      default = "/srv/shores/${poolName}";
      description = "Base path for individual disk mounts. Each disk mounts at <mountBase>/<id>.";
    };

    mergedPath = mkOption {
      type = types.str;
      default = "/srv/lakes/${poolName}";
      description = "Path for the mergerfs merged view of this pool.";
    };

    mergerfs = {
      dataDisks = mkOption {
        type = types.listOf types.str;
        default = map (d: d.id) config.disks;
        defaultText = lib.literalExpression "all disk IDs";
        description = "Disk IDs to include in the mergerfs union. Defaults to all disks.";
      };

      createPolicy = mkOption {
        type = types.str;
        default = "pfrd";
        description = "mergerfs category.create policy.";
      };

      extraOptions = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional mergerfs mount options.";
      };
    };

    snapraid = {
      enable = mkEnableOption "SnapRAID parity protection for this pool";

      dataDisks = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Disk IDs used as SnapRAID data disks.";
      };

      parityDisks = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Disk IDs used as SnapRAID parity disks.";
      };

      syncSchedule = mkOption {
        type = types.str;
        default = "*-*-* 03:00";
        description = "OnCalendar schedule for SnapRAID sync.";
      };

      scrubSchedule = mkOption {
        type = types.str;
        default = "monthly";
        description = "OnCalendar schedule for SnapRAID scrub.";
      };

      maxRemoved = mkOption {
        type = types.int;
        default = 50;
        description = "Safety threshold: abort sync if more than this many files were removed.";
      };

      maxUpdated = mkOption {
        type = types.int;
        default = 100;
        description = "Safety threshold: abort sync if more than this many files were updated.";
      };

      excludes = mkOption {
        type = types.listOf types.str;
        default = [
          "*.tmp"
          "/tmp/"
          "/lost+found/"
          ".Trash-*/"
          "*.unrecoverable"
          "*.part"
          "*.crdownload"
          "*.!sync"
          ".DS_Store"
          "Thumbs.db"
        ];
        description = "File patterns to exclude from SnapRAID.";
      };
    };

    cache = {
      enable = mkEnableOption "NVMe/SSD write cache tier prepended to mergerfs";

      path = mkOption {
        type = types.str;
        default = "/srv/cache/${poolName}";
        description = "Path to the fast cache directory (should be on NVMe/SSD).";
      };

      mover = {
        schedule = mkOption {
          type = types.str;
          default = "hourly";
          description = "OnCalendar schedule for the cache mover.";
        };

        threshold = mkOption {
          type = types.int;
          default = 80;
          description = "Move files when cache filesystem usage exceeds this percentage.";
        };

        olderThan = mkOption {
          type = types.int;
          default = 60;
          description = "Only move files older than this many minutes.";
        };
      };
    };

    usb = {
      disableAutosuspend = mkEnableOption "USB autosuspend disable (prevents disconnections)";

      udevRules = mkOption {
        type = types.listOf (types.submodule {
          options = {
            vendor = mkOption {type = types.str;};
            product = mkOption {type = types.str;};
          };
        });
        default = [];
        description = "USB vendor/product pairs to disable autosuspend for.";
      };
    };
  };
}
