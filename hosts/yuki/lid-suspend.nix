# Lid-close suspend grace period for yuki.
#
# When the lid closes (whether docked or not), yuki waits 5 minutes before
# suspending. Opening the lid or re-docking during that window cancels the
# pending suspend. This replaces logind's default immediate-suspend behavior.
#
# Two paths trigger the buffered suspend:
# - yuki-lid-state-watch: polls lid state; handles "close lid while undocked"
# - yuki-undock-suspend: called by HyprDynamicMonitors; handles "close lid
#   while docked, then undock"
#
# Both share a generation counter in a state file so that any state change
# (lid open, re-dock) invalidates stale suspend timers.
{
  lib,
  pkgs,
  ...
}: let
  display = import ./display-lib.nix {inherit pkgs lib;};

  gracePeriodSeconds = 300; # 5 minutes

  yukiLidStateWatchScript = pkgs.writeShellScript "yuki-lid-state-watch" ''
    set -eu

    runtimeDir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    stateDir="$runtimeDir/yuki-hyprdynamicmonitors"
    stateFile="$stateDir/undock-state"
    lockFile="$stateDir/undock-state.lock"
    pollIntervalSeconds="1"
    suspendBufferSeconds="${toString gracePeriodSeconds}"

    mkdir -p "$stateDir"
    exec 9>"$lockFile"

    current_dp_count() {
      ${pkgs.hyprland}/bin/hyprctl --instance 0 monitors all 2>/dev/null | ${pkgs.gnugrep}/bin/grep -c '^Monitor DP-' || true
    }

    current_lid_state() {
      ${pkgs.systemd}/bin/busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower LidIsClosed 2>/dev/null | ${pkgs.gawk}/bin/awk '{ print $2 }' || printf 'false\n'
    }

    internal_panels_enabled() {
      ${pkgs.hyprland}/bin/hyprctl --instance 0 monitors 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^Monitor eDP-'
    }

    while :; do
      ${pkgs.util-linux}/bin/flock -x 9

      prevProfile=""
      prevDpCount="0"
      prevLidClosed="false"
      undockGeneration="0"
      if [ -f "$stateFile" ]; then
        . "$stateFile"
      fi
      prevLidClosed="''${prevLidClosed:-false}"
      undockGeneration="''${undockGeneration:-0}"

      dpCount=$(current_dp_count)
      lidClosed=$(current_lid_state)
      shouldRestoreUndockedDisplays="0"
      shouldStopInhibitor="0"
      shouldScheduleSuspend="0"
      scheduledSuspendGeneration="0"

      if [ "$dpCount" -gt 0 ]; then
        ${pkgs.systemd}/bin/systemctl --user start yuki-docked-lid-inhibitor.service >/dev/null 2>&1 || true
      fi

      if [ "$lidClosed" = "true" ] && internal_panels_enabled; then
        ${pkgs.util-linux}/bin/logger -t yuki-lid-state-watch \
          "lid closed; disabling internal displays dpCount=$dpCount"
        ${display.yukiDisableInternalDisplaysScript}
      fi

      # Lid closed while not docked → schedule buffered suspend
      if [ "$prevLidClosed" != "true" ] && [ "$lidClosed" = "true" ] && [ "$dpCount" -eq 0 ]; then
        shouldScheduleSuspend="1"
        scheduledSuspendGeneration=$((undockGeneration + 1))
        undockGeneration="$scheduledSuspendGeneration"
        ${pkgs.util-linux}/bin/logger -t yuki-lid-state-watch \
          "lid closed while undocked; scheduling suspend-then-hibernate in $suspendBufferSeconds seconds generation=$scheduledSuspendGeneration"
      fi

      if [ "$prevLidClosed" = "true" ] && [ "$lidClosed" != "true" ]; then
        undockGeneration=$((undockGeneration + 1))
        shouldRestoreUndockedDisplays="1"
        if [ "$dpCount" -eq 0 ]; then
          shouldStopInhibitor="1"
        fi
        ${pkgs.util-linux}/bin/logger -t yuki-lid-state-watch \
          "lid opened; cancelling buffered suspend generation=$undockGeneration dpCount=$dpCount"
      elif [ "$lidClosed" != "true" ] && [ "$dpCount" -eq 0 ] && ! internal_panels_enabled; then
        shouldRestoreUndockedDisplays="1"
        shouldStopInhibitor="1"
        ${pkgs.util-linux}/bin/logger -t yuki-lid-state-watch \
          "undocked with lid open and internal displays off; restoring internal layout"
      elif [ "$lidClosed" != "true" ] && [ "$dpCount" -eq 0 ]; then
        shouldStopInhibitor="1"
      fi

      printf 'prevProfile=%q\n' "$prevProfile" > "$stateFile"
      printf 'prevDpCount=%q\n' "$prevDpCount" >> "$stateFile"
      printf 'prevLidClosed=%q\n' "$lidClosed" >> "$stateFile"
      printf 'undockGeneration=%q\n' "$undockGeneration" >> "$stateFile"

      ${pkgs.util-linux}/bin/flock -u 9

      if [ "$shouldStopInhibitor" = "1" ]; then
        ${pkgs.systemd}/bin/systemctl --user stop yuki-docked-lid-inhibitor.service >/dev/null 2>&1 || true
      fi

      if [ "$shouldRestoreUndockedDisplays" = "1" ]; then
        ${display.yukiRestoreUndockedDisplaysScript}
      fi

      if [ "$shouldScheduleSuspend" = "1" ]; then
        (
          ${pkgs.coreutils}/bin/sleep "$suspendBufferSeconds"

          currentUndockGeneration="0"
          if [ -f "$stateFile" ]; then
            . "$stateFile"
          fi
          currentUndockGeneration="''${undockGeneration:-0}"
          lidClosedAfter=$(current_lid_state)
          dpCountAfter=$(current_dp_count)

          if [ "$currentUndockGeneration" != "$scheduledSuspendGeneration" ]; then
            ${pkgs.util-linux}/bin/logger -t yuki-lid-state-watch \
              "skipping stale lid-close suspend generation=$scheduledSuspendGeneration currentGeneration=$currentUndockGeneration"
            exit 0
          fi

          if [ "$lidClosedAfter" != "true" ] || [ "$dpCountAfter" -ne 0 ]; then
            ${pkgs.util-linux}/bin/logger -t yuki-lid-state-watch \
              "cancelling lid-close suspend generation=$scheduledSuspendGeneration lidClosed=$lidClosedAfter dpCount=$dpCountAfter"
            exit 0
          fi

          ${pkgs.util-linux}/bin/logger -t yuki-lid-state-watch \
            "lid-close buffer elapsed; running suspend-then-hibernate generation=$scheduledSuspendGeneration"
          ${pkgs.systemd}/bin/systemctl suspend-then-hibernate
        ) >/dev/null 2>&1 &
      fi

      ${pkgs.coreutils}/bin/sleep "$pollIntervalSeconds"
    done
  '';

  yukiUndockSuspendScript = pkgs.writeShellScript "yuki-undock-suspend" ''
    set -eu

    profile="''${1:?usage: yuki-undock-suspend <profile-name>}"
    runtimeDir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    stateDir="$runtimeDir/yuki-hyprdynamicmonitors"
    stateFile="$stateDir/undock-state"
    lockFile="$stateDir/undock-state.lock"
    dryRun="''${YUKI_UNDOCK_SUSPEND_DRY_RUN:-0}"

    mkdir -p "$stateDir"
    exec 9>"$lockFile"
    ${pkgs.util-linux}/bin/flock -x 9

    prevProfile=""
    prevDpCount="0"
    prevLidClosed="false"
    undockGeneration="0"
    shouldScheduleSuspend="0"
    scheduledUndockGeneration="0"
    suspendBufferSeconds=${toString gracePeriodSeconds}
    if [ -f "$stateFile" ]; then
      . "$stateFile"
    fi
    prevLidClosed="''${prevLidClosed:-false}"
    undockGeneration="''${undockGeneration:-0}"

    dpCount=$(${pkgs.hyprland}/bin/hyprctl --instance 0 monitors all 2>/dev/null | ${pkgs.gnugrep}/bin/grep -c '^Monitor DP-' || true)
    lidClosed=$(${pkgs.systemd}/bin/busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower LidIsClosed 2>/dev/null | ${pkgs.gawk}/bin/awk '{ print $2 }' || printf 'false\n')

    ${pkgs.util-linux}/bin/logger -t yuki-undock-suspend \
      "profile=$profile prevProfile=$prevProfile dpCount=$dpCount prevDpCount=$prevDpCount lidClosed=$lidClosed prevLidClosed=$prevLidClosed undockGeneration=$undockGeneration dryRun=$dryRun"

    if [ "$dpCount" -gt 0 ]; then
      ${pkgs.systemd}/bin/systemctl --user start yuki-docked-lid-inhibitor.service >/dev/null 2>&1 || true
      if [ "$prevDpCount" -eq 0 ] && [ "$undockGeneration" -gt 0 ]; then
        undockGeneration=$((undockGeneration + 1))
        ${pkgs.util-linux}/bin/logger -t yuki-undock-suspend \
          "dock reconnected; cancelling buffered suspend generation=$undockGeneration"
      fi
    fi

    case "$profile" in
      yukiInternal|fallback)
        if [ "$lidClosed" = "true" ] && [ "$dpCount" -eq 0 ] && [ "$prevDpCount" -gt 0 ]; then
          ${pkgs.systemd}/bin/systemctl --user start yuki-docked-lid-inhibitor.service >/dev/null 2>&1 || true
          shouldScheduleSuspend="1"
          scheduledUndockGeneration=$((undockGeneration + 1))
          undockGeneration="$scheduledUndockGeneration"
          ${pkgs.util-linux}/bin/logger -t yuki-undock-suspend \
            "closed-lid undock detected after profile=$profile; scheduling suspend-then-hibernate in 5 minutes generation=$scheduledUndockGeneration"
        fi
        ;;
    esac

    if [ "$lidClosed" = "true" ]; then
      ${display.yukiDisableInternalDisplaysScript}
    elif [ "$dpCount" -eq 0 ]; then
      ${pkgs.systemd}/bin/systemctl --user stop yuki-docked-lid-inhibitor.service >/dev/null 2>&1 || true
    fi

    printf 'prevProfile=%q\n' "$profile" > "$stateFile"
    printf 'prevDpCount=%q\n' "$dpCount" >> "$stateFile"
    printf 'prevLidClosed=%q\n' "$lidClosed" >> "$stateFile"
    printf 'undockGeneration=%q\n' "$undockGeneration" >> "$stateFile"

    ${pkgs.util-linux}/bin/flock -u 9

    if [ "$shouldScheduleSuspend" = "1" ] && [ "$dryRun" != "1" ]; then
      (
        ${pkgs.coreutils}/bin/sleep "$suspendBufferSeconds"

        currentUndockGeneration="0"
        if [ -f "$stateFile" ]; then
          . "$stateFile"
        fi
        currentUndockGeneration="''${undockGeneration:-0}"
        dpCountAfter=$(${pkgs.hyprland}/bin/hyprctl --instance 0 monitors all 2>/dev/null | ${pkgs.gnugrep}/bin/grep -c '^Monitor DP-' || true)
        lidClosedAfter=$(${pkgs.systemd}/bin/busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower LidIsClosed 2>/dev/null | ${pkgs.gawk}/bin/awk '{ print $2 }' || printf 'false\n')

        if [ "$currentUndockGeneration" != "$scheduledUndockGeneration" ]; then
          ${pkgs.util-linux}/bin/logger -t yuki-undock-suspend \
            "skipping stale suspend buffer generation=$scheduledUndockGeneration currentGeneration=$currentUndockGeneration"
          exit 0
        fi

        if [ "$lidClosedAfter" != "true" ] || [ "$dpCountAfter" -ne 0 ]; then
          ${pkgs.util-linux}/bin/logger -t yuki-undock-suspend \
            "cancelling buffered suspend generation=$scheduledUndockGeneration lidClosed=$lidClosedAfter dpCount=$dpCountAfter"
          exit 0
        fi

        ${pkgs.util-linux}/bin/logger -t yuki-undock-suspend \
          "buffer elapsed; running suspend-then-hibernate generation=$scheduledUndockGeneration"
        ${pkgs.systemd}/bin/systemctl suspend-then-hibernate
      ) >/dev/null 2>&1 &
    fi

    ${display.yukiSyncEdp2ModeScript}
  '';
in {
  # Override the portable preset's logind lid handling. yuki manages all
  # lid-close suspend behavior itself through the scripts above, both with
  # a 5-minute grace period before suspend-then-hibernate.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  home-manager.users.simonwjackson = {
    xdg.configFile."hyprdynamicmonitors/bin/yuki-undock-suspend" = {
      source = yukiUndockSuspendScript;
      executable = true;
    };

    systemd.user.services.yuki-docked-lid-inhibitor = {
      Unit = {
        Description = "Block logind lid handling while yuki manages dock transitions";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --why=YukiDockedLidHandling --what=handle-lid-switch --mode=block ${pkgs.coreutils}/bin/tail -f /dev/null";
      };
    };

    systemd.user.services.yuki-lid-state-watch = {
      Unit = {
        Description = "Keep yuki's lid, dock, and internal display state in sync";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${yukiLidStateWatchScript}";
        Restart = "always";
        RestartSec = "2s";
      };
    };
  };
}
