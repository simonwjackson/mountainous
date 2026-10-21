{
  config,
  lib,
  pkgs,
  utils,
  ...
}: let
  inherit (lib) mkIf mkMerge mapAttrsToList concatMap concatStringsSep listToAttrs nameValuePair imap0 optional;
  cfg = config.mountainous.features.disk-array;

  diskMountPath = pool: disk: "${pool.mountBase}/${disk.id}";

  poolDiskFileSystems = name: pool:
    listToAttrs (map (
        disk:
          nameValuePair (diskMountPath pool disk) {
            device = "${disk.device}-part${disk.partition}";
            fsType = pool.fsType;
            options = disk.mountOptions;
          }
      )
      pool.disks);

  poolMergerfsFileSystem = name: pool: let
    dataDiskPaths = map (id: "${pool.mountBase}/${id}") pool.mergerfs.dataDisks;
    allBranches =
      (optional pool.cache.enable pool.cache.path)
      ++ dataDiskPaths;
  in {
    ${pool.mergedPath} = {
      device = concatStringsSep ":" allBranches;
      fsType = "fuse.mergerfs";
      options =
        [
          "noauto"
          "nofail"
          "x-systemd.requires=${name}-storage-admission.service"
          "x-systemd.after=${name}-storage-admission.service"
          "allow_other"
          "use_ino"
          # The lake is exported over NFS. Without noforget, mergerfs drops a
          # node when the kernel evicts its dentry, and every NFS handle to it
          # turns stale (Unzen's library views, 2026-10-21). The cost is
          # memory for each path ever looked up.
          "noforget"
          "cache.files=partial"
          "dropcacheonclose=true"
          "category.create=${
            if pool.cache.enable
            then "ff"
            else pool.mergerfs.createPolicy
          }"
          "fsname=mergerfs-${name}"
        ]
        ++ map (unit: "x-systemd.requires=${unit}") (backingUnits pool)
        ++ map (unit: "x-systemd.after=${unit}") (backingUnits pool)
        ++ pool.mergerfs.extraOptions;
    };
  };

  mountUnit = path: "${utils.escapeSystemdPath path}.mount";
  backingUnits = pool:
    map (disk: mountUnit (diskMountPath pool disk)) pool.disks
    ++ optional pool.cache.enable (mountUnit pool.cache.path);
  moverConfig = name: pool:
    pkgs.writeText "${name}-storage.json" (builtins.toJSON {
      mounts =
        map (disk: {
          inherit (disk) id uuid;
          path = diskMountPath pool disk;
          device = "${disk.device}-part${disk.partition}";
          fsType = pool.fsType;
        })
        pool.disks
        ++ optional pool.cache.enable {
          id = "cache";
          path = pool.cache.path;
          inherit (pool.cache) device uuid fsRoot fsType;
        };
      data = pool.snapraid.dataDisks;
      excludes = pool.snapraid.excludes;
      ageMinutes = pool.cache.mover.olderThan;
      stateDir = "/var/lib/disk-array/${name}/receipts";
      statusPath = "/var/lib/disk-array/${name}/status.json";
      lock = "/run/lock/disk-array-${name}.lock";
      snapraid = "${pkgs.snapraid}/bin/snapraid";
      snapraidConfig = "/etc/snapraid-${name}.conf";
      inherit (pool.snapraid) maxRemoved maxUpdated;
      evidence =
        map (disk: {
          disk = disk.id;
          path = "snapraid.content";
          kind = "content";
        })
        pool.disks
        ++ lib.imap0 (i: disk: {
          inherit disk;
          path = "snapraid.${toString i}.parity";
          kind = "parity";
        })
        pool.snapraid.parityDisks;
    });
  mover = name: pool:
    pkgs.writeShellApplication {
      name = "${name}-storage";
      runtimeInputs = [pkgs.python3 pkgs.util-linux];
      text = "exec python3 ${./mover.py} --config ${moverConfig name pool} \"$@\"";
    };
  command = name: pool: "${lib.getExe (mover name pool)}";
  poolMergerfsService = name: pool: {
    "${name}-storage-admission" = {
      description = "Validate all ${name} backing identities before exposing storage";
      requires = backingUnits pool ++ ["systemd-tmpfiles-setup.service"];
      bindsTo = backingUnits pool;
      after = backingUnits pool ++ ["systemd-tmpfiles-setup.service"];
      before = [(mountUnit pool.mergedPath)];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${command name pool} admit";
      };
    };
    # Retain the public commitment unit, but let the actual .mount own mounting.
    "${name}-mergerfs-mount" = {
      description = "${name} mounted and admitted";
      wantedBy = ["multi-user.target"];
      requires = [(mountUnit pool.mergedPath)];
      bindsTo = [(mountUnit pool.mergedPath)];
      after = [(mountUnit pool.mergedPath)];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/true";
      };
    };
  };

  poolTargets = name: pool: {
    "${name}-array" = {
      description = "${name} Array Storage Target";
      wantedBy = ["multi-user.target"];
      requires = ["${name}-storage-admission.service"];
      bindsTo = backingUnits pool;
      after = ["${name}-storage-admission.service"];
    };
    "${name}-merged" = {
      description = "${name} Merged View Target";
      wantedBy = ["multi-user.target"];
      after = ["${name}-mergerfs-mount.service"];
      requires = ["${name}-mergerfs-mount.service"];
      bindsTo = [(mountUnit pool.mergedPath)];
    };
  };

  poolTmpfiles = name: pool:
    [
      "d /var/lib/disk-array/${name} 0755 root root - -"
      "d /var/lib/disk-array/${name}/receipts 0700 root root - -"
      "d ${pool.mountBase} 0755 root root - -"
      "d ${pool.mergedPath} 0755 root root - -"
    ]
    ++ map (disk: "d ${diskMountPath pool disk} 0755 root root - -") pool.disks;

  # --- SnapRAID helpers ---
  poolSnapraidConf = name: pool: let
    sr = pool.snapraid;
  in ''
    ${concatStringsSep "\n" (imap0 (
        i: diskId: "data d${toString (i + 1)} ${pool.mountBase}/${diskId}"
      )
      sr.dataDisks)}

    ${concatStringsSep "\n" (imap0 (
        i: diskId: "${
          if i == 0
          then "parity"
          else "${toString (i + 1)}-parity"
        } ${pool.mountBase}/${diskId}/snapraid.${toString i}.parity"
      )
      sr.parityDisks)}

    content /var/lib/snapraid/${name}.content
    ${concatStringsSep "\n" (map (
        disk: "content ${diskMountPath pool disk}/snapraid.content"
      )
      pool.disks)}

    blocksize 256
    hashsize 16
    autosave 1000

    ${concatStringsSep "\n" (map (p: "exclude ${p}") sr.excludes)}

    nohidden
  '';

  poolSnapraidServices = name: pool:
    lib.genAttrs ["${name}-snapraid-sync" "${name}-snapraid-scrub"] (unit: {
      description = unit;
      requires = ["${name}-storage-admission.service"];
      bindsTo = backingUnits pool;
      after = ["${name}-storage-admission.service"];
      serviceConfig = {
        Type = "oneshot";
        Nice = 19;
        IOSchedulingClass = "idle";
        ExecStart = "${command name pool} ${
          if lib.hasSuffix "-sync" unit
          then "sync"
          else "scrub"
        }";
      };
    });

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
  poolCacheMoverService = name: pool: {
    "${name}-cache-mover" = {
      description = "Copy aged ${name} cache files; retain sources pending explicit protection/release";
      requires = ["${name}-storage-admission.service"];
      bindsTo = backingUnits pool;
      after = ["${name}-storage-admission.service"];
      serviceConfig = {
        Type = "oneshot";
        Nice = 19;
        IOSchedulingClass = "idle";
        ExecStart = "${command name pool} scheduled";
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
    map (
      rule: ''SUBSYSTEM=="usb", ATTRS{idVendor}=="${rule.vendor}", ATTRS{idProduct}=="${rule.product}", ATTR{power/autosuspend}="-1"''
    )
    pool.usb.udevRules;

  # --- Collect across all pools ---
  poolNames = builtins.attrNames cfg.pools;
  poolList = mapAttrsToList (name: pool: {inherit name pool;}) cfg.pools;

  # Array disks hold data that outlives any one host. A disko layout
  # formats every disk it lists, so an array disk must never appear in one.
  arrayDevices = concatMap (p: map (disk: disk.device) p.pool.disks) poolList;
  diskoDevices =
    if config ? disko
    then mapAttrsToList (_: disk: disk.device) (config.disko.devices.disk or {})
    else [];
  diskoArrayOverlap = builtins.filter (dev: builtins.elem dev arrayDevices) diskoDevices;
  anySnapraid = builtins.any (p: p.pool.snapraid.enable) poolList;
in {
  config = mkIf cfg.enable {
    assertions =
      (map (p: {
          assertion = !p.pool.cache.enable || (p.pool.cache.device != "" && p.pool.snapraid.enable && p.pool.snapraid.dataDisks == p.pool.mergerfs.dataDisks);
          message = "disk-array: a cache requires explicit cache identity and matching protected data branches";
        })
        poolList)
      ++ [
        {
          assertion = diskoArrayOverlap == [];
          message = "disk-array: disko would format array disk(s): ${concatStringsSep ", " diskoArrayOverlap}. Remove them from the disko layout.";
        }
      ];

    environment.systemPackages = with pkgs;
      [
        mergerfs
      ]
      ++ optional (builtins.any (p: p.pool.snapraid.enable) poolList) pkgs.snapraid
      ++ map (p: mover p.name p.pool) poolList;

    systemd.tmpfiles.rules =
      [
        "d /srv/shores 0755 root root - -"
        "d /srv/lakes 0755 root root - -"
      ]
      # SnapRAID keeps one content file in /var/lib/snapraid and refuses
      # to run when that folder is missing.
      ++ optional anySnapraid "d /var/lib/snapraid 0755 root root - -"
      ++ concatMap (p: poolTmpfiles p.name p.pool) poolList;

    fileSystems = mkMerge (
      (map (p: poolDiskFileSystems p.name p.pool) poolList)
      ++ (map (p: poolMergerfsFileSystem p.name p.pool) poolList)
    );

    systemd.services = mkMerge (
      (map (p: poolMergerfsService p.name p.pool) poolList)
      ++ (map (
          p:
            if p.pool.snapraid.enable
            then poolSnapraidServices p.name p.pool
            else {}
        )
        poolList)
      ++ (map (
          p:
            if p.pool.cache.enable
            then poolCacheMoverService p.name p.pool
            else {}
        )
        poolList)
    );

    # BindsTo belongs to the real mount, not only its historical helper.
    systemd.units = listToAttrs (map (p:
      nameValuePair (mountUnit p.pool.mergedPath) {
        overrideStrategy = "asDropin";
        text = "[Unit]\nBindsTo=${concatStringsSep " " (backingUnits p.pool ++ ["${p.name}-storage-admission.service"])}\n";
      })
    poolList);

    systemd.targets = mkMerge (map (p: poolTargets p.name p.pool) poolList);

    systemd.timers = mkMerge (
      (map (
          p:
            if p.pool.snapraid.enable
            then poolSnapraidTimers p.name p.pool
            else {}
        )
        poolList)
      ++ (map (
          p:
            if p.pool.cache.enable
            then poolCacheMoverTimer p.name p.pool
            else {}
        )
        poolList)
    );

    environment.etc = mkMerge (map (
        p:
          if p.pool.snapraid.enable
          then {"snapraid-${p.name}.conf".text = poolSnapraidConf p.name p.pool;}
          else {}
      )
      poolList);

    boot.kernelParams =
      optional (builtins.any (p: p.pool.usb.disableAutosuspend) poolList)
      "usbcore.autosuspend=-1";

    services.udev.extraRules =
      concatStringsSep "\n" (concatMap (p: poolUdevRules p.name p.pool) poolList);
  };
}
