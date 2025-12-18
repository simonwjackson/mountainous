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
    # Register mount prefix for the directories module
    # Use our mount service instead of the raw mount unit
    mountainous.directories.mountPrefixes."${cfg.mountPoints.merged}/iceberg" = "iceberg-mergerfs-mount.service";

    # Systemd target for services that depend on iceberg array
    # With automount, access to paths triggers mounting on-demand
    # This target is just a synchronization point for services
    systemd.targets.iceberg-array = {
      description = "Iceberg Array Storage Target";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"];
    };

    # Target for the merged view - depends on the mount service
    systemd.targets.iceberg-merged = {
      description = "Iceberg Array Merged View Target";
      wantedBy = ["multi-user.target"];
      after = ["iceberg-mergerfs-mount.service"];
      requires = ["iceberg-mergerfs-mount.service"];
    };

    # Service to mount mergerfs only after data disks are available
    systemd.services.iceberg-mergerfs-mount = let
      dataDiskPaths =
        map (
          diskId: let
            diskNum = lib.strings.removePrefix "iceberg" diskId;
          in "${cfg.mountPoints.disks}/iceberg/${diskNum}/0"
        )
        icebergConfig.snapraid.dataDisks;
    in {
      description = "Mount Iceberg MergerFS (after disks are ready)";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"];

      # Only start if at least one data disk device exists
      # This prevents the service from running when array is disconnected
      unitConfig = {
        ConditionPathExists = "|${builtins.head dataDiskPaths}";
      };

      path = with pkgs; [util-linux mount];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "iceberg-mergerfs-mount" ''
          set -euo pipefail

          DATA_DISKS=(${lib.concatStringsSep " " (map (p: ''"${p}"'') dataDiskPaths)})
          MERGED_PATH="${cfg.mountPoints.merged}/iceberg"

          # Wait for disk mounts (with timeout)
          # Must be longer than x-systemd.device-timeout (90s) to give disks time
          TIMEOUT=120
          WAITED=0
          READY=0

          echo "Waiting for iceberg data disks to mount..."

          while [ $WAITED -lt $TIMEOUT ]; do
            MOUNTED=0
            for disk in "''${DATA_DISKS[@]}"; do
              if mountpoint -q "$disk" 2>/dev/null; then
                ((MOUNTED++)) || true
              fi
            done

            if [ $MOUNTED -eq ''${#DATA_DISKS[@]} ]; then
              READY=1
              break
            fi

            sleep 1
            ((WAITED++)) || true
          done

          if [ $READY -eq 0 ]; then
            echo "Timeout waiting for iceberg disks. Mounted: $MOUNTED/''${#DATA_DISKS[@]}"
            echo "Array may be disconnected - skipping mergerfs mount"
            exit 0
          fi

          echo "All data disks mounted, mounting mergerfs..."

          # Check if already mounted
          if mountpoint -q "$MERGED_PATH" 2>/dev/null; then
            echo "MergerFS already mounted at $MERGED_PATH"
            exit 0
          fi

          mount "$MERGED_PATH"
          echo "MergerFS mounted successfully at $MERGED_PATH"
        '';

        ExecStop = pkgs.writeShellScript "iceberg-mergerfs-umount" ''
          MERGED_PATH="${cfg.mountPoints.merged}/iceberg"
          if mountpoint -q "$MERGED_PATH" 2>/dev/null; then
            umount "$MERGED_PATH" || true
          fi
        '';
      };
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
      # MergerFS configuration - uses noauto so we control mounting via systemd service
      {
        "${cfg.mountPoints.merged}/iceberg" = {
          device = "${cfg.mountPoints.disks}/iceberg/00/0:${cfg.mountPoints.disks}/iceberg/01/0:${cfg.mountPoints.disks}/iceberg/04/0:${cfg.mountPoints.disks}/iceberg/05/0";
          fsType = "fuse.mergerfs";
          options = [
            "noauto" # Don't mount automatically - let our service handle it
            "x-systemd.automount=false" # Prevent any automount attempts
            "allow_other"
            "use_ino"
            "cache.files=partial"
            "dropcacheonclose=true"
            "category.create=pfrd"
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

          # Thresholds for safety checks (prevent ransomware/accidental mass deletion)
          MAX_REMOVED=50
          MAX_UPDATED=100

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

          # Run diff check before sync to detect suspicious changes
          echo "Running SnapRAID diff to check for changes..."
          DIFF_OUTPUT=$(${pkgs.snapraid}/bin/snapraid diff 2>&1) || true
          echo "$DIFF_OUTPUT"

          # Parse diff output for removed and updated counts
          REMOVED=$(echo "$DIFF_OUTPUT" | grep -oP '^\s*\K\d+(?=\s+removed)' || echo "0")
          UPDATED=$(echo "$DIFF_OUTPUT" | grep -oP '^\s*\K\d+(?=\s+updated)' || echo "0")

          if [ "$REMOVED" -gt "$MAX_REMOVED" ]; then
            echo "ERROR: $REMOVED files removed exceeds safety threshold of $MAX_REMOVED"
            echo "This could indicate ransomware, accidental deletion, or misconfiguration."
            echo "Review changes manually with 'snapraid diff' before running 'snapraid sync --force'"
            exit 1
          fi

          if [ "$UPDATED" -gt "$MAX_UPDATED" ]; then
            echo "ERROR: $UPDATED files updated exceeds safety threshold of $MAX_UPDATED"
            echo "This could indicate ransomware or mass file corruption."
            echo "Review changes manually with 'snapraid diff' before running 'snapraid sync --force'"
            exit 1
          fi

          echo "Diff check passed (removed: $REMOVED/$MAX_REMOVED, updated: $UPDATED/$MAX_UPDATED)"
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
        OnCalendar = "*-*-* 03:00"; # Daily at 3 AM - protects new content within 24h
        Persistent = true;
        RandomizedDelaySec = "1h"; # Spread load over 1h window
      };
    };

    # Monthly scrub service to verify data integrity
    systemd.services.iceberg-array-snapraid-scrub = {
      description = "SnapRAID Scrub for Iceberg Array";
      after = ["iceberg-array.target" "iceberg-array-snapraid-sync.service"];
      wants = ["iceberg-array.target"];

      unitConfig = {
        ConditionPathExists = map (diskId: icebergConfig.getDiskMountPoint cfg.mountPoints diskId) icebergConfig.snapraid.dataDisks;
      };

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Nice = 19; # Low priority - don't interfere with normal operations
        IOSchedulingClass = "idle";
        ExecStart = "${pkgs.writeShellScript "snapraid-scrub" ''
          set -euo pipefail

          if [ ! -f /etc/snapraid.conf ]; then
            echo "SnapRAID configuration not found"
            exit 1
          fi

          # Scrub 8% of the oldest data, files older than 10 days
          # At 8% monthly, full array verification takes ~12 months
          echo "Starting SnapRAID scrub (8% of data older than 10 days)..."
          ${pkgs.snapraid}/bin/snapraid scrub -p 8 -o 10
          echo "SnapRAID scrub completed successfully"
        ''}";
      };
    };

    systemd.timers.iceberg-array-snapraid-scrub = {
      description = "SnapRAID Scrub Timer for Iceberg Array";
      wantedBy = ["timers.target"];

      timerConfig = {
        OnCalendar = "monthly"; # First day of each month
        Persistent = true;
        RandomizedDelaySec = "6h"; # Spread over 6h window
      };
    };

    # USB power management optimization - prevent disconnections
    boot.kernelParams = ["usbcore.autosuspend=-1"];

    # USB device-specific power management for TerraMaster enclosures
    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ATTRS{idVendor}=="152d", ATTRS{idProduct}=="0578", ATTR{power/autosuspend}="-1"
    '';

    # SMART monitoring for TerraMaster drives (extends existing smartd config)
    services.smartd = {
      enable = true;
      devices =
        map (disk: {
          device = disk.device;
        })
        cfg.disks;
    };
  };
}
