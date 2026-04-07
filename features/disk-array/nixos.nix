{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge mapAttrsToList concatMap concatStringsSep listToAttrs nameValuePair imap0 flatten optionalAttrs optional;
  cfg = config.mountainous.features.disk-array;

  diskMountPath = pool: disk: "${pool.mountBase}/${disk.id}";

  poolDiskFileSystems = name: pool:
    listToAttrs (map (disk:
      nameValuePair (diskMountPath pool disk) {
        device = "${disk.device}-part${disk.partition}";
        fsType = pool.fsType;
        options = disk.mountOptions;
      }
    ) pool.disks);

  poolMergerfsFileSystem = name: pool: let
    dataDiskPaths = map (id: "${pool.mountBase}/${id}") pool.mergerfs.dataDisks;
    allBranches =
      (optional pool.cache.enable pool.cache.path)
      ++ dataDiskPaths;
  in {
    ${pool.mergedPath} = {
      device = concatStringsSep ":" allBranches;
      fsType = "fuse.mergerfs";
      options = [
        "noauto"
        "x-systemd.automount=false"
        "allow_other"
        "use_ino"
        "cache.files=partial"
        "dropcacheonclose=true"
        "category.create=${if pool.cache.enable then "ff" else pool.mergerfs.createPolicy}"
        "fsname=mergerfs-${name}"
      ] ++ pool.mergerfs.extraOptions;
    };
  };

  poolMergerfsService = name: pool: let
    dataDiskPaths = map (id: "${pool.mountBase}/${id}") pool.mergerfs.dataDisks;
    waitPaths = dataDiskPaths;
  in {
    "${name}-mergerfs-mount" = {
      description = "Mount ${name} MergerFS (after disks are ready)";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"];
      unitConfig.ConditionPathExists = "|${builtins.head dataDiskPaths}";
      path = with pkgs; [util-linux mount];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "${name}-mergerfs-mount" ''
          set -euo pipefail
          DATA_DISKS=(${concatStringsSep " " (map (p: ''"${p}"'') dataDiskPaths)})
          MERGED_PATH="${pool.mergedPath}"
          TIMEOUT=120
          WAITED=0

          echo "Waiting for ${name} data disks to mount..."
          while [ $WAITED -lt $TIMEOUT ]; do
            MOUNTED=0
            for disk in "''${DATA_DISKS[@]}"; do
              if mountpoint -q "$disk" 2>/dev/null; then
                ((MOUNTED++)) || true
              fi
            done
            if [ $MOUNTED -eq ''${#DATA_DISKS[@]} ]; then
              break
            fi
            sleep 1
            ((WAITED++)) || true
          done

          if [ $WAITED -ge $TIMEOUT ]; then
            echo "Timeout waiting for ${name} disks. Array may be disconnected — skipping."
            exit 0
          fi

          if mountpoint -q "$MERGED_PATH" 2>/dev/null; then
            echo "MergerFS already mounted at $MERGED_PATH"
            exit 0
          fi

          mount "$MERGED_PATH"
          echo "MergerFS mounted at $MERGED_PATH"
        '';
        ExecStop = pkgs.writeShellScript "${name}-mergerfs-umount" ''
          MERGED_PATH="${pool.mergedPath}"
          if mountpoint -q "$MERGED_PATH" 2>/dev/null; then
            umount "$MERGED_PATH" || true
          fi
        '';
      };
    };
  };

  poolTargets = name: pool: {
    "${name}-array" = {
      description = "${name} Array Storage Target";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"];
    };
    "${name}-merged" = {
      description = "${name} Merged View Target";
      wantedBy = ["multi-user.target"];
      after = ["${name}-mergerfs-mount.service"];
      requires = ["${name}-mergerfs-mount.service"];
    };
  };

  poolTmpfiles = name: pool:
    [
      "d ${pool.mountBase} 0755 root root - -"
      "d ${pool.mergedPath} 0755 root root - -"
    ]
    ++ map (disk: "d ${diskMountPath pool disk} 0755 root root - -") pool.disks;

  # --- SnapRAID helpers ---
  poolSnapraidConf = name: pool: let
    sr = pool.snapraid;
  in ''
    ${concatStringsSep "\n" (imap0 (i: diskId:
      "data d${toString (i + 1)} ${pool.mountBase}/${diskId}"
    ) sr.dataDisks)}

    ${concatStringsSep "\n" (imap0 (i: diskId:
      "${if i == 0 then "parity" else "${toString (i + 1)}-parity"} ${pool.mountBase}/${diskId}/snapraid.${toString i}.parity"
    ) sr.parityDisks)}

    content /var/lib/snapraid/${name}.content
    ${concatStringsSep "\n" (map (disk:
      "content ${diskMountPath pool disk}/snapraid.content"
    ) pool.disks)}

    blocksize 256
    hashsize 16
    autosave 1000
    nocrawl

    ${concatStringsSep "\n" (map (p: "exclude ${p}") sr.excludes)}

    nohidden
  '';

  poolSnapraidServices = name: pool: let
    sr = pool.snapraid;
    confPath = "/etc/snapraid-${name}.conf";
  in {
    "${name}-snapraid-sync" = {
      description = "SnapRAID Sync for ${name}";
      after = ["${name}-array.target"];
      wants = ["${name}-array.target"];
      unitConfig.ConditionPathExists = map (id: "${pool.mountBase}/${id}") sr.dataDisks;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "${name}-snapraid-sync" ''
          set -euo pipefail
          MAX_REMOVED=${toString sr.maxRemoved}
          MAX_UPDATED=${toString sr.maxUpdated}

          for disk in ${concatStringsSep " " (map (id: ''"${pool.mountBase}/${id}"'') sr.dataDisks)}; do
            if [ ! -d "$disk" ] || ! mountpoint -q "$disk"; then
              echo "ERROR: Data disk not mounted: $disk"
              exit 1
            fi
          done

          for disk in ${concatStringsSep " " (map (id: ''"${pool.mountBase}/${id}"'') sr.parityDisks)}; do
            if [ ! -d "$disk" ] || ! mountpoint -q "$disk"; then
              echo "WARNING: Parity disk not mounted: $disk"
            fi
          done

          echo "Running SnapRAID diff..."
          DIFF_OUTPUT=$(${pkgs.snapraid}/bin/snapraid -c ${confPath} diff 2>&1) || true
          echo "$DIFF_OUTPUT"

          REMOVED=$(echo "$DIFF_OUTPUT" | grep -oP '^\s*\K\d+(?=\s+removed)' || echo "0")
          UPDATED=$(echo "$DIFF_OUTPUT" | grep -oP '^\s*\K\d+(?=\s+updated)' || echo "0")

          if [ "$REMOVED" -gt "$MAX_REMOVED" ]; then
            echo "ERROR: $REMOVED removed exceeds threshold ($MAX_REMOVED). Aborting."
            exit 1
          fi
          if [ "$UPDATED" -gt "$MAX_UPDATED" ]; then
            echo "ERROR: $UPDATED updated exceeds threshold ($MAX_UPDATED). Aborting."
            exit 1
          fi

          echo "Starting SnapRAID sync..."
          ${pkgs.snapraid}/bin/snapraid -c ${confPath} sync
          echo "SnapRAID sync completed."
        '';
      };
    };
    "${name}-snapraid-scrub" = {
      description = "SnapRAID Scrub for ${name}";
      after = ["${name}-array.target" "${name}-snapraid-sync.service"];
      wants = ["${name}-array.target"];
      unitConfig.ConditionPathExists = map (id: "${pool.mountBase}/${id}") sr.dataDisks;
      serviceConfig = {
        Type = "oneshot";
        Nice = 19;
        IOSchedulingClass = "idle";
        ExecStart = pkgs.writeShellScript "${name}-snapraid-scrub" ''
          set -euo pipefail
          echo "Starting SnapRAID scrub (8% of data older than 10 days)..."
          ${pkgs.snapraid}/bin/snapraid -c ${confPath} scrub -p 8 -o 10
          echo "SnapRAID scrub completed."
        '';
      };
    };
  };

  poolSnapraidTimers = name: pool: let
    sr = pool.snapraid;
  in {
    "${name}-snapraid-sync" = {
      description = "SnapRAID Sync Timer for ${name}";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = sr.syncSchedule;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
    "${name}-snapraid-scrub" = {
      description = "SnapRAID Scrub Timer for ${name}";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = sr.scrubSchedule;
        Persistent = true;
        RandomizedDelaySec = "6h";
      };
    };
  };

  # --- Cache mover helpers ---
  poolCacheMoverService = name: pool: let
    cache = pool.cache;
    dataDiskPaths = map (id: "${pool.mountBase}/${id}") pool.mergerfs.dataDisks;
  in {
    "${name}-cache-mover" = {
      description = "Move aged files from ${name} cache to backing disks";
      after = ["${name}-mergerfs-mount.service"];
      wants = ["${name}-merged.target"];
      serviceConfig = {
        Type = "oneshot";
        Nice = 19;
        IOSchedulingClass = "idle";
        ExecStart = pkgs.writeShellScript "${name}-cache-mover" ''
          set -euo pipefail
          CACHE="${cache.path}"
          MERGED="${pool.mergedPath}"
          THRESHOLD=${toString cache.mover.threshold}
          OLDER_THAN=${toString cache.mover.olderThan}

          if ! mountpoint -q "$MERGED" 2>/dev/null; then
            echo "Merged pool not mounted — skipping."
            exit 0
          fi

          # Check cache usage
          USAGE=$(df --output=pcent "$CACHE" | tail -1 | tr -d ' %')
          if [ "$USAGE" -lt "$THRESHOLD" ]; then
            echo "Cache usage ''${USAGE}% < ''${THRESHOLD}% threshold — skipping."
            exit 0
          fi

          echo "Cache usage ''${USAGE}% >= ''${THRESHOLD}% — moving files older than ''${OLDER_THAN}m..."

          # Find files older than threshold and move them via the merged view.
          # rsync through mergerfs with existing-path policy handles placement.
          find "$CACHE" -mindepth 1 -mmin +"$OLDER_THAN" -type f -print0 | while IFS= read -r -d "" file; do
            REL="''${file#$CACHE/}"
            DEST_DIR="$MERGED/$(dirname "$REL")"
            mkdir -p "$DEST_DIR"
            ${pkgs.rsync}/bin/rsync -axqHAXWES --preallocate --remove-source-files "$file" "$DEST_DIR/"
          done

          # Clean empty directories left behind in cache
          find "$CACHE" -mindepth 1 -type d -empty -delete 2>/dev/null || true

          echo "Cache mover completed."
        '';
      };
    };
  };

  poolCacheMoverTimer = name: pool: {
    "${name}-cache-mover" = {
      description = "Cache mover timer for ${name}";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = pool.cache.mover.schedule;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };
  };

  # --- USB helpers ---
  poolNeedsUsbFix = _name: pool: pool.usb.disableAutosuspend;
  poolUdevRules = _name: pool:
    map (rule:
      ''SUBSYSTEM=="usb", ATTRS{idVendor}=="${rule.vendor}", ATTRS{idProduct}=="${rule.product}", ATTR{power/autosuspend}="-1"''
    ) pool.usb.udevRules;

  # --- Collect across all pools ---
  poolNames = builtins.attrNames cfg.pools;
  poolList = mapAttrsToList (name: pool: {inherit name pool;}) cfg.pools;
in {
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      mergerfs
    ] ++ optional (builtins.any (p: p.pool.snapraid.enable) poolList) pkgs.snapraid;

    systemd.tmpfiles.rules =
      [
        "d /srv/shores 0755 root root - -"
        "d /srv/lakes 0755 root root - -"
      ]
      ++ concatMap (p: poolTmpfiles p.name p.pool) poolList;

    fileSystems = mkMerge (
      (map (p: poolDiskFileSystems p.name p.pool) poolList)
      ++ (map (p: poolMergerfsFileSystem p.name p.pool) poolList)
    );

    systemd.services = mkMerge (
      (map (p: poolMergerfsService p.name p.pool) poolList)
      ++ (map (p:
        if p.pool.snapraid.enable
        then poolSnapraidServices p.name p.pool
        else {}
      ) poolList)
      ++ (map (p:
        if p.pool.cache.enable
        then poolCacheMoverService p.name p.pool
        else {}
      ) poolList)
    );

    systemd.targets = mkMerge (map (p: poolTargets p.name p.pool) poolList);

    systemd.timers = mkMerge (
      (map (p:
        if p.pool.snapraid.enable
        then poolSnapraidTimers p.name p.pool
        else {}
      ) poolList)
      ++ (map (p:
        if p.pool.cache.enable
        then poolCacheMoverTimer p.name p.pool
        else {}
      ) poolList)
    );

    environment.etc = mkMerge (map (p:
      if p.pool.snapraid.enable
      then {"snapraid-${p.name}.conf".text = poolSnapraidConf p.name p.pool;}
      else {}
    ) poolList);

    boot.kernelParams =
      optional (builtins.any (p: p.pool.usb.disableAutosuspend) poolList)
      "usbcore.autosuspend=-1";

    services.udev.extraRules =
      concatStringsSep "\n" (concatMap (p: poolUdevRules p.name p.pool) poolList);
  };
}
