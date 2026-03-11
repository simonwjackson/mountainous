{
  lib,
  pkgs,
  nixos-hardware,
  ...
}: let
  knownGoodScale = "1.33";
  knownGoodMode = "2560x1600";
  scalePresets = ["1" "1.25" "1.33" "1.6" "2"];

  yukiApplyDisplayScript = pkgs.writeShellScript "yuki-apply-display" ''
    set -eu

    refresh="''${1:?usage: yuki-apply-display <refresh> <scale>}"
    scale="''${2:?usage: yuki-apply-display <refresh> <scale>}"

    # Apply each panel independently.
    #
    # On yuki, the scaling itself appears fine, but only when the monitor keywords are
    # sent as separate commands. A combined/batched dual-monitor update caused layout
    # problems that did not reproduce with independent calls.
    ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
      "keyword monitor eDP-1,${knownGoodMode}@''${refresh},auto,''${scale},transform,2"
    ${pkgs.hyprland}/bin/hyprctl --instance 0 --batch \
      "keyword monitor eDP-2,${knownGoodMode}@''${refresh},auto,''${scale}"
  '';

  yukiRefreshRateScript = pkgs.writeShellScript "yuki-refresh-rate" ''
    set -eu

    if [ ! -r /sys/class/power_supply/ADP0/online ]; then
      exit 0
    fi

    if [ "$(cat /sys/class/power_supply/ADP0/online)" = "1" ]; then
      refresh=120
    else
      refresh=60
    fi

    runtimeDir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    lockFile="$runtimeDir/yuki-display.lock"
    refreshStateFile="$runtimeDir/yuki-refresh-rate"
    scaleStateFile="$runtimeDir/yuki-scale"
    current=""
    scale="${knownGoodScale}"

    exec 9>"$lockFile"
    ${pkgs.util-linux}/bin/flock -x 9

    if [ -f "$refreshStateFile" ]; then
      current=$(cat "$refreshStateFile")
    fi

    if [ -f "$scaleStateFile" ]; then
      scale=$(cat "$scaleStateFile")
    fi

    if [ "$current" = "$refresh" ]; then
      exit 0
    fi

    if ${yukiApplyDisplayScript} "$refresh" "$scale"; then
      printf '%s\n' "$refresh" > "$refreshStateFile"
    fi
  '';

  yukiScaleScript = pkgs.writeShellScript "yuki-scale" ''
    set -eu

    runtimeDir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    lockFile="$runtimeDir/yuki-display.lock"
    refreshStateFile="$runtimeDir/yuki-refresh-rate"
    scaleStateFile="$runtimeDir/yuki-scale"
    presets=(${lib.concatStringsSep " " scalePresets})

    current_scale() {
      if [ -f "$scaleStateFile" ]; then
        cat "$scaleStateFile"
      else
        printf '${knownGoodScale}\n'
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

    find_index() {
      target="$1"
      idx=0
      for preset in "''${presets[@]}"; do
        if [ "$preset" = "$target" ]; then
          printf '%s\n' "$idx"
          return 0
        fi
        idx=$((idx + 1))
      done
      printf '0\n'
    }

    exec 9>"$lockFile"
    ${pkgs.util-linux}/bin/flock -x 9

    case "''${1:-}" in
      up)
        idx=$(find_index "$(current_scale)")
        if [ "$idx" -lt $((''${#presets[@]} - 1)) ]; then
          idx=$((idx + 1))
        fi
        target="''${presets[$idx]}"
        ;;
      down)
        idx=$(find_index "$(current_scale)")
        if [ "$idx" -gt 0 ]; then
          idx=$((idx - 1))
        fi
        target="''${presets[$idx]}"
        ;;
      set)
        target="''${2:?usage: yuki-scale set <scale>}"
        ;;
      get)
        current_scale
        exit 0
        ;;
      *)
        echo "usage: yuki-scale {up|down|set <scale>|get}" >&2
        exit 1
        ;;
    esac

    current=$(current_scale)
    if [ "$target" = "$current" ]; then
      exit 0
    fi

    refresh=$(current_refresh)
    if ${yukiApplyDisplayScript} "$refresh" "$target"; then
      printf '%s\n' "$target" > "$scaleStateFile"
      printf '%s\n' "$refresh" > "$refreshStateFile"
    fi
  '';

  yukiBrightnessScript = pkgs.writeShellScript "yuki-brightness" ''
        set -eu

        min=5
        max=100
        stepDefault=5
        runtimeDir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        stateFile="$runtimeDir/yuki-brightness"
        shaderFile="$runtimeDir/yuki-brightness.glsl"

        current_percent() {
          if [ -f "$stateFile" ]; then
            cat "$stateFile"
          else
            printf '100\n'
          fi
        }

        write_shader() {
          opacity="$1"
          cat > "$shaderFile" <<EOF
    #version 300 es
    precision highp float;
    in vec2 v_texcoord;
    out vec4 fragColor;
    uniform sampler2D tex;
    void main() {
      vec4 c = texture(tex, v_texcoord);
      c.rgb *= $opacity;
      fragColor = c;
    }
    EOF
        }

        apply_percent() {
          target="$1"
          [ "$target" -lt "$min" ] && target="$min"
          [ "$target" -gt "$max" ] && target="$max"
          printf '%s\n' "$target" > "$stateFile"

          if [ "$target" -ge 100 ]; then
            rm -f "$shaderFile"
            ${pkgs.hyprland}/bin/hyprctl --instance 0 keyword decoration:screen_shader ""
            exit 0
          fi

          opacity=$(awk "BEGIN { printf \"%.3f\", $target / 100 }")
          write_shader "$opacity"
          ${pkgs.hyprland}/bin/hyprctl --instance 0 keyword decoration:screen_shader "$shaderFile"
        }

        case "''${1:-}" in
          up)
            step="''${2:-$stepDefault}"
            apply_percent "$(( $(current_percent) + step ))"
            ;;
          down)
            step="''${2:-$stepDefault}"
            apply_percent "$(( $(current_percent) - step ))"
            ;;
          set)
            apply_percent "''${2:?usage: yuki-brightness set <percent>}"
            ;;
          get)
            current_percent
            ;;
          *)
            echo "usage: yuki-brightness {up [step]|down [step]|set <percent>|get}" >&2
            exit 1
            ;;
        esac
  '';
in {
  imports = [
    # There is not yet an exact nixos-hardware module for the Yoga Book 9i Gen 10 (83Q8),
    # so we currently borrow the closest upstream Lenovo Intel laptop profile as part of
    # the overall compatibility story for this host.
    #
    # This lives here instead of `hosts/yuki/default.nix` on purpose: the borrowed module
    # is temporary and should be reviewed alongside the rest of yuki's quirks whenever we
    # test newer kernels, firmware, or a future first-class upstream hardware module.
    nixos-hardware.nixosModules.lenovo-ideapad-14imh9
  ];

  # This module intentionally centralizes the host-specific quirks for yuki so they can
  # be audited, deleted, or re-tested as upstream support improves.
  #
  # Why this exists:
  # - yuki is a Lenovo Yoga Book 9i Gen 10, but nixos-hardware does not yet ship an exact
  #   module for it.
  # - We currently borrow the nearest Lenovo IdeaPad 14IMH9 profile for a baseline.
  # - During bring-up, several display / sleep / input behaviors diverged from both the
  #   installer and from a stock laptop setup.
  # - Keeping all of those decisions in one file makes future clean-up much easier:
  #   when a kernel, firmware, or proper upstream hardware profile lands, this is the
  #   first file to review.

  boot.kernelParams = [
    # Historical note:
    # The borrowed 14IMH9 profile already disables PSR and adds a few Intel graphics
    # workarounds. We still add our own flags here because they were discovered while
    # testing the actual Yoga Book 9i hardware, not the borrowed model.

    # Best-known setting from the hardware-brightness experiments.
    #
    # We previously tried multiple i915 DPCD backlight modes. `=1` was the least-bad
    # option we found on yuki and is left in place as a breadcrumb for future testing.
    # Even though we are currently using software dimming, keep this documented so that
    # a future kernel / firmware retest starts from the same known point.
    "i915.enable_dpcd_backlight=1"

    # This machine behaved more reliably when advertising an older Windows ACPI profile.
    # Keep this here until suspend / resume / panel behavior is re-validated without it.
    ''acpi_osi="!Windows 2020"''

    # Explicitly prefer suspend-to-idle. This matched the direction of our hibernation /
    # sleep work and avoided bouncing between platform sleep modes while debugging.
    "mem_sleep_default=s2idle"
  ];

  hardware.display.outputs."eDP-1".edid = lib.mkForce null;

  # The borrowed 14IMH9 module ships an EDID override for eDP-1 to fix refresh-rate
  # issues on that machine. On yuki, that borrowed EDID produced a visible greenish tint
  # on the top panel and also caused the panel to identify itself strangely.
  #
  # We intentionally force the override back to `null` here so yuki uses its real panel
  # EDID again. The trade-off is important and should be remembered:
  # - with the borrowed EDID: top panel hardware brightness had some visible effect, but
  #   color looked wrong;
  # - without the borrowed EDID: color looks correct (or at least much closer), but the
  #   previously observed hardware-brightness behavior no longer reproduces reliably.
  #
  # Current policy choice:
  # prefer correct panel identity / color over the borrowed EDID hack, and use software
  # dimming for day-to-day brightness control until a real Yoga Book 9i fix is found.

  systemd.services.fix-backlight-permissions = {
    description = "Allow video group to control backlight devices";
    after = ["systemd-udev-settle.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      # During the original hardware-brightness investigation, Hyprland keybinds ran as
      # the regular user and could not write the kernel backlight nodes. Granting group
      # write access to the `video` group made experimentation possible without using
      # sudo from inside the compositor session.
      #
      # This is retained even though the current brightness path is software-based,
      # because it preserves the ability to re-test hardware backlight control quickly.
      for brightness in /sys/class/backlight/*/brightness; do
        [ -e "$brightness" ] || continue
        ${pkgs.coreutils}/bin/chgrp video "$brightness" || true
        ${pkgs.coreutils}/bin/chmod g+w "$brightness" || true
      done
    '';
  };

  systemd.services.disable-elan-wakeup-before-sleep = {
    description = "Disable ELAN touchpad wakeup sources before sleep";
    before = ["sleep.target"];
    wantedBy = ["sleep.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      # On this dual-screen Lenovo, ELAN-related wakeup sources appeared to cause
      # immediate or near-immediate wakeups when trying to suspend.
      #
      # We intentionally search generically for ELAN wakeup files instead of hardcoding
      # a single sysfs path because the exact device path may shift across kernels.
      # If the hardware topology stabilizes in a future kernel, this can be simplified.
      while IFS= read -r wakeup; do
        echo disabled > "$wakeup" || true
      done < <(find /sys -name "wakeup" | xargs grep -l "enabled" 2>/dev/null | grep -i elan || true)
    '';
  };

  home-manager.users.simonwjackson = {
    xdg.configFile."hypr/yuki-workarounds.conf".text = ''
      # This file is sourced from the main Hyprland config only on yuki.
      #
      # Keep host-specific compositor quirks here instead of baking them deeper into the
      # generic home-manager config. When upstream support improves, this file should be
      # the first thing reviewed and trimmed.

      # Base monitor layout
      # -------------------
      # This is the currently known-good scaled layout for yuki.
      #
      # Earlier attempts used native 2880x1800 plus explicit stacked coordinates, but
      # that led to badly shifted window placement on the bottom panel. The stable setup
      # we found in live testing is to let Hyprland auto-place both displays while using
      # a 2560x1600 mode at 1.33 scale.
      monitor = eDP-1, ${knownGoodMode}@60, auto, ${knownGoodScale}, transform, 2
      monitor = eDP-2, ${knownGoodMode}@60, auto, ${knownGoodScale}

      # Visual baseline
      # ---------------
      # Keep the desktop background as a plain solid black. That fits the dual-OLED
      # hardware well, avoids distracting default wallpaper/splash visuals, and plays
      # nicely with the software dimming path below.
      misc:force_default_wallpaper = 0
      misc:background_color = 0x000000

      # Live scale stepping
      # -------------------
      # Restore scale controls, but apply them using two independent monitor commands.
      # That matches the manual sequence that behaved correctly on yuki.
      bind = $mod CTRL, equal, exec, ${yukiScaleScript} up
      bind = $mod CTRL, minus, exec, ${yukiScaleScript} down
      bind = $mod CTRL, 0, exec, ${yukiScaleScript} set ${knownGoodScale}

      # Software brightness implementation
      # ---------------------------------
      # Plasma on the installer gave the impression of per-display brightness control,
      # but investigation showed it was doing software dimming rather than changing the
      # kernel backlight devices. After more testing on the installed system we ended up
      # in a similar place: the kernel backlight nodes can be written, but without the
      # borrowed EDID hack they do not currently produce reliable visible dimming.
      #
      # So the current user-facing solution is a Hyprland screen shader driven by the
      # brightness keys. This is intentionally documented here so it is obvious that this
      # is a compromise, not a final answer.
      bind = , XF86MonBrightnessUp, exec, ${yukiBrightnessScript} up
      bind = , XF86MonBrightnessDown, exec, ${yukiBrightnessScript} down

      cursor {
        # Important companion setting for shader-based dimming.
        #
        # With hardware cursors enabled, the cursor is rendered on a separate plane and
        # stays at full brightness even when the rest of the scene is dimmed. Disabling
        # hardware cursors makes the cursor participate in the same rendered scene as the
        # rest of Hyprland, so the software brightness effect also dims the pointer.
        #
        # Trade-off: software cursors can theoretically be less efficient or slightly less
        # smooth on some systems, so this should be re-evaluated if Hyprland or the kernel
        # gains a better per-output dimming path in the future.
        no_hardware_cursors = true
      }

      # Refresh-rate policy
      # -------------------
      # yuki has two internal panels and benefits noticeably from dropping to 60 Hz on
      # battery. Linux / Hyprland does not currently provide the polished, progressive,
      # Android-style refresh policy the hardware suggests, so this is our practical
      # compromise: a tiny user service that flips both panels between 60 Hz and 120 Hz
      # based on AC power state.
      exec-once = systemctl --user start yuki-refresh-rate.service
    '';

    systemd.user.services.yuki-refresh-rate = {
      Unit = {
        Description = "Adjust Hyprland refresh rate based on AC power";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${yukiRefreshRateScript}";
      };
    };

    systemd.user.timers.yuki-refresh-rate = {
      Unit.Description = "Poll AC power and update Hyprland refresh rate";
      Timer = {
        OnBootSec = "20s";
        OnUnitActiveSec = "20s";
        Unit = "yuki-refresh-rate.service";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
