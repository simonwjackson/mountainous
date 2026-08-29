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

  runtimeUser = get ["services" "korri" "runtime" "user"] "simonwjackson";
  korriPort = get ["services" "korri" "daemon" "port"] 39217;
  localMediaRoot = get ["mountainous" "features" "media-tiering" "localBackingRoot"] "/srv/lakes/towada/media";
  rangeMoviesDir = get ["mountainous" "features" "media" "rangeMoviesDir"] "/srv/range/media/movies";
  rangeTvDir = get ["mountainous" "features" "media" "rangeTvDir"] "/srv/range/media/tv";
  korridExecStart = get ["systemd" "user" "services" "korrid" "serviceConfig" "ExecStart"] "";
  legacyKorridUnit = ''
    [Unit]
    Description=Korri native host daemon
    After=network-online.target
    Wants=network-online.target

    [Service]
    Environment=KORRID_MODE=host
    Environment=KORRID_ADDRESS=0.0.0.0:43117
    Environment=KORRID_HOST_CONFIG=%h/.config/korrid/host.toml
    Environment=KORRID_STORAGE_ROOT=%h/.local/share/korri
    ExecStart=%h/.local/state/korrid/current/bin/korrid
    Restart=on-failure
    RestartSec=2s

    [Install]
    WantedBy=default.target
  '';
  legacyKorridUnitHash = builtins.hashString "sha256" legacyKorridUnit;

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

    korri-stream-source = {
      assertion =
        enabled ["services" "korri" "daemon" "enable"]
        && enabled ["services" "korri" "daemon" "openFirewall"]
        && builtins.elem "tailscale0" (get ["services" "korri" "daemon" "firewallInterfaces"] [])
        && enabled ["services" "korri" "daemon" "streamControl" "enable"]
        && enabled ["services" "korri" "daemon" "streaming" "enable"]
        && enabled ["services" "korri" "compositor" "enable"]
        && enabled ["services" "sunshine" "enable"]
        && enabled ["services" "sunshine" "openFirewall"];
      message = "Zao must retain the Korri daemon, compositor, stream control, and Sunshine source.";
    };

    korri-runtime = {
      assertion =
        enabled ["programs" "sway" "enable"]
        && enabled ["programs" "sway" "xwayland" "enable"]
        && enabled ["programs" "steam" "enable"]
        && enabled ["programs" "gamemode" "enable"]
        && enabled ["services" "seatd" "enable"]
        && enabled ["services" "pipewire" "enable"]
        && enabled ["services" "pipewire" "wireplumber" "enable"]
        && enabled ["hardware" "graphics" "enable"]
        && enabled ["hardware" "graphics" "enable32Bit"]
        && enabled ["services" "korri" "input" "provider" "enable"]
        && builtins.elem "uinput" config.boot.kernelModules;
      message = "Zao must retain the graphics, audio, input, and gaming runtime required by Korri.";
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
      kmod
      systemd
      tailscale
      util-linux
    ];
    text = ''
      set -uo pipefail

      declare -a reasons=()
      failed=0
      passed=0
      runtime_user="${runtimeUser}"
      korri_port="${toString korriPort}"
      range_movies_dir="${rangeMoviesDir}"
      range_tv_dir="${rangeTvDir}"
      local_movies_branch="${localMediaRoot}/movies"
      local_tv_branch="${localMediaRoot}/tv"
      committed_korrid_exec="${korridExecStart}"

      if [ "$(id --user --name)" = "$runtime_user" ]; then
        runtime_uid="$(id --user)"
        export XDG_RUNTIME_DIR="/run/user/$runtime_uid"
        user_systemctl() {
          systemctl --user "$@"
        }
      elif [ "$EUID" -eq 0 ]; then
        runtime_uid="$(id --user "$runtime_user")"
        user_systemctl() {
          runuser --user "$runtime_user" -- \
            env XDG_RUNTIME_DIR="/run/user/$runtime_uid" systemctl --user "$@"
        }
      else
        echo "zao-verify-commitments must run as $runtime_user or root" >&2
        exit 2
      fi

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

      expect_system_binary() {
        local name="$1"
        if [ ! -x "/run/current-system/sw/bin/$name" ]; then
          add_failure "$name is absent from the current system"
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

      expect_nixos_user_unit() {
        local unit="$1"
        local fragment
        local resolved
        local current
        fragment="$(user_systemctl show "$unit" --property FragmentPath --value 2>/dev/null || true)"
        resolved="$(readlink --canonicalize-existing "$fragment" 2>/dev/null || true)"
        current="$(readlink --canonicalize-existing "/etc/systemd/user/$unit" 2>/dev/null || true)"
        case "$current" in
          /nix/store/*) ;;
          "") add_failure "$unit is absent from the current NixOS generation"; return ;;
          *) add_failure "$unit has an unexpected current target: $current"; return ;;
        esac
        if [ "$resolved" != "$current" ]; then
          add_failure "$unit has stale or shadowed loaded state: $fragment"
        fi
      }

      expect_user_unit_enabled() {
        local unit="$1"
        if ! user_systemctl is-enabled --quiet "$unit"; then
          add_failure "$unit is not enabled"
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

      check_korri_stream_source() {
        expect_nixos_user_unit korrid.service
        expect_nixos_user_unit korri-compositor.service
        expect_nixos_user_unit korri-sunshine.service

        expect_user_unit_enabled korrid.service
        expect_user_unit_enabled korri-compositor.service
        expect_user_unit_enabled korri-sunshine.service
        effective_environment="$(user_systemctl show korrid.service --property Environment --value 2>/dev/null || true)"
        if ! printf '%s\n' "$effective_environment" \
          | grep --extended-regexp --quiet '(^|[[:space:]])"?PORT=${toString korriPort}"?([[:space:]]|$)'; then
          add_failure "korrid.service does not use configured port $korri_port"
        fi

        if ! user_systemctl is-active --quiet korrid.service; then
          return
        fi

        main_pid="$(user_systemctl show korrid.service --property MainPID --value 2>/dev/null || true)"
        executable="$(readlink "/proc/$main_pid/exe" 2>/dev/null || true)"
        exec_start="$(user_systemctl show korrid.service --property ExecStart --value 2>/dev/null || true)"
        expected_executable="''${exec_start#*path=}"
        expected_executable="''${expected_executable%% ;*}"
        if [ "$expected_executable" != "$committed_korrid_exec" ]; then
          add_failure "korrid.service effective command is $expected_executable, expected $committed_korrid_exec"
        fi
        expected_package="''${committed_korrid_exec%/bin/*}"
        if ! tr '\0' '\n' < "/proc/$main_pid/environ" | grep --fixed-strings --line-regexp --quiet "PORT=$korri_port"; then
          add_failure "active korrid process does not use port $korri_port"
        fi
        if ! tr '\0' '\n' < "/proc/$main_pid/cmdline" | grep --fixed-strings --quiet "$expected_package/"; then
          add_failure "active korrid process is not from current package $expected_package"
        fi
        case "$executable" in
          /nix/store/*) ;;
          *) add_failure "active korrid process is outside the Nix store: ''${executable:-unknown}" ;;
        esac
        if ! ss --no-header --listening --numeric --processes --tcp "sport = :$korri_port" \
          | grep --fixed-strings --quiet "pid=$main_pid,"; then
          add_failure "active korrid process is not listening on port $korri_port"
        fi
      }

      check_korri_runtime() {
        expect_active seatd.service
        expect_nixos_user_unit pipewire.service
        expect_nixos_user_unit pipewire-pulse.service
        expect_nixos_user_unit wireplumber.service
        expect_user_unit_enabled wireplumber.service
        expect_system_binary sway
        expect_system_binary steam
        expect_system_binary gamemoderun

        if [ ! -c /dev/uinput ]; then
          add_failure "/dev/uinput is unavailable"
        fi
        if ! grep --quiet '^uinput ' /proc/modules; then
          add_failure "uinput kernel module is not loaded"
        fi
        if ! ls /dev/dri/renderD* >/dev/null 2>&1; then
          add_failure "no DRM render device is available"
        fi
        if [ ! -e /run/opengl-driver-32/lib/libGLX_nvidia.so.0 ]; then
          add_failure "32-bit NVIDIA graphics runtime is unavailable"
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
      run_commitment korri-stream-source check_korri_stream_source
      run_commitment korri-runtime check_korri_runtime
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

    systemd.services.zao-korrid-unit-refresh = {
      description = "Select the NixOS-generated Zao korrid user unit";
      after = ["systemd-user-sessions.service"];
      wantedBy = ["multi-user.target"];
      path = with pkgs; [coreutils gnugrep systemd];
      serviceConfig = {
        Type = "oneshot";
        User = runtimeUser;
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail

        legacy_unit=/home/${runtimeUser}/.config/systemd/user/korrid.service
        legacy_backup="$legacy_unit.mountainous-legacy"
        legacy_wants=/home/${runtimeUser}/.config/systemd/user/default.target.wants/korrid.service
        legacy_hash=${legacyKorridUnitHash}

        if [ -f "$legacy_unit" ]; then
          current_hash="$(sha256sum "$legacy_unit" | cut --delimiter=' ' --fields=1)"
          if [ "$current_hash" = "$legacy_hash" ]; then
            mv --backup=numbered "$legacy_unit" "$legacy_backup"
            if [ -L "$legacy_wants" ] \
              && [ "$(readlink "$legacy_wants")" = "$legacy_unit" ]; then
              rm --force "$legacy_wants"
            fi
          else
            echo "warning: refusing to move unrecognized user-managed korrid.service" >&2
          fi
        fi

        runtime_uid="$(id --user)"
        export XDG_RUNTIME_DIR="/run/user/$runtime_uid"
        if [ ! -S "$XDG_RUNTIME_DIR/systemd/private" ]; then
          exit 0
        fi

        was_active=0
        if systemctl --user is-active --quiet korrid.service; then
          was_active=1
        fi

        systemctl --user daemon-reload
        if [ "$was_active" -eq 1 ]; then
          systemctl --user restart korrid.service
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
