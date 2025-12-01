{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.mountainous.iceberg-array;
  sharedConfig = import ./config.nix {inherit lib;};
  icebergConfig = sharedConfig.icebergArray;
in {
  options.mountainous.iceberg-array = {
    enable = lib.mkEnableOption "Whether to enable the portable iceberg disk array";

    autoDetectPartitions = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically detect XFS partitions on iceberg disks";
    };

    disks = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          id = lib.mkOption {
            type = lib.types.str;
            description = "Disk identifier (e.g., 'iceberg00')";
          };
          device = lib.mkOption {
            type = lib.types.str;
            description = "Base device path without partition suffix";
          };
          partition = lib.mkOption {
            type = lib.types.str;
            default = "1";
            description = "Partition number to mount";
          };
          mountOptions = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = ["defaults" "nofail" "noatime" "lazytime" "x-systemd.device-timeout=30"];
            description = "Mount options for this disk";
          };
        };
      });
      default = icebergConfig.disks;
      description = "List of iceberg disks to mount";
    };

    mountPoints = {
      disks = lib.mkOption {
        type = lib.types.str;
        default = icebergConfig.mountPoints.disks;
        description = "Directory for individual disk mounts";
      };

      merged = lib.mkOption {
        type = lib.types.str;
        default = icebergConfig.mountPoints.merged;
        description = "Directory for merged filesystem views";
      };

      pools = lib.mkOption {
        type = lib.types.str;
        default = icebergConfig.mountPoints.pools;
        description = "Directory for storage pools";
      };

      groups = lib.mkOption {
        type = lib.types.str;
        default = icebergConfig.mountPoints.groups;
        description = "Directory for disk groups";
      };
    };

    media = {
      user = lib.mkOption {
        type = lib.types.str;
        default = icebergConfig.media.user;
        description = "Media user name";
      };

      uid = lib.mkOption {
        type = lib.types.int;
        default = icebergConfig.media.uid;
        description = "Media user ID";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = icebergConfig.media.group;
        description = "Media group name";
      };

      gid = lib.mkOption {
        type = lib.types.int;
        default = icebergConfig.media.gid;
        description = "Media group ID";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Systemd target for services that depend on iceberg array
    # With automount, access to paths triggers mounting on-demand
    # This target is just a synchronization point for services
    systemd.targets.iceberg-array = {
      description = "Iceberg Array Storage Target";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"];
    };

    # Target for the merged view
    systemd.targets.iceberg-merged = {
      description = "Iceberg Array Merged View Target";
      wantedBy = ["multi-user.target"];
      after = ["iceberg-array.target"];
    };

    # Combined fileSystems configuration
    fileSystems =
      # Safe mounting of existing iceberg array partitions (no formatting)
      (lib.listToAttrs (map (disk: {
          name = "${cfg.mountPoints.disks}/iceberg/${lib.strings.removePrefix "iceberg" disk.id}/0";
          value = {
            device = "${disk.device}-part${disk.partition}";
            fsType = "xfs";
            options = disk.mountOptions;
          };
        })
        cfg.disks))
      //
      # MergerFS configuration
      {
        "${cfg.mountPoints.merged}/iceberg" = {
          device = "${cfg.mountPoints.disks}/iceberg/00/0:${cfg.mountPoints.disks}/iceberg/01/0:${cfg.mountPoints.disks}/iceberg/04/0:${cfg.mountPoints.disks}/iceberg/05/0";
          fsType = "fuse.mergerfs";
          options = [
            "defaults"
            "nofail"
            "allow_other"
            "use_ino"
            "cache.files=partial"
            "dropcacheonclose=true"
            "category.create=mfs"
            "fsname=mergerfs-iceberg"
          ];
        };
      };

    # Create media user and group
    users.users.${cfg.media.user} = {
      uid = cfg.media.uid;
      group = cfg.media.group;
      isSystemUser = true;
      description = "Media server user";
    };

    users.groups.${cfg.media.group} = {
      gid = cfg.media.gid;
    };

    # SnapRAID configuration
    environment.etc."snapraid.conf".text = ''
      # SnapRAID configuration for portable iceberg array - optimized for SMR/CMR placement

      # CMR drives (fast) for data access
      ${lib.concatStringsSep "\n      " (lib.imap0 (i: diskId: "data d${toString (i + 1)} ${icebergConfig.getDiskMountPoint cfg.mountPoints diskId}") icebergConfig.snapraid.dataDisks)}

      # SMR drives (slow writes) for parity - written only during sync
      parity ${icebergConfig.getDiskMountPoint cfg.mountPoints (lib.elemAt icebergConfig.snapraid.parityDisks 0)}/snapraid.0.parity
      2-parity ${icebergConfig.getDiskMountPoint cfg.mountPoints (lib.elemAt icebergConfig.snapraid.parityDisks 1)}/snapraid.1.parity

      # Content files on all drives
      content /var/lib/snapraid/snapraid.content
      ${lib.concatStringsSep "\n      " (map (disk: "content ${icebergConfig.getDiskMountPoint cfg.mountPoints disk.id}/snapraid.content") cfg.disks)}

      # Optimized for SMR parity drives
      blocksize 256        # Keep at 256KB - larger blocks stress SMR
      hashsize 16          # Standard hash size
      autosave 1000        # Increase to reduce SMR write frequency
      nocrawl              # Disable timestamp crawling (reduces SMR stress)

      # Standard exclusions
      exclude *.tmp
      exclude /tmp/
      exclude /lost+found/
      exclude .Trash-*/
      exclude *.unrecoverable
      exclude /gaming/games

      # Better exclusions for media workflows
      exclude *.part
      exclude *.crdownload
      exclude *.!sync
      exclude .DS_Store
      exclude Thumbs.db
      exclude *.nfo.tmp
      exclude *.srt.tmp

      # Don't hide hidden files
      nohidden
    '';

    # Install required packages
    environment.systemPackages = with pkgs; [
      snapraid
      mergerfs
      bindfs
    ];

    # Create directory structure
    systemd.tmpfiles.rules = let
      mkRule = path: "d ${path} 0755 ${cfg.media.user} ${cfg.media.group} - -";
    in
      [
        # Base directories
        (mkRule cfg.mountPoints.disks)
        (mkRule cfg.mountPoints.merged)
        (mkRule cfg.mountPoints.pools)
        (mkRule cfg.mountPoints.groups)

        # Iceberg disk mount directories
        (mkRule "${cfg.mountPoints.disks}/iceberg")
      ]
      ++ (lib.flatten (map (disk: let
          diskNum = lib.strings.removePrefix "iceberg" disk.id;
        in [
          (mkRule "${cfg.mountPoints.disks}/iceberg/${diskNum}")
          (mkRule "${cfg.mountPoints.disks}/iceberg/${diskNum}/0")
        ])
        cfg.disks))
      ++ [
        # MergerFS directory
        (mkRule "${cfg.mountPoints.merged}/iceberg")

        # SnapRAID state directory
        "d /var/lib/snapraid 0755 root root - -"
      ];

    systemd.services.iceberg-array-snapraid-sync = {
      description = "SnapRAID Sync for Iceberg Array";
      after = ["iceberg-array.target"];
      wants = ["iceberg-array.target"];

      # Only run if at least the data disks are available
      unitConfig = {
        ConditionPathExists = map (diskId: icebergConfig.getDiskMountPoint cfg.mountPoints diskId) icebergConfig.snapraid.dataDisks;
      };

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.writeShellScript "snapraid-sync" ''
          set -euo pipefail

          if [ ! -f /etc/snapraid.conf ]; then
            echo "SnapRAID configuration not found"
            exit 1
          fi

          # Check that all data disks are mounted and accessible
          DATA_DISKS=(
            ${lib.concatStringsSep "\n            " (map (diskId: "\"${icebergConfig.getDiskMountPoint cfg.mountPoints diskId}\"") icebergConfig.snapraid.dataDisks)}
          )

          for disk in "''${DATA_DISKS[@]}"; do
            if [ ! -d "$disk" ] || ! mountpoint -q "$disk"; then
              echo "ERROR: Data disk not mounted: $disk"
              echo "SnapRAID sync cannot proceed without all data disks"
              exit 1
            fi
          done

          # Check parity disks (optional but warn if missing)
          PARITY_DISKS=(
            ${lib.concatStringsSep "\n            " (map (diskId: "\"${icebergConfig.getDiskMountPoint cfg.mountPoints diskId}\"") icebergConfig.snapraid.parityDisks)}
          )

          MISSING_PARITY=0
          for disk in "''${PARITY_DISKS[@]}"; do
            if [ ! -d "$disk" ] || ! mountpoint -q "$disk"; then
              echo "WARNING: Parity disk not mounted: $disk"
              MISSING_PARITY=1
            fi
          done

          if [ $MISSING_PARITY -eq 1 ]; then
            echo "WARNING: Not all parity disks available. Sync will proceed but redundancy is reduced."
          fi

          echo "Starting SnapRAID sync..."
          ${pkgs.snapraid}/bin/snapraid sync
          echo "SnapRAID sync completed successfully"
        ''}";
      };
    };

    systemd.timers.iceberg-array-snapraid = {
      description = "SnapRAID Sync Timer for Iceberg Array";
      wantedBy = ["timers.target"];

      timerConfig = {
        OnCalendar = "Mon 02:00"; # Weekly instead of daily - reduces SMR wear
        Persistent = true;
        RandomizedDelaySec = "2h"; # Spread load over 2h window
      };
    };

    # USB power management optimization - prevent disconnections
    boot.kernelParams = ["usbcore.autosuspend=-1"];

    # USB device-specific power management for TerraMaster enclosures
    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ATTRS{idVendor}=="152d", ATTRS{idProduct}=="0578", ATTR{power/autosuspend}="-1"
    '';
  };
}
