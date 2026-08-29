{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatStringsSep mkIf mkMerge optionalString optionals;
  cfg = config.mountainous.features.media-tiering;
  mediaCfg = config.mountainous.features.media;

  localMoviesDir = "${cfg.localBackingRoot}/movies";
  localTvDir = "${cfg.localBackingRoot}/tv";
  peerMoviesDir = "${cfg.peerMountRoot}/movies";
  peerTvDir = "${cfg.peerMountRoot}/tv";
  rangeMoviesBranches = [localMoviesDir] ++ optionals (cfg.role == "source") [peerMoviesDir];
  rangeTvBranches = [localTvDir] ++ optionals (cfg.role == "source") [peerTvDir];

  # Both sides export and mount rw: the mover writes source→sink,
  # and Jellyfin on the sink needs to delete files on the source.
  exportMode = "rw";
  peerMountMode = "rw";
  peerNfsOptions = [
    peerMountMode
    "nfsvers=4.2"
    "soft"
    "timeo=50"
    "retrans=2"
    "noatime"
  ];
  sinkPeerMountOptions = concatStringsSep "," [
    peerMountMode
    "nfsvers=4.2"
    "soft"
    "timeo=10"
    "retrans=1"
    "noatime"
    "retry=0"
  ];

  mergerfsOptions = mountpoint: [
    "noauto"
    "x-systemd.automount=false"
    "allow_other"
    "use_ino"
    "cache.files=partial"
    "dropcacheonclose=true"
    "category.create=ff"
    "moveonenospc=true"
    "minfreespace=10G"
    "fsname=mergerfs-${builtins.replaceStrings ["/" "."] ["-" "-"] mountpoint}"
  ];

  mergerfsMount = name: mountpoint: branches: {
    fileSystems.${mountpoint} = {
      device = concatStringsSep ":" branches;
      fsType = "fuse.mergerfs";
      options = mergerfsOptions mountpoint;
    };

    systemd.services.${name} = {
      description = "Mount mergerfs view at ${mountpoint}";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"] ++ optionals (cfg.role == "source") ["media-tiering-source-migrate.service"];
      requires = optionals (cfg.role == "source") ["media-tiering-source-migrate.service"];
      path = with pkgs; [util-linux mount];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript name ''
          set -euo pipefail
          if mountpoint -q "${mountpoint}" 2>/dev/null; then
            echo "${mountpoint} already mounted"
            exit 0
          fi
          mount "${mountpoint}"
        '';
        ExecStop = pkgs.writeShellScript "${name}-umount" ''
          if mountpoint -q "${mountpoint}" 2>/dev/null; then
            umount "${mountpoint}" || true
          fi
        '';
      };
    };
  };

  peerMountScript = pkgs.writeShellScript "media-tiering-peer-mount" ''
    set -u

    set_branches() {
      local movies_branches="$1" tv_branches="$2" status=0

      if ! ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg mediaCfg.rangeMoviesDir}; then
        echo "movies range is not mounted" >&2
        status=1
      elif ! ${pkgs.attr}/bin/setfattr \
        -n user.mergerfs.branches \
        -v "$movies_branches" \
        ${lib.escapeShellArg "${mediaCfg.rangeMoviesDir}/.mergerfs"}; then
        echo "failed to update movies range branches" >&2
        status=1
      fi

      if ! ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg mediaCfg.rangeTvDir}; then
        echo "TV range is not mounted" >&2
        status=1
      elif ! ${pkgs.attr}/bin/setfattr \
        -n user.mergerfs.branches \
        -v "$tv_branches" \
        ${lib.escapeShellArg "${mediaCfg.rangeTvDir}/.mergerfs"}; then
        echo "failed to update TV range branches" >&2
        status=1
      fi

      return "$status"
    }

    local_only() {
      set_branches \
        ${lib.escapeShellArg localMoviesDir} \
        ${lib.escapeShellArg localTvDir}
    }

    local_and_peer() {
      set_branches \
        ${lib.escapeShellArg "${localMoviesDir}:${peerMoviesDir}"} \
        ${lib.escapeShellArg "${localTvDir}:${peerTvDir}"}
    }

    peer_is_healthy() {
      ${pkgs.coreutils}/bin/timeout --signal=TERM --kill-after=2s 5s \
        ${pkgs.coreutils}/bin/stat \
          ${lib.escapeShellArg peerMoviesDir} \
          ${lib.escapeShellArg peerTvDir} \
          >/dev/null 2>&1
    }

    if ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg cfg.peerMountRoot}; then
      if peer_is_healthy && local_and_peer; then
        exit 0
      fi

      local_only || true
      ${pkgs.util-linux}/bin/umount -l ${lib.escapeShellArg cfg.peerMountRoot} 2>/dev/null || true
      echo "removed unavailable peer media from the range views" >&2
    fi

    ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg cfg.peerMountRoot}
    mount_status=0
    if ${pkgs.coreutils}/bin/timeout --signal=TERM --kill-after=2s 10s \
      ${pkgs.util-linux}/bin/mount \
        -t nfs \
        -o ${lib.escapeShellArg sinkPeerMountOptions} \
        ${lib.escapeShellArg "${cfg.peerHost}:/"} \
        ${lib.escapeShellArg cfg.peerMountRoot}; then
      if local_and_peer; then
        echo "mounted peer media from ${cfg.peerHost}"
        exit 0
      fi
      mount_status=70
    else
      mount_status=$?
    fi

    local_only || true
    ${pkgs.util-linux}/bin/umount -l ${lib.escapeShellArg cfg.peerMountRoot} 2>/dev/null || true
    echo "peer media from ${cfg.peerHost} is unavailable; keeping local-only range views (mount status $mount_status)" >&2
    exit 0
  '';

  moverScript = pkgs.writeShellScript "media-tiering-mover" ''
        set -euo pipefail

        mode="''${1:-low-space}"
        case "$mode" in
          nightly|low-space) ;;
          *)
            echo "unknown mode: $mode" >&2
            exit 2
            ;;
        esac

        lock=/run/media-tiering-mover.lock
        exec 9>"$lock"
        if ! ${pkgs.util-linux}/bin/flock -n 9; then
          echo "media-tiering mover already running; skipping"
          exit 0
        fi

        SOURCE_ROOT=${lib.escapeShellArg cfg.localBackingRoot}
        DEST_ROOT=${lib.escapeShellArg cfg.peerMountRoot}
        MIN_AGE_MINUTES=${toString cfg.mover.minAgeMinutes}
        MIN_FREE_PERCENT=${toString cfg.mover.minFreePercent}
        mkdir -p /var/lib/media-tiering

        used_percent() {
          ${pkgs.coreutils}/bin/df --output=pcent "$SOURCE_ROOT" | tail -1 | tr -d ' %'
        }

        free_percent() {
          local used
          used=$(used_percent)
          echo $((100 - used))
        }

        low_space() {
          [ "$(free_percent)" -le "$MIN_FREE_PERCENT" ]
        }

        mountain_now() {
          TZ=America/Denver ${pkgs.coreutils}/bin/date "+%Y-%m-%d %H:%M:%S"
        }

        echo "media-tiering run starting at $(mountain_now)"
        echo "requested mode: $mode"
        echo "source free space before: $(free_percent)%"

        if [ "$mode" = "low-space" ] && ! low_space; then
          echo "free space above threshold; skipping low-space run"
          exit 0
        fi

        moved_files=0
        moved_bytes=0

        generate_candidates() {
          ${pkgs.python3}/bin/python3 - "$SOURCE_ROOT" "$MIN_AGE_MINUTES" <<'PY'
    import os
    import sys
    import time

    source_root = sys.argv[1]
    min_age_minutes = int(sys.argv[2])
    cutoff = time.time() - (min_age_minutes * 60)
    items = []
    for library in ("movies", "tv"):
        root = os.path.join(source_root, library)
        if not os.path.isdir(root):
            continue
        for dirpath, _, filenames in os.walk(root):
            for filename in filenames:
                path = os.path.join(dirpath, filename)
                try:
                    st = os.stat(path)
                except FileNotFoundError:
                    continue
                if st.st_mtime > cutoff:
                    continue
                items.append((st.st_mtime, path))
    items.sort()
    out = sys.stdout.buffer
    for _, path in items:
        out.write(path.encode())
        out.write(b"\0")
    PY
        }

        refresh_jellyfin() {
          ${optionalString (cfg.mover.jellyfin.passwordFile != null) ''
      local password response token payload
      password=$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg (toString cfg.mover.jellyfin.passwordFile)})
      case "$password" in *=*) password="$(printf '%s' "$password" | ${pkgs.coreutils}/bin/cut -d= -f2-)" ;; esac
      payload=$(${pkgs.jq}/bin/jq -nc \
        --arg username ${lib.escapeShellArg cfg.mover.jellyfin.username} \
        --arg pw "$password" \
        '{Username: $username, Pw: $pw}')
      response=$(${pkgs.curl}/bin/curl -sS -X POST "http://${cfg.mover.jellyfin.host}:8096/Users/AuthenticateByName" \
        -H 'Content-Type: application/json' \
        -H 'Authorization: MediaBrowser Client="mountainous", Device="mountainous", DeviceId="media-tiering", Version="1.0.0"' \
        -d "$payload" || true)
      token=$(printf '%s' "$response" | ${pkgs.jq}/bin/jq -r '.AccessToken // empty' 2>/dev/null || true)
      if [ -n "$token" ]; then
        ${pkgs.curl}/bin/curl -sS -X POST "http://${cfg.mover.jellyfin.host}:8096/Library/Refresh" -H "X-Emby-Token: $token" >/dev/null || true
        echo "queued Jellyfin refresh on ${cfg.mover.jellyfin.host}"
      else
        echo "warning: failed to refresh Jellyfin on ${cfg.mover.jellyfin.host}" >&2
        echo "$response" >&2
      fi
    ''}
        }

        move_one() {
          local src="$1"
          local rel dest dest_dir tmp size

          if ! [ -f "$src" ]; then
            return 0
          fi

          if ${pkgs.lsof}/bin/lsof "$src" >/dev/null 2>&1; then
            echo "skipping busy file: $src"
            return 0
          fi

          rel="''${src#$SOURCE_ROOT/}"
          dest="$DEST_ROOT/$rel"
          dest_dir=$(dirname "$dest")
          tmp="$dest.__tiering_tmp__.$$"
          size=$(${pkgs.coreutils}/bin/stat -c %s "$src")

          ${pkgs.coreutils}/bin/mkdir -p "$dest_dir"
          ${pkgs.coreutils}/bin/chgrp ${lib.escapeShellArg mediaCfg.group} "$dest_dir"
          ${pkgs.coreutils}/bin/chmod g+rws "$dest_dir"

          if [ -e "$dest" ]; then
            if ${pkgs.diffutils}/bin/cmp -s "$src" "$dest"; then
              ${pkgs.coreutils}/bin/rm -f "$src"
              moved_files=$((moved_files + 1))
              moved_bytes=$((moved_bytes + size))
              return 0
            fi
            echo "destination already exists with different content: $dest" >&2
            return 1
          fi

          ${pkgs.rsync}/bin/rsync -aHAXWES --preallocate "$src" "$tmp"
          ${pkgs.coreutils}/bin/chgrp ${lib.escapeShellArg mediaCfg.group} "$tmp"
          ${pkgs.coreutils}/bin/chmod g+rwX "$tmp"
          if ! ${pkgs.diffutils}/bin/cmp -s "$src" "$tmp"; then
            echo "verification failed for $src" >&2
            ${pkgs.coreutils}/bin/rm -f "$tmp"
            return 1
          fi

          ${pkgs.coreutils}/bin/mv "$tmp" "$dest"
          ${pkgs.coreutils}/bin/rm -f "$src"
          moved_files=$((moved_files + 1))
          moved_bytes=$((moved_bytes + size))
        }

        status=0
        while IFS= read -r -d $'\0' src; do
          if ! move_one "$src"; then
            status=1
            continue
          fi
          if [ "$mode" = "low-space" ] && ! low_space; then
            break
          fi
        done < <(generate_candidates)

        ${pkgs.findutils}/bin/find "$SOURCE_ROOT" -depth -type d -empty -delete 2>/dev/null || true

        echo "moved files: $moved_files"
        echo "moved bytes: $moved_bytes"
        echo "source free space after: $(free_percent)%"

        if [ "$moved_files" -gt 0 ]; then
          refresh_jellyfin
        fi

        exit "$status"
  '';
in {
  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = mediaCfg.enable;
          message = "mountainous.features.media-tiering requires mountainous.features.media.enable = true";
        }
        {
          assertion = mediaCfg.group == "media";
          message = ''
            mountainous.features.media-tiering relies on the shared `media`
            group identity from mountainous.features.media.gid instead of
            per-service UID parity across hosts.
          '';
        }
        {
          assertion = cfg.nfs.anonuid == 0;
          message = "mountainous.features.media-tiering requires nfs.anonuid = 0 to preserve the root:media all_squash ownership model";
        }
        {
          assertion = cfg.nfs.anongid == mediaCfg.gid;
          message = ''
            mountainous.features.media-tiering requires nfs.anongid to match
            mountainous.features.media.gid so files created over NFS land with
            the expected root:media ownership.
          '';
        }
      ];

      environment.systemPackages = [pkgs.mergerfs];

      systemd.tmpfiles.rules =
        [
          "d ${cfg.localBackingRoot} 2775 root media - -"
          "d ${localMoviesDir} 2775 root media - -"
          "d ${localTvDir} 2775 root media - -"
          "d ${mediaCfg.rangeRoot} 0755 root root - -"
          "d ${mediaCfg.rangeRoot}/media 0755 root root - -"
          "d ${mediaCfg.rangeMoviesDir} 2775 root media - -"
          "d ${mediaCfg.rangeTvDir} 2775 root media - -"
          "d /var/lib/media-tiering 0755 root root - -"
        ]
        ++ optionals (cfg.role == "source") [
          "d ${cfg.peerMountRoot} 0755 root root - -"
          "d ${peerMoviesDir} 0755 root root - -"
          "d ${peerTvDir} 0755 root root - -"
        ];

      services.nfs.server = {
        enable = true;
        exports = ''
          # Tiered media exports use all_squash with anonuid=0 and
          # anongid=${toString cfg.nfs.anongid} so new files arrive as root:media.
          ${cfg.localBackingRoot}  ${cfg.nfs.clients}(${exportMode},fsid=0,no_subtree_check,crossmnt,all_squash,anonuid=${toString cfg.nfs.anonuid},anongid=${toString cfg.nfs.anongid})
        '';
      };
    }

    (mkIf (cfg.role == "source") {
      fileSystems.${cfg.peerMountRoot} = {
        device = "${cfg.peerHost}:/";
        fsType = "nfs";
        options =
          peerNfsOptions
          ++ [
            "_netdev"
            "nofail"
            "x-systemd.automount"
            "x-systemd.idle-timeout=600"
            "x-systemd.mount-timeout=10s"
            "x-systemd.after=tailscaled.service"
            "x-systemd.requires=tailscaled.service"
          ];
      };
    })

    (mkIf (cfg.role == "sink") {
      systemd.services.media-tiering-peer-mount = {
        description = "Best-effort mount of peer media from ${cfg.peerHost}";
        after = ["tailscaled.service"];
        wants = ["tailscaled.service"];
        wantedBy = [];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = peerMountScript;
        };
      };

      systemd.timers.media-tiering-peer-mount = {
        description = "Retry the peer media mount outside host activation";
        wantedBy = ["timers.target"];
        timerConfig = {
          Unit = "media-tiering-peer-mount.service";
          OnActiveSec = "30s";
          OnUnitInactiveSec = "5min";
        };
      };
    })

    (mkIf (cfg.localSources.movies != null) {
      fileSystems.${localMoviesDir} = {
        device = cfg.localSources.movies;
        fsType = "none";
        options = ["bind"];
      };
    })

    (mkIf (cfg.localSources.tv != null) {
      fileSystems.${localTvDir} = {
        device = cfg.localSources.tv;
        fsType = "none";
        options = ["bind"];
      };
    })

    (mergerfsMount "media-tiering-movies-mount" mediaCfg.rangeMoviesDir rangeMoviesBranches)
    (mergerfsMount "media-tiering-tv-mount" mediaCfg.rangeTvDir rangeTvBranches)

    (mkIf (cfg.role == "source") {
      systemd.services.media-tiering-source-migrate = {
        description = "Migrate source media layout into local backing directories";
        wantedBy = ["multi-user.target"];
        before = ["media-tiering-movies-mount.service" "media-tiering-tv-mount.service"];
        after = ["local-fs.target"];
        path = with pkgs; [coreutils findutils rsync util-linux];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail
          stamp=/var/lib/media-tiering/source-migrated
          if [ -e "$stamp" ]; then
            exit 0
          fi

          migrate_one() {
            local canonical="$1" backing="$2"
            mkdir -p "$backing"
            if mountpoint -q "$canonical" 2>/dev/null; then
              return 0
            fi
            if [ -n "$(find "$canonical" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
              ${pkgs.rsync}/bin/rsync -aHAXWES --remove-source-files "$canonical/" "$backing/"
              ${pkgs.findutils}/bin/find "$canonical" -depth -type d -empty -delete 2>/dev/null || true
            fi
          }

          migrate_one ${lib.escapeShellArg mediaCfg.rangeMoviesDir} ${lib.escapeShellArg localMoviesDir}
          migrate_one ${lib.escapeShellArg mediaCfg.rangeTvDir} ${lib.escapeShellArg localTvDir}
          touch "$stamp"
        '';
      };

      systemd.services."media-tiering-mover@" = mkIf cfg.mover.enable {
        description = "Move aged media from local backing storage to peer backing storage (%i)";
        after = [
          "media-tiering-movies-mount.service"
          "media-tiering-tv-mount.service"
        ];
        requires = [
          "media-tiering-movies-mount.service"
          "media-tiering-tv-mount.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          Nice = 19;
          IOSchedulingClass = "idle";
          ExecStart = "${moverScript} %i";
        };
        path = with pkgs; [coreutils curl diffutils findutils gnugrep jq lsof python3 rsync util-linux];
      };

      systemd.timers.media-tiering-mover-nightly = mkIf cfg.mover.enable {
        description = "Nightly media tiering run";
        wantedBy = ["timers.target"];
        timerConfig = {
          Unit = "media-tiering-mover@nightly.service";
          OnCalendar = cfg.mover.nightlySchedule;
          Persistent = true;
        };
      };

      systemd.timers.media-tiering-mover-low-space = mkIf cfg.mover.enable {
        description = "Frequent low-space media tiering checks";
        wantedBy = ["timers.target"];
        timerConfig = {
          Unit = "media-tiering-mover@low-space.service";
          OnBootSec = cfg.mover.lowSpaceCheckInterval;
          OnUnitActiveSec = cfg.mover.lowSpaceCheckInterval;
          Persistent = true;
          RandomizedDelaySec = "30s";
        };
      };
    })
  ]);
}
