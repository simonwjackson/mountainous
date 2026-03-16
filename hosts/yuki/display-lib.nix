# Shared display constants and primitive scripts for yuki.
#
# Both quirks.nix and lid-suspend.nix import this file so that display helper
# scripts are defined once and referenced from either module.
{
  pkgs,
  lib,
}: let
  defaultScale = "1.25";
  defaultYOffset = "1280";
  resolution = "2560x1600";
  scalePresets = [
    "1"
    "1.25"
    "1.33"
    "1.6"
    "2"
  ];

  yukiApplyDisplayScript = pkgs.writeShellScript "yuki-apply-display" ''
    set -eu

    refresh="''${1:?usage: yuki-apply-display <refresh> <scale>}"
    scale="''${2:?usage: yuki-apply-display <refresh> <scale>}"
    externalRefresh="100"
    runtimeDir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    panelModeStateFile="$runtimeDir/yuki-edp-2-mode"
    panelMode="''${YUKI_INTERNAL_PANEL_MODE:-}"

    if [ -z "$panelMode" ] && [ -f "$panelModeStateFile" ]; then
      panelMode=$(cat "$panelModeStateFile")
    fi

    if [ -z "$panelMode" ]; then
      panelMode="dual"
    fi

    internalYOffset=$(awk "BEGIN {
      y = 1600 / $scale;
      printf \"%d\", y + 0.5;
    }")

    externalYOffset=$(awk "BEGIN {
      y = 1800 / $scale;
      printf \"%d\", y + 0.5;
    }")

    dpCount=$(${pkgs.hyprland}/bin/hyprctl --instance 0 monitors all 2>/dev/null | ${pkgs.gnugrep}/bin/grep -c '^Monitor DP-' || true)

    if [ "$dpCount" -ge 2 ]; then
      ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
        "keyword monitor eDP-1,disable"
      ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
        "keyword monitor eDP-2,disable"
      ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
        "keyword monitor DP-1,2880x1800@''${externalRefresh},0x0,''${scale}"
      ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
        "keyword monitor DP-2,2880x1800@''${externalRefresh},0x''${externalYOffset},''${scale}"
      exit 0
    fi

    if [ "$dpCount" -eq 1 ]; then
      dpName=$(${pkgs.hyprland}/bin/hyprctl --instance 0 monitors all 2>/dev/null | ${pkgs.gawk}/bin/awk '/^Monitor DP-/{gsub(/[():]/, "", $2); print $2; exit}')
      ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
        "keyword monitor eDP-1,disable"
      ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
        "keyword monitor eDP-2,disable"
      ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
        "keyword monitor ''${dpName},2880x1800@''${externalRefresh},0x0,''${scale}"
      exit 0
    fi

    # Keep the internal panels stacked vertically when both are enabled.
    #
    # The bottom panel's Y position must track the scaled logical height of the top
    # panel. For 2560x1600 at scale 1.25 this becomes 1280, and we derive the same math
    # for the other scale presets so the two displays keep touching edge-to-edge.

    # Apply each panel independently.
    #
    # On yuki, the scaling path behaved better when monitor keywords were sent as
    # separate commands rather than a single dual-monitor batch update.
    ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
      "keyword monitor eDP-1,${resolution}@''${refresh},0x0,''${scale},transform,2"

    case "$panelMode" in
      dual)
        ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
          "keyword monitor eDP-2,${resolution}@''${refresh},0x''${internalYOffset},''${scale}"
        # HACK: Bug in Hyprland needs this to get the placement right.
        ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
          "keyword monitor eDP-2,${resolution}@''${refresh},0x''${internalYOffset},''${scale}"
        ;;
      single)
        ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
          "keyword monitor eDP-2,disable"
        ;;
      *)
        echo "invalid yuki internal panel mode: $panelMode" >&2
        exit 1
        ;;
    esac
  '';

  yukiDisableInternalDisplaysScript = pkgs.writeShellScript "yuki-disable-internal-displays" ''
    set -eu

    ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
      "keyword monitor eDP-1,disable" >/dev/null 2>&1 || true
    ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
      "keyword monitor eDP-2,disable" >/dev/null 2>&1 || true
  '';

  yukiRestoreUndockedDisplaysScript = pkgs.writeShellScript "yuki-restore-undocked-displays" ''
    set -eu

    runtimeDir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    refreshStateFile="$runtimeDir/yuki-refresh-rate"
    scaleStateFile="$runtimeDir/yuki-scale"

    current_scale() {
      if [ -f "$scaleStateFile" ]; then
        cat "$scaleStateFile"
      else
        printf '${defaultScale}\n'
      fi
    }

    current_refresh() {
      if [ -f "$refreshStateFile" ]; then
        cat "$refreshStateFile"
      elif [ -r /sys/class/power_supply/ADP0/online ] && [ "$(cat /sys/class/power_supply/ADP0/online)" = "1" ]; then
        printf '120\n'
      else
        printf '60\n'
      fi
    }

    if ${pkgs.hyprland}/bin/hyprctl --instance 0 monitors all 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^Monitor DP-'; then
      exit 0
    fi

    lidClosed=$(${pkgs.systemd}/bin/busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower LidIsClosed 2>/dev/null | ${pkgs.gawk}/bin/awk '{ print $2 }' || printf 'false\n')
    if [ "$lidClosed" = "true" ]; then
      exit 0
    fi

    ${yukiApplyDisplayScript} "$(current_refresh)" "$(current_scale)"
  '';

  yukiSyncEdp2ModeScript = pkgs.writeShellScript "yuki-sync-edp-2-mode" ''
    set -eu

    runtimeDir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    panelModeStateFile="$runtimeDir/yuki-edp-2-mode"
    refreshStateFile="$runtimeDir/yuki-refresh-rate"
    scaleStateFile="$runtimeDir/yuki-scale"

    current_scale() {
      if [ -f "$scaleStateFile" ]; then
        cat "$scaleStateFile"
      else
        printf '${defaultScale}\n'
      fi
    }

    current_refresh() {
      if [ -f "$refreshStateFile" ]; then
        cat "$refreshStateFile"
      elif [ -r /sys/class/power_supply/ADP0/online ] && [ "$(cat /sys/class/power_supply/ADP0/online)" = "1" ]; then
        printf '120\n'
      else
        printf '60\n'
      fi
    }

    if ${pkgs.hyprland}/bin/hyprctl --instance 0 monitors all 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^Monitor DP-'; then
      exit 0
    fi

    lidClosed=$(${pkgs.systemd}/bin/busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower LidIsClosed 2>/dev/null | ${pkgs.gawk}/bin/awk '{ print $2 }' || printf 'false\n')
    if [ "$lidClosed" = "true" ]; then
      exit 0
    fi

    if [ ! -f "$panelModeStateFile" ] || [ "$(cat "$panelModeStateFile")" != "single" ]; then
      exit 0
    fi

    YUKI_INTERNAL_PANEL_MODE=single ${yukiApplyDisplayScript} "$(current_refresh)" "$(current_scale)"
  '';
in {
  inherit defaultScale defaultYOffset resolution scalePresets;
  inherit yukiApplyDisplayScript yukiDisableInternalDisplaysScript yukiRestoreUndockedDisplaysScript yukiSyncEdp2ModeScript;
}
