{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) attrByPath concatMapStringsSep escapeShellArg mapAttrs mapAttrsToList mkOption types;

  get = path: default: attrByPath path default config;
  enabled = path: get path false;
  hasSecret = name: builtins.hasAttr name config.age.secrets;
  hasService = name: builtins.hasAttr name config.systemd.services;

  towadaDisks = get ["mountainous" "features" "disk-array" "pools" "towada" "disks"] [];
  towadaDiskIds = map (disk: disk.id) towadaDisks;
  towadaMountBase = get ["mountainous" "features" "disk-array" "pools" "towada" "mountBase"] "/srv/shores/towada";
  towadaMountChecks =
    concatMapStringsSep "\n" (disk: ''
      expect_mount_device ${escapeShellArg "${towadaMountBase}/${disk.id}"} ${escapeShellArg "${disk.device}-part${disk.partition}"}
    '')
    towadaDisks;
  jellyfinLibraries = get ["mountainous" "features" "jellyfin" "bootstrap" "libraries"] {};
  localMediaRoot = get ["mountainous" "features" "media-tiering" "localBackingRoot"] "/srv/lakes/towada/media";
  rangeMoviesDir = get ["mountainous" "features" "media" "rangeMoviesDir"] "/srv/range/media/movies";
  rangeTvDir = get ["mountainous" "features" "media" "rangeTvDir"] "/srv/range/media/tv";

  commitments = {
    towada-storage = {
      assertion =
        enabled ["mountainous" "features" "disk-array" "enable"]
        && towadaDiskIds == ["00" "01" "02" "03" "04"]
        && enabled ["mountainous" "features" "disk-array" "pools" "towada" "cache" "enable"]
        && get ["mountainous" "features" "disk-array" "pools" "towada" "mergerfs" "dataDisks"] [] == ["00" "01" "04"]
        && enabled ["mountainous" "features" "disk-array" "pools" "towada" "snapraid" "enable"]
        && get ["mountainous" "features" "disk-array" "pools" "towada" "snapraid" "dataDisks"] [] == ["00" "01" "04"]
        && get ["mountainous" "features" "disk-array" "pools" "towada" "snapraid" "parityDisks"] [] == ["02" "03"]
        && enabled ["mountainous" "features" "disk-array" "pools" "towada" "usb" "disableAutosuspend"];
      message = "Towada must retain its five-disk mergerfs, cache, and SnapRAID layout.";
    };

    media-tiering-sink = {
      assertion =
        enabled ["mountainous" "features" "media" "enable"]
        && get ["mountainous" "features" "media" "root"] null == "/srv/lakes/towada"
        && enabled ["mountainous" "features" "media-tiering" "enable"]
        && get ["mountainous" "features" "media-tiering" "role"] null == "sink"
        && get ["mountainous" "features" "media-tiering" "peerHost"] null == "yari";
      message = "Zao must remain the Towada media-tiering sink for Yari.";
    };

    jellyfin-media-server = {
      assertion =
        enabled ["mountainous" "features" "jellyfin" "enable"]
        && enabled ["mountainous" "features" "jellyfin" "openFirewall"]
        && enabled ["mountainous" "features" "jellyfin" "bootstrap" "enable"]
        && enabled ["mountainous" "features" "jellyfin" "bootstrap" "remoteAccess"]
        && enabled ["mountainous" "features" "jellyfin" "proxy" "enable"]
        && get ["mountainous" "features" "jellyfin" "proxy" "hostname"] null == "watch"
        && enabled ["services" "jellyfin" "enable"]
        && attrByPath ["tv" "path"] null jellyfinLibraries == "/srv/range/media/tv"
        && attrByPath ["movies" "path"] null jellyfinLibraries == "/srv/range/media/movies"
        && hasSecret "jellyfin-pass";
      message = "Zao must retain Jellyfin with its TV and movie libraries and admin secret.";
    };

    shared-office-printer = {
      assertion =
        enabled ["services" "printing" "enable"]
        && enabled ["services" "printing" "openFirewall"]
        && hasService "ensure-office-printer"
        && builtins.elem "multi-user.target" (get ["systemd" "services" "ensure-office-printer" "wantedBy"] [])
        && enabled ["services" "avahi" "enable"]
        && enabled ["services" "avahi" "publish" "userServices"];
      message = "Zao must retain the shared Office Printer queue and Avahi publication.";
    };

    tailnet-access = {
      assertion =
        enabled ["mountainous" "features" "tailscale" "enable"]
        && enabled ["mountainous" "features" "tsnet-proxy" "enable"]
        && hasSecret "tailscale-authkey"
        && builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces;
      message = "Zao must retain tsnet-proxy, its Tailscale secret, and trusted tailnet access.";
    };

    eval-memory-safety = {
      assertion =
        enabled ["zramSwap" "enable"]
        && get ["zramSwap" "algorithm"] null == "zstd"
        && get ["zramSwap" "memoryPercent"] null == 50;
      message = "Zao must retain its zstd zram configuration for Nix evaluation memory pressure.";
    };
  };

  runtimeVerifier = pkgs.writeShellApplication {
    name = "zao-verify-commitments";
    runtimeInputs = with pkgs; [
      attr
      coreutils
      cups
      curl
      gnugrep
      iproute2
      jq
      systemd
      tailscale
      util-linux
    ];
    text = ''
      set -uo pipefail

      declare -a reasons=()
      failed=0
      passed=0
      range_movies_dir="${rangeMoviesDir}"
      range_tv_dir="${rangeTvDir}"
      local_movies_branch="${localMediaRoot}/movies"
      local_tv_branch="${localMediaRoot}/tv"

      add_failure() {
        reasons+=("$1")
      }

      expect_active() {
        local unit="$1"
        if ! systemctl is-active --quiet "$unit"; then
          add_failure "$unit is not active"
        fi
      }

      expect_timer() {
        local unit="$1"
        expect_active "$unit"
        if ! systemctl is-enabled --quiet "$unit"; then
          add_failure "$unit is not enabled"
        fi
      }

      expect_mount_type() {
        local path="$1"
        local fs_type="$2"
        if ! findmnt --noheadings --raw --target "$path" --types "$fs_type" >/dev/null 2>&1; then
          add_failure "$path is not mounted as $fs_type"
        fi
      }

      expect_mount_device() {
        local path="$1"
        local expected="$2"
        local mounted_source
        local mounted_device
        local expected_device
        mounted_source="$(findmnt --noheadings --raw --mountpoint "$path" --output SOURCE 2>/dev/null | head --lines=1 || true)"
        mounted_device="$(readlink --canonicalize-existing "$mounted_source" 2>/dev/null || true)"
        expected_device="$(readlink --canonicalize-existing "$expected" 2>/dev/null || true)"
        if [ -z "$mounted_device" ] || [ "$mounted_device" != "$expected_device" ]; then
          add_failure "$path uses ''${mounted_source:-no device}, expected $expected"
        fi
      }

      expect_mergerfs_branch() {
        local view="$1"
        local branch="$2"
        local branches
        branches="$(getfattr --name=user.mergerfs.branches --only-values "$view/.mergerfs" 2>/dev/null || true)"
        if ! printf '%s' "$branches" | grep --fixed-strings --quiet "$branch=RW"; then
          add_failure "$view does not retain local branch $branch"
        fi
      }

      check_towada_storage() {
        local disk
        for disk in 00 01 02 03 04; do
          expect_mount_type "/srv/shores/towada/$disk" xfs
        done
        ${towadaMountChecks}
        expect_mount_type /srv/lakes/towada fuse.mergerfs
        expect_active towada-mergerfs-mount.service
        expect_active towada-array.target
        expect_active towada-merged.target
        expect_timer towada-snapraid-sync.timer
        expect_timer towada-snapraid-scrub.timer
        expect_timer towada-cache-mover.timer
      }

      check_media_tiering_sink() {
        expect_mount_type "$range_tv_dir" fuse.mergerfs
        expect_mount_type "$range_movies_dir" fuse.mergerfs
        expect_mergerfs_branch "$range_tv_dir" "$local_tv_branch"
        expect_mergerfs_branch "$range_movies_dir" "$local_movies_branch"
        expect_active media-tiering-tv-mount.service
        expect_active media-tiering-movies-mount.service
        expect_timer media-tiering-peer-mount.timer
      }

      check_jellyfin_media_server() {
        expect_active jellyfin.service
        expect_active jellyfin-seed-bootstrap.service
        expect_active tsnet-proxy-jellyfin.service
        if ! curl --fail --silent --show-error --max-time 5 http://127.0.0.1:8096/health | grep --fixed-strings --line-regexp --quiet Healthy; then
          add_failure "Jellyfin health endpoint is not healthy"
        fi
      }

      check_shared_office_printer() {
        expect_active cups.service
        expect_active ensure-office-printer.service
        expect_active avahi-daemon.service

        if ! lpstat -r >/dev/null 2>&1; then
          add_failure "CUPS scheduler is unavailable"
        fi
        printer_status="$(lpstat -p Office_Printer 2>/dev/null || true)"
        if ! printf '%s\n' "$printer_status" | grep --fixed-strings --quiet 'printer Office_Printer'; then
          add_failure "Office_Printer queue is unavailable"
        elif printf '%s\n' "$printer_status" | grep --fixed-strings --quiet ' disabled '; then
          add_failure "Office_Printer queue is disabled"
        fi
        if ! lpstat -d 2>/dev/null | grep --fixed-strings --quiet 'Office_Printer'; then
          add_failure "Office_Printer is not the default queue"
        fi
      }

      check_tailnet_access() {
        expect_active tailscaled.service
        expect_active tsnet-proxy-jellyfin.service

        if ! ip link show tailscale0 >/dev/null 2>&1; then
          add_failure "tailscale0 is unavailable"
        fi
        if ! tailscale status --json 2>/dev/null | jq --exit-status '.BackendState == "Running"' >/dev/null; then
          add_failure "Tailscale backend is not running"
        fi
      }

      check_eval_memory_safety() {
        if ! swapon --show=NAME --noheadings | grep --fixed-strings --line-regexp --quiet /dev/zram0; then
          add_failure "/dev/zram0 is not active swap"
        fi
        algorithm="$(zramctl --noheadings --output ALGORITHM /dev/zram0 2>/dev/null | xargs || true)"
        if [ "$algorithm" != zstd ]; then
          add_failure "/dev/zram0 uses ''${algorithm:-no algorithm}, not zstd"
        fi
      }

      run_commitment() {
        local name="$1"
        local check_function="$2"
        reasons=()
        "$check_function"

        if [ "''${#reasons[@]}" -eq 0 ]; then
          printf 'PASS %s\n' "$name"
          passed=$((passed + 1))
          return
        fi

        printf 'FAIL %s\n' "$name"
        printf '  - %s\n' "''${reasons[@]}"
        failed=$((failed + 1))
      }

      run_commitment towada-storage check_towada_storage
      run_commitment media-tiering-sink check_media_tiering_sink
      run_commitment jellyfin-media-server check_jellyfin_media_server
      run_commitment shared-office-printer check_shared_office_printer
      run_commitment tailnet-access check_tailnet_access
      run_commitment eval-memory-safety check_eval_memory_safety

      printf '\n%d passed, %d failed\n' "$passed" "$failed"
      [ "$failed" -eq 0 ]
    '';
  };
in {
  options.mountainous.hosts.zao = {
    commitments = mkOption {
      type = types.attrsOf types.bool;
      readOnly = true;
      description = "Named operational commitments that every Zao configuration must preserve.";
    };

    runtimeVerifier = mkOption {
      type = types.package;
      readOnly = true;
      description = "Command that verifies Zao's operational commitments against the live host.";
    };
  };

  config = {
    mountainous.hosts.zao = {
      commitments = mapAttrs (_: commitment: commitment.assertion) commitments;
      inherit runtimeVerifier;
    };

    environment.systemPackages = [runtimeVerifier];

    systemd.services.zao-retire-korri = {
      description = "Retire loaded Korri user services from Zao";
      after = ["systemd-user-sessions.service"];
      wantedBy = ["multi-user.target"];
      path = with pkgs; [coreutils systemd];
      serviceConfig = {
        Type = "oneshot";
        User = "simonwjackson";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail

        runtime_uid="$(id --user)"
        export XDG_RUNTIME_DIR="/run/user/$runtime_uid"
        user_manager="$XDG_RUNTIME_DIR/systemd/private"
        legacy_sunshine=/home/simonwjackson/.config/systemd/user/sunshine.service
        sunshine_backup="$legacy_sunshine.mountainous-retired"
        sunshine_wants=/home/simonwjackson/.config/systemd/user/default.target.wants/sunshine.service

        if [ -S "$user_manager" ]; then
          systemctl --user stop korri-session.target || true
          systemctl --user stop \
            pipewire.socket \
            pipewire-pulse.socket \
            gamemoded.service \
            pipewire.service \
            pipewire-pulse.service \
            wireplumber.service \
            korrid.service \
            korri-compositor.service \
            korri-sunshine.service \
            sunshine.service || true
          systemctl --user disable \
            pipewire.socket \
            pipewire-pulse.socket \
            gamemoded.service \
            pipewire.service \
            pipewire-pulse.service \
            wireplumber.service \
            korrid.service \
            korri-compositor.service \
            korri-sunshine.service \
            sunshine.service || true
        fi

        if [ -f "$legacy_sunshine" ]; then
          mv --backup=numbered "$legacy_sunshine" "$sunshine_backup"
        fi
        if [ -L "$sunshine_wants" ]; then
          rm --force "$sunshine_wants"
        fi

        if [ -S "$user_manager" ]; then
          systemctl --user daemon-reload || true
          systemctl --user reset-failed || true
        fi
      '';
    };

    assertions =
      mapAttrsToList (name: commitment: {
        inherit (commitment) assertion;
        message = "Zao commitment '${name}' is not satisfied. ${commitment.message}";
      })
      commitments;
  };
}
