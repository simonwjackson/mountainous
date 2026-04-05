{
  lib,
  pkgs,
  hyprdynamicmonitors,
  ...
}: let
  display = import ./display-lib.nix {inherit pkgs lib;};
  inherit (display) defaultScale defaultYOffset resolution scalePresets yukiApplyDisplayScript;

  yukiRefreshRateScript = pkgs.writeShellScript "yuki-refresh-rate" ''
    set -eu

    if ${pkgs.hyprland}/bin/hyprctl --instance 0 monitors all 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^Monitor DP-'; then
      exit 0
    fi

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
    scale="${defaultScale}"

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
      reset)
        if ${pkgs.hyprland}/bin/hyprctl --instance 0 monitors all 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^Monitor DP-'; then
          target="1"
        else
          target="${defaultScale}"
        fi
        ;;
      get)
        current_scale
        exit 0
        ;;
      *)
        echo "usage: yuki-scale {up|down|set <scale>|reset|get}" >&2
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

  yukiEdp2ToggleScript = pkgs.writeShellScript "yuki-toggle-edp-2" ''
    set -eu

    runtimeDir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    lockFile="$runtimeDir/yuki-display.lock"
    panelModeStateFile="$runtimeDir/yuki-edp-2-mode"
    refreshStateFile="$runtimeDir/yuki-refresh-rate"
    scaleStateFile="$runtimeDir/yuki-scale"
    notifySend='${pkgs.libnotify}/bin/notify-send'

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

    exec 9>"$lockFile"
    ${pkgs.util-linux}/bin/flock -x 9

    if ${pkgs.hyprland}/bin/hyprctl --instance 0 monitors all 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^Monitor DP-'; then
      "$notifySend" "Displays" "eDP-2 toggle is only available while undocked."
      exit 0
    fi

    refresh=$(current_refresh)
    scale=$(current_scale)

    if ${pkgs.hyprland}/bin/hyprctl --instance 0 monitors 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^Monitor eDP-2'; then
      targetMode="single"
      message="eDP-2 disabled"
    else
      targetMode="dual"
      message="eDP-2 enabled"
    fi

    YUKI_INTERNAL_PANEL_MODE="$targetMode" ${yukiApplyDisplayScript} "$refresh" "$scale"
    printf '%s\n' "$targetMode" > "$panelModeStateFile"
    printf '%s\n' "$refresh" > "$refreshStateFile"
    printf '%s\n' "$scale" > "$scaleStateFile"
    "$notifySend" "Displays" "$message"
  '';

  yukiSelectSpeakerProfileScript = pkgs.writeShellScript "yuki-select-speaker-profile" ''
    set -eu

    wpctl='${pkgs.wireplumber}/bin/wpctl'
    pwCli='${pkgs.pipewire}/bin/pw-cli'
    amixer='${pkgs.alsa-utils}/bin/amixer'
    awk='${pkgs.gawk}/bin/awk'
    sed='${pkgs.gnused}/bin/sed'
    sleepCmd='${pkgs.coreutils}/bin/sleep'
    seqCmd='${pkgs.coreutils}/bin/seq'

    deviceId=""
    for _ in $($seqCmd 1 20); do
      deviceId=$($wpctl status | $awk '
        /sof-hda-dsp[[:space:]]+\[alsa\]/ {
          if (match($0, /[0-9]+\./)) {
            print substr($0, RSTART, RLENGTH - 1)
            exit
          }
        }
      ')
      if [ -n "$deviceId" ]; then
        break
      fi
      $sleepCmd 1
    done

    if [ -z "$deviceId" ]; then
      exit 0
    fi

    speakerProfile=$($pwCli e "$deviceId" EnumProfile | $awk '
      /Prop: key .*Profile:index/ { wantInt = 1; next }
      wantInt && $1 == "Int" { idx = $2; wantInt = 0; next }
      /String "HiFi .*Speaker/ { print idx; exit }
    ')

    if [ -z "$speakerProfile" ]; then
      exit 0
    fi

    $wpctl set-profile "$deviceId" "$speakerProfile"

    # Wait for the Speaker sink node to appear after profile switch.
    speakerSinkId=""
    for _ in $($seqCmd 1 10); do
      speakerSinkId=$($wpctl status | $awk '
        /sof-hda-dsp[[:space:]]+Speaker/ {
          if (match($0, /[0-9]+\./)) {
            print substr($0, RSTART, RLENGTH - 1)
            exit
          }
        }
      ')
      if [ -n "$speakerSinkId" ]; then
        break
      fi
      $sleepCmd 1
    done

    # Clear any stale "configured default" for sinks and sources that pins an
    # internal device. Previous versions of this script called `wpctl set-default`
    # for the internal speaker, which writes a persistent configured default to
    # WirePlumber's state file. That configured default overrides the
    # priority.session-based automatic selection, preventing external USB and
    # Bluetooth devices from becoming the default even when they have higher
    # priority. Removing these entries lets WirePlumber fall back to pure
    # priority-based selection.
    stateFile="''${XDG_STATE_HOME:-$HOME/.local/state}/wireplumber/default-nodes"
    if [ -f "$stateFile" ]; then
      $sed -i '/^default\.configured\.audio\.sink=alsa_output\.pci-0000_00_1f\.3/d' "$stateFile"
      $sed -i '/^default\.configured\.audio\.source=alsa_input\.pci-0000_00_1f\.3/d' "$stateFile"
    fi

    # Park the ALSA hardware Master at full scale and unmuted.
    #
    # With api.alsa.soft-mixer = true, PipeWire does volume in software and never
    # touches the hardware mixer. Without alsa-store/alsa-restore the kernel
    # default for this card leaves Master at 0 / muted, so no audio reaches the
    # CS35L56 amps. Setting it to max (0 dB, no attenuation) once here lets the
    # software mixer be the sole volume control, matching the intent of the
    # soft-mixer WirePlumber rule in this same config.
    $amixer -c0 sset Master 87 unmute >/dev/null 2>&1 || true
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
  #
  # We previously imported `nixos-hardware.nixosModules.lenovo-ideapad-14imh9` directly,
  # but current nixpkgs now asserts on that borrowed module's deprecated
  # `systemd.sleep.extraConfig` usage. Mirror the still-useful baseline settings here so
  # yuki keeps the same compatibility profile without depending on the deprecated option.
  boot.initrd.kernelModules = ["i915"];

  environment.variables.INTEL_DEBUG = lib.mkDefault "no32";

  security.tpm2.enable = lib.mkDefault true;

  hardware = {
    enableRedistributableFirmware = lib.mkDefault true;
    i2c.enable = lib.mkDefault true;
    # Persist the ALSA mixer state across reboots.
    #
    # yuki's internal SOF card comes up with the hardware mixer parked in a bad
    # state often enough that audio and capture can appear dead until the
    # session-side repair script runs. Restoring the last known-good ALSA state
    # at boot makes the fix survive full reboots instead of only the current
    # login session.
    alsa.enablePersistence = true;
    graphics = {
      extraPackages = [
        pkgs.intel-media-driver
        pkgs.intel-compute-runtime
        (pkgs.vpl-gpu-rt or pkgs.onevpl-intel-gpu)
      ];
      extraPackages32 = [pkgs.driversi686Linux.intel-media-driver];
    };
  };

  services = {
    fstrim.enable = lib.mkDefault true;
    fwupd.enable = lib.mkDefault true;
    hardware.bolt.enable = lib.mkDefault true;
    thermald.enable = lib.mkDefault true;
  };

  systemd.sleep.settings.Sleep.HibernateMode = lib.mkDefault "shutdown";

  systemd.services.workaround-reset-xhci-driver-after-resume-if-needed = {
    script = ''
      result=$(${pkgs.usbutils}/bin/lsusb | ${pkgs.gnugrep}/bin/grep Chicony)
      if [[ -z $result ]]; then
        ${pkgs.kmod}/bin/rmmod xhci_pci xhci_hcd
        ${pkgs.kmod}/bin/modprobe xhci_pci xhci_hcd
      fi
    '';
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "multi-user.target"
    ];
  };

  # The borrowed 14IMH9 profile also ships an old HDA modprobe workaround:
  #
  #   options snd-hda-intel model=generic
  #   options snd-hda-intel snd-intel-dspcfg.dsp_driver=1
  #   blacklist snd_soc_skl
  #
  # That was intended to avoid resume-related audio breakage on the borrowed machine, but
  # on yuki it makes the analog route show up as `Headphones` while the internal speakers
  # never appear as a proper sink. During profiling on yuki we also saw the second line is
  # no longer valid on current kernels (`unknown parameter 'snd-intel-dspcfg' ignored`).
  #
  # Since the Yoga Book 9i Gen 10 already boots the SOF stack correctly and both CS35L56
  # amps probe successfully, prefer the kernel's native machine-specific routing here.
  # If resume audio regressions return, re-evaluate this together with newer upstream
  # Yoga Book quirks instead of restoring the borrowed 14IMH9 workaround verbatim.
  boot.extraModprobeConfig = lib.mkForce "";

  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/51-yuki-soft-mixer.conf" ''
      monitor.alsa.rules = [
        {
          matches = [
            {
              device.name = "alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic"
            }
          ]
          actions = {
            update-props = {
              # Keep the laptop's quirky ALSA controls fixed and let PipeWire apply
              # volume in software. This avoids the broken hardware volume curve where
              # lowering volume mostly changes the brighter speaker path.
              api.alsa.soft-mixer = true
            }
          }
        }
      ]
    '')
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/52-yuki-internal-low-priority.conf" ''
      monitor.alsa.rules = [
        {
          matches = [
            {
              # All sinks on the internal sound card (Speaker, Headphones, etc.)
              # should have low priority so any external USB or Bluetooth audio
              # device automatically becomes the default output.
              node.name = "~alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.*"
            }
          ]
          actions = {
            update-props = {
              priority.driver = 100
              priority.session = 100
            }
          }
        }
        {
          matches = [
            {
              # All sources on the internal sound card (Stereo Microphone,
              # Digital Microphone, etc.) should have low priority so any
              # external USB or Bluetooth microphone automatically becomes
              # the default input.
              node.name = "~alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.*"
            }
          ]
          actions = {
            update-props = {
              priority.driver = 100
              priority.session = 100
            }
          }
        }
        {
          matches = [
            {
              # The Audioengine 2+ USB DAC (shows as "Mpow HC5" in descriptions
              # due to a USB descriptor quirk). When connected it should always be
              # the preferred audio output over the laptop's built-in speakers.
              node.name = "alsa_output.usb-Audioengine_LLC_Audioengine_2__AE202302221C0006-00.analog-stereo"
            }
          ]
          actions = {
            update-props = {
              priority.driver = 2000
              priority.session = 2000
            }
          }
        }
      ]
    '')
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/53-yuki-external-mic-priority.conf" ''
      monitor.alsa.rules = [
        {
          matches = [
            {
              # The Shure X2u is used exclusively as a microphone on yuki.
              # Disable its headphone output so audio never routes there.
              node.name = "alsa_output.usb-Shure_Incorporated_Shure_Digital-00.analog-stereo"
            }
          ]
          actions = {
            update-props = {
              node.disabled = true
            }
          }
        }
        {
          matches = [
            {
              # Boost the Shure X2u microphone input so it becomes the default
              # source whenever connected, taking precedence over internal mics
              # and other lower-priority external devices.
              node.name = "alsa_input.usb-Shure_Incorporated_Shure_Digital-00.mono-fallback"
            }
          ]
          actions = {
            update-props = {
              priority.driver = 2500
              priority.session = 2500
            }
          }
        }
      ]
    '')
    # Suppress the Saramonic BTW's headphone/speaker output.
    #
    # Bluetooth HSP/HFP profiles inherently bundle source + sink; there is no
    # source-only profile. Destroying the sink node (request_destroy) tears down
    # the entire SCO connection, killing the microphone too.
    #
    # Instead, demote the BT sink to the lowest possible priority so it is never
    # auto-selected by WirePlumber's default policy. The node still exists (to
    # keep the BT transport alive for the microphone) but will never be chosen
    # over any other sink.
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/55-yuki-disable-bt-mic-sinks.conf" ''
      monitor.bluez.rules = [
        {
          matches = [
            {
              # Saramonic BTW sink (colon-separated MAC variant).
              node.name = "~bluez_output.F4:4E:FC:84:E6:61*"
            }
          ]
          actions = {
            update-props = {
              priority.driver = 0
              priority.session = 0
            }
          }
        }
        {
          matches = [
            {
              # Saramonic BTW sink (underscore-separated MAC variant).
              node.name = "~bluez_output.F4_4E_FC_84_E6_61*"
            }
          ]
          actions = {
            update-props = {
              priority.driver = 0
              priority.session = 0
            }
          }
        }
      ]
    '')
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/54-yuki-disable-hdmi-audio.conf" ''
      monitor.alsa.rules = [
        {
          matches = [
            {
              # Match any HDMI / DisplayPort audio sink node.
              # On the SOF card these show up as separate nodes whose names contain
              # "HDMI" (e.g. HiFi__HDMI1__sink, HiFi__HDMI2__sink, etc.).
              node.name = "~alsa_output.*HDMI.*"
            }
          ]
          actions = {
            update-props = {
              node.disabled = true
            }
          }
        }
      ]
    '')
  ];

  boot.kernelParams = [
    # Mirrored from the borrowed 14IMH9 compatibility profile.
    "i915.enable_psr=0"
    "iommu.strict=1"
    "iommu.passthrough=1"
    ''i915.dmc_firmware_path=""''

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

  environment.etc."libinput/local-overrides.quirks".text = ''
    [Yuki External USB Keyboards]
    MatchBus=usb
    MatchUdevType=keyboard
    ModelTabletModeNoSuspend=1

    [Yuki External USB Mice]
    MatchBus=usb
    MatchUdevType=mouse
    ModelTabletModeNoSuspend=1

    [Yuki External USB Touchpads]
    MatchBus=usb
    MatchUdevType=touchpad
    ModelTabletModeNoSuspend=1
  '';

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

  systemd.services.unblock-bluetooth = {
    description = "Unblock Bluetooth on boot";
    wantedBy = [
      "bluetooth.target"
      "multi-user.target"
    ];
    after = ["systemd-rfkill.service"];
    before = ["bluetooth.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
    };
  };

  home-manager.users.simonwjackson = {
    home.packages = [
      hyprdynamicmonitors.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    home.hyprdynamicmonitors = {
      enable = true;
      configFile = ./hyprdynamicmonitors/config.toml;
      extraFiles = {
        "hyprdynamicmonitors/hyprconfigs" = ./hyprdynamicmonitors/hyprconfigs;
      };
      extraFlags = [
        "--disable-power-events"
        "--enable-lid-events"
      ];
    };

    mountainous.features.hyprland.keybinds = {
      ",XF86MonBrightnessUp" = {
        kind = "bindel";
        action = "exec, ${yukiBrightnessScript} up";
      };
      ",XF86MonBrightnessDown" = {
        kind = "bindel";
        action = "exec, ${yukiBrightnessScript} down";
      };
      # On yuki's keyboard, GUI+F7 appears to arrive as GUI+P in practice,
      # so provide the display toggle on both chords and move the color picker
      # to GUI+SHIFT+P for this host.
      "$mainMod, P" = {
        kind = "bind";
        action = "exec, ${yukiEdp2ToggleScript}";
      };
      "$mainMod SHIFT, P" = {
        kind = "bind";
        action = "exec, ${pkgs.hyprpicker}/bin/hyprpicker -a";
      };
      "$mainMod, F7" = {
        kind = "bind";
        action = "exec, ${yukiEdp2ToggleScript}";
      };
    };

    xdg.configFile."hypr/monitors.conf" = {
      force = true;
      text = ''
        # Bootstrap placeholder for HyprDynamicMonitors.
        #
        # Home Manager creates this so Hyprland's `source = ~/.config/hypr/monitors.conf`
        # always resolves during startup. The runtime daemon replaces it with the active
        # generated monitor profile after login.
      '';
    };

    xdg.configFile."hypr/yuki-quirks.conf".text = ''
      # This file is sourced from the main Hyprland config only on yuki.
      #
      # Keep only the temporary compositor-side display, lid, and power workarounds here.
      # Once kernel / firmware / Hyprland support improves, this should be the first file
      # reviewed and trimmed.

      # Bootstrap monitor layout
      # ------------------------
      # Keep yuki's two internal panels stacked vertically even before
      # HyprDynamicMonitors has generated ~/.config/hypr/monitors.conf for the session.
      #
      # This mirrors the default internal-only profile so startup stays predictable while
      # the daemon still gets to hotplug and manage any extra displays that appear later.
      monitor = eDP-1, ${resolution}@60, 0x0, ${defaultScale}, transform, 2
      monitor = eDP-2, ${resolution}@60, 0x${defaultYOffset}, ${defaultScale}

      # Live scale stepping
      # -------------------
      # Restore scale controls, applying them to whichever layout is currently active:
      # the stacked internal pair when undocked, or the active DP layout when external
      # panels are connected.
      bind = $mod CTRL, equal, exec, ${yukiScaleScript} up
      bind = $mod CTRL, minus, exec, ${yukiScaleScript} down
      bind = $mod CTRL, 0, exec, ${yukiScaleScript} reset

      # Software brightness implementation
      # ---------------------------------
      # Plasma on the installer gave the impression of per-display brightness control,
      # but investigation showed it was doing software dimming rather than changing the
      # kernel backlight devices. After more testing on the installed system we ended up
      # in a similar place: the kernel backlight nodes can be written, but without the
      # borrowed EDID hack they do not currently produce reliable visible dimming.
      #
      # The actual XF86 brightness keybindings are overridden via
      # `mountainous.features.hyprland.keybinds` so yuki can reuse the shared global keymap while
      # swapping only the command implementation.

      # Keyboard remapping
      # ------------------
      # Remap Caps Lock to Escape for this host.
      input:kb_options = caps:escape

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

      # Audio route selection
      # ---------------------
      # PipeWire/WirePlumber sometimes prefers the bogus `Headphones` profile on this
      # machine even when the internal speakers are the real target. A dedicated user
      # service now starts with the graphical session and keeps the built-in card on the
      # `Speaker` profile instead of relying on a compositor-side `exec-once` hook.

      # Lid / dock state policy
      # -----------------------
      # Keep a tiny watcher alive for the session so yuki can block logind's lid action
      # while docked, keep the internal OLEDs dark whenever the lid is shut, and restore
      # the internal layout immediately if we end up undocked with the lid open.
      exec-once = systemctl --user start yuki-lid-state-watch.service

      # Volume policy
      # -------------
      # Keep the real hardware mixer parked at a fixed state and let PipeWire do volume
      # changes in software. This avoids the Yoga Book's quirky ALSA mixer mapping where
      # hardware volume adjustments mostly change the brighter / treble-heavy speaker path.

      # Refresh-rate policy
      # -------------------
      # yuki has two internal panels and benefits noticeably from dropping to 60 Hz on
      # battery. Linux / Hyprland does not currently provide the polished, progressive,
      # Android-style refresh policy the hardware suggests, so this is our practical
      # compromise: a tiny user service that flips both panels between 60 Hz and 120 Hz
      # based on AC power state.
      exec-once = systemctl --user start yuki-refresh-rate.service
    '';

    systemd.user.services.yuki-audio-profile = {
      Unit = {
        Description = "Select the internal speaker profile and unmute Master on yuki";
        Wants = [
          "pipewire.service"
          "wireplumber.service"
        ];
        After = [
          "graphical-session.target"
          "pipewire.service"
          "wireplumber.service"
        ];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${yukiSelectSpeakerProfileScript}";
      };
      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };

    systemd.user.timers.yuki-audio-profile = {
      Unit.Description = "Periodically ensure speaker profile and ALSA Master are correct";
      Timer = {
        OnBootSec = "15s";
        OnUnitActiveSec = "30s";
        Unit = "yuki-audio-profile.service";
      };
      Install.WantedBy = ["timers.target"];
    };

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
