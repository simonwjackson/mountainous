{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) attrByPath concatMapStringsSep escapeShellArg mapAttrs mapAttrsToList mkOption types;

  get = path: default: attrByPath path default config;
  enabled = path: get path false;
  hasSecret = name: builtins.hasAttr name config.age.secrets;
  hasService = name: builtins.hasAttr name config.systemd.services;

  commitments = {
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

    lockout-safety = {
      assertion =
        enabled ["mountainous" "features" "memory-guard" "enable"]
        && enabled ["mountainous" "features" "memory-guard" "userSlices"]
        && config.systemd.oomd.enableSystemSlice
        && config.systemd.oomd.enableUserSlices;
      message = "Zao must keep the memory guard, with systemd-oomd on system.slice and the user slices.";
    };
  };

  runtimeVerifier = pkgs.writeShellApplication {
    name = "zao-verify-commitments";
    runtimeInputs = with pkgs; [
      coreutils
      cups
      curl
      findutils # The zram check calls xargs, also in a clean supervisor environment.
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

      check_lockout_safety() {
        if ! oomctl 2>/dev/null | grep --fixed-strings --quiet /system.slice; then
          add_failure "systemd-oomd does not watch system.slice"
        fi
        if ! oomctl 2>/dev/null | grep --fixed-strings --quiet /user.slice; then
          add_failure "systemd-oomd does not watch the user slices"
        fi
        if [ "$(systemctl show sshd.service --property MemoryMin --value)" != 67108864 ]; then
          add_failure "sshd has no 64M memory reserve"
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

      run_commitment shared-office-printer check_shared_office_printer
      run_commitment tailnet-access check_tailnet_access
      run_commitment eval-memory-safety check_eval_memory_safety
      run_commitment lockout-safety check_lockout_safety

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
