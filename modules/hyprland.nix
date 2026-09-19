# The desktop: Hyprland shaped to Kamoi.
#
# Kamoi (~/code/sandbox/irori) tiles the web on Android: one page per window,
# a master pane and a stack, on an ordered strip of workspaces. Its README is
# the product manual and the only source for what follows.
#
# Hyprland is the right base because Kamoi's model is master-and-stack with a
# bounded capacity per workspace. Everything Kamoi asks for that a scrollable
# compositor cannot do is a first-class call here.
#
# The config is Lua, not hyprland.conf. Hyprland 0.56 reads both and prefers
# hyprland.lua; 0.56 also shows this on every launch of a .conf:
#
#   src/i18n/Engine.cpp:254
#     "You are using the .conf config format, support for which will be
#      removed in Hyprland 0.57."
#
# Every call below was read out of 0.56.2's own source rather than a wiki:
#
#   hl.dsp tree                 config/lua/bindings/LuaBindingsDispatchers.cpp
#   hl.dsp.focus{last=true}     -> dsp_focusCurrentOrLast
#   window.fullscreen mode      "fullscreen"|"maximized", action toggle/set/unset
#   window.resize keep_aspect_ratio  -> dsp_mouseResize, shape preserved
#   hl.gesture fingers 2..9     config/ConfigManager.cpp handleGesture
#   overall shape               example/hyprland.lua, shipped with 0.56.2
{
  nixos.modules.desktop = {
    config,
    pkgs,
    ...
  }: let
    hyprPkg = config.programs.hyprland.package;

    # Under a Lua config, hyprctl changes shape and the legacy forms die
    # quietly. Verified on the machine:
    #
    #   hyprctl keyword monitor ...
    #     -> "keyword can't work with non-legacy parsers. Use eval."
    #   hyprctl dispatch layoutmsg "mfact exact 0.5"
    #     -> error: [string "return hl.dispatch(layoutmsg mfact exact 0.5)"]
    #        ')' expected near 'mfact'
    #
    # So `dispatch` now evaluates its argument as Lua, and `keyword` is
    # refused outright in favour of `eval`. Worse, hyprctl still exits 0
    # after printing those errors, so a broken helper looks like a working
    # one. Everything below uses the Lua forms.
    # Kamoi's interface scale: one control that resizes the whole UI, held
    # apart from per-application zoom.
    #
    # Hyprland quantises scale to 1/120 and then demands whole logical
    # pixels. From output/Monitor.cpp:
    #
    #   float    searchScale = std::round(m_scale * 120.0);
    #   double   scaleZero   = searchScale / 120.0;
    #   Vector2D logicalZero = m_pixelSize / scaleZero;
    #   if (logicalZero == logicalZero.round()) m_scale = scaleZero;
    #
    # So a legal scale is N/120 where both pw*120/N and ph*120/N are whole,
    # which means N divides 120 * gcd(pw, ph). For this 2880x1800 panel that
    # is 43200, giving 11 legal scales between 1.0 and 2.0.
    #
    # Miss the set and Hyprland does not fail outright: it hunts +/-1/120 up
    # to 90 steps, and on success raises a red notification naming the scale
    # it substituted. Working off the exact set avoids that notification.
    #
    # The ladder is computed from the live mode rather than written down, so
    # it stays correct on whatever monitor this stick is plugged into. Fine
    # steps move one rung, coarse steps three, which is how Kamoi's
    # Meta+scroll and Ctrl+Meta+scroll differ.
    #
    # The 1/120 rounding also absorbs decimal truncation: 160/120 prints as
    # 1.333333, and Hyprland multiplies by 120 and rounds straight back.
    hypr-scale = pkgs.writeShellApplication {
      name = "hypr-scale";
      runtimeInputs = [
        pkgs.jq
        pkgs.gawk
        hyprPkg # hyprctl; do not rely on inheriting it from the session
      ];
      text = ''
        MIN=0.8
        MAX=3.0
        DEFAULT=1.5
        COARSE_RUNGS=3

        case "''${1:-}" in
          up)        rungs=$COARSE_RUNGS ;;
          down)      rungs=-$COARSE_RUNGS ;;
          fine-up)   rungs=1 ;;
          fine-down) rungs=-1 ;;
          # Quoted because `reset` and `list` are also real commands; a
          # bare word there trips SC2209 as a likely missing $(...).
          # (Keep "shellcheck" off the start of a comment line: that is
          # its directive syntax and it errors with SC1124 inside a case.)
          reset)     rungs="reset" ;;
          get)       rungs="get" ;;
          list)      rungs="list" ;;
          *) echo "usage: hypr-scale up|down|fine-up|fine-down|reset|get|list" >&2; exit 2 ;;
        esac

        mon=$(hyprctl -j monitors | jq -r 'map(select(.focused))[0]')
        name=$(printf '%s' "$mon" | jq -r '.name')
        cur=$(printf '%s' "$mon" | jq -r '.scale')
        pw=$(printf '%s' "$mon" | jq -r '.width')
        ph=$(printf '%s' "$mon" | jq -r '.height')
        rr=$(printf '%s' "$mon" | jq -r '.refreshRate | . * 1000 | round / 1000')
        x=$(printf '%s' "$mon" | jq -r '.x')
        y=$(printf '%s' "$mon" | jq -r '.y')

        [ "$rungs" = get ] && { echo "$cur"; exit 0; }

        apply() {
          hyprctl eval "hl.monitor({ output = \"$name\", mode = \"''${pw}x''${ph}@''${rr}\", position = \"''${x}x''${y}\", scale = \"$1\" })"
        }

        [ "$rungs" = reset ] && { apply "$DEFAULT"; exit 0; }

        ladder() {
          awk -v cur="$cur" -v n="$1" -v pw="$pw" -v ph="$ph" \
              -v lo="$MIN" -v hi="$MAX" -v mode="$2" '
            function gcd(a, b) { while (b) { t = b; b = a % b; a = t } return a }
            BEGIN {
              # Legal scales are N/120 for N dividing 120*gcd(pw, ph).
              M = 120 * gcd(pw, ph)
              count = 0
              for (k = int(lo * 120 + 0.5); k <= int(hi * 120 + 0.5); k++)
                if (M % k == 0) L[++count] = k

              if (mode == "list") {
                for (i = 1; i <= count; i++)
                  printf "%.4f -> %dx%d\n", L[i]/120, pw*120/L[i], ph*120/L[i]
                exit
              }

              # Nearest rung to the live value, which may sit off-ladder.
              curN = cur * 120
              bi = 1; bd = 1e9
              for (i = 1; i <= count; i++) {
                d = L[i] - curN; if (d < 0) d = -d
                if (d < bd) { bd = d; bi = i }
              }

              i = bi + n
              if (i < 1) i = 1
              if (i > count) i = count
              printf "%.6f", L[i] / 120
            }'
        }

        [ "$rungs" = list ] && { ladder 0 list; exit 0; }

        apply "$(ladder "$rungs" step)"
      '';
    };

    # Kamoi zen mode: the same single window, inside a margin, so the page
    # reads as a column rather than a wall. Kamoi's defaults are 12% of the
    # width each side and 5% of the height top and bottom, stored as shares
    # so one setting reads the same in both orientations. Computed from the
    # live logical size for that reason.
    hypr-zen = pkgs.writeShellApplication {
      name = "hypr-zen";
      runtimeInputs = [
        pkgs.jq
        pkgs.gawk
        hyprPkg
      ];
      text = ''
        state="''${XDG_RUNTIME_DIR:-/tmp}/hypr-zen"
        NORMAL_GAPS=8   # must match general.gaps_out in hyprland.lua

        if [ -e "$state" ]; then
          rm -f "$state"
          hyprctl eval "hl.config({ general = { gaps_out = $NORMAL_GAPS } })"
          hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "unset" })'
          exit 0
        fi

        mon=$(hyprctl -j monitors | jq -r 'map(select(.focused))[0]')
        lw=$(printf '%s' "$mon" | jq -r '(.width / .scale) | round')
        lh=$(printf '%s' "$mon" | jq -r '(.height / .scale) | round')
        side=$(awk -v w="$lw" 'BEGIN { printf "%d", w * 0.12 }')
        vert=$(awk -v h="$lh" 'BEGIN { printf "%d", h * 0.05 }')

        touch "$state"
        # A comma string is the legacy form. Lua's css_gap type refuses it:
        #   "css_gap type requires an integer or a table with optional
        #    top, right, bottom, left fields"
        hyprctl eval "hl.config({ general = { gaps_out = { top = ''${vert}, right = ''${side}, bottom = ''${vert}, left = ''${side} } } })"
        hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "set" })'
      '';
    };

    # Kamoi Meta+G toggles the horizontal split between even and golden
    # ratios. `layoutmsg mfact` sets the focused workspace's ratio, which is
    # not the master:mfact option, so the state cannot be read back.
    hypr-split = pkgs.writeShellApplication {
      name = "hypr-split";
      runtimeInputs = [hyprPkg];
      text = ''
        state="''${XDG_RUNTIME_DIR:-/tmp}/hypr-split-golden"
        if [ -e "$state" ]; then
          rm -f "$state"
          hyprctl dispatch 'hl.dsp.layout("mfact exact 0.5")'
        else
          touch "$state"
          hyprctl dispatch 'hl.dsp.layout("mfact exact 0.61803")'
        fi
      '';
    };

    oled-idle = pkgs.writeShellApplication {
      name = "oled-idle";
      runtimeInputs = [
        pkgs.swayidle
        hyprPkg
      ];
      text = ''
        # `dispatch dpms off` is the legacy argument form. Under the Lua
        # parser, dispatch evaluates one Lua expression instead.
        exec swayidle -w \
          timeout 300 "hyprctl --instance 0 dispatch 'hl.dsp.dpms({ action = \"off\" })'" \
          resume "hyprctl --instance 0 dispatch 'hl.dsp.dpms({ action = \"on\" })'" \
          before-sleep "hyprctl --instance 0 dispatch 'hl.dsp.dpms({ action = \"off\" })'"
      '';
    };

    # The session, not just the compositor.
    #
    # Hyprland publishes its own environment to the systemd user manager and
    # withdraws it on exit. Both command lines are literals in the 0.56.2
    # binary:
    #
    #   systemctl --user import-environment DISPLAY WAYLAND_DISPLAY
    #     HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP
    #     QT_QPA_PLATFORMTHEME PATH XDG_DATA_DIRS
    #   systemctl --user unset-environment <the same list>
    #
    # It never starts graphical-session.target, and neither does
    # start-hyprland. The string "graphical-session" appears in neither
    # binary. So a unit with WantedBy=graphical-session.target never ran at
    # login. The bars only ever appeared because a person started them by
    # hand, and they stayed dead after the compositor restarted.
    #
    # graphical-session.target sets RefuseManualStart=yes, so no script can
    # start it directly. Verified on hiyori. A compositor target that binds to
    # it is the supported route: systemd starts a refused target when another
    # unit depends on it. RefuseManualStop is no, so exit can tear the whole
    # session down through it.
    start-mountainous = pkgs.writeShellApplication {
      name = "start-mountainous";
      # hyprPkg is deliberately absent. writeShellApplication prepends
      # runtimeInputs to PATH, which would make start-hyprland resolve
      # "Hyprland" to the bare store binary instead of the wrapper in
      # /run/wrappers/bin that carries cap_sys_nice+ep.
      runtimeInputs = [
        pkgs.systemd
        pkgs.coreutils
      ];
      text = ''
        # A compositor that died took its units down with it and may have
        # burned their restart budget. start refuses a unit still marked
        # failed, so clear the slate before the new session begins.
        systemctl --user reset-failed || true

        # tuigreet runs on tty1 and sets XDG_SESSION_TYPE=tty.
        # Ensure graphical applications and Ozone pick native Wayland.
        export XDG_SESSION_TYPE=wayland
        export XDG_CURRENT_DESKTOP=Hyprland
        export NIXOS_OZONE_WL=1
        systemctl --user import-environment XDG_SESSION_TYPE XDG_CURRENT_DESKTOP NIXOS_OZONE_WL || true

        # Hyprland publishes the environment only once it is up, so watch for
        # the signature rather than race it. Bash pattern matching, to keep
        # grep out of PATH and out of this script's closure.
        (
          for _ in {1..100}; do
            if [[ "$(systemctl --user show-environment)" == *HYPRLAND_INSTANCE_SIGNATURE=* ]]; then
              systemctl --user start hyprland-session.target
              exit 0
            fi
            sleep 0.1
          done
          echo "start-mountainous: Hyprland never published HYPRLAND_INSTANCE_SIGNATURE" >&2
          exit 1
        ) &

        # Unqualified, so PATH finds /run/wrappers/bin/Hyprland first. See
        # the note on runtimeInputs above.
        rc=0
        start-hyprland "$@" || rc=$?

        # Stop the session so its services exit cleanly. Without this they
        # restart against a compositor that is gone, fail five times, and
        # stay failed.
        systemctl --user stop graphical-session.target || true
        exit "$rc"
      '';
    };
    # Provide `zed` symlink alongside `zeditor` so both command names work in PATH.
    zed-wrapper = pkgs.runCommand "zed" {meta.mainProgram = "zed";} ''
      mkdir -p "$out/bin"
      ln -s ${pkgs.zed-editor}/bin/zeditor "$out/bin/zed"
    '';
  in {
    programs.hyprland.enable = true;

    # The bridge to graphical-session.target. start-mountainous starts this one;
    # systemd pulls in graphical-session.target because this target binds to
    # it, which is legal where a manual start is not.
    systemd.user.targets.hyprland-session = {
      description = "Hyprland session";
      documentation = ["man:systemd.special(7)"];
      bindsTo = ["graphical-session.target"];
      wants = ["graphical-session-pre.target"];
      after = ["graphical-session-pre.target"];
    };

    systemd.user.services.oled-idle = {
      description = "Blank OLED displays after five idle minutes";
      documentation = ["man:swayidle(1)"];
      wantedBy = ["hyprland-session.target"];
      partOf = ["graphical-session.target"];
      serviceConfig = {
        ExecStart = "${oled-idle}/bin/oled-idle";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };

    services.greetd = {
      enable = true;
      # start-hyprland, not Hyprland. It is "a binary to properly start
      # Hyprland via a watchdog process", and it is what Hyprland's own
      # session entry runs:
      #
      #   share/wayland-sessions/hyprland.desktop
      #     Exec=.../bin/start-hyprland
      #
      # Launching the compositor directly makes it warn on every start:
      #   i18n/Engine.cpp:253  TXT_KEY_NOTIF_NO_WATCHDOG
      #   "Hyprland was started without start-hyprland. This is strongly
      #    discouraged unless you are in a debugging environment."
      #
      # Deliberately unqualified. start-hyprland resolves "Hyprland"
      # through PATH, and NixOS puts /run/wrappers/bin first, where
      # programs/wayland/hyprland.nix installs a wrapper carrying
      # cap_sys_nice+ep for realtime scheduling. An absolute store path
      # would execute the uncapped binary instead.
      #
      # start-mountainous wraps start-hyprland to reach graphical-session.target.
      # It calls start-hyprland unqualified for the reason above.
      settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${start-mountainous}/bin/start-mountainous";
    };

    security.pam.services.greetd.enableGnomeKeyring = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    security.rtkit.enable = true;

    xdg.portal = {
      enable = true;
      # Without a backend the portal never activates, and the journal shows:
      #   "Could not activate remote peer 'org.freedesktop.portal.Desktop'"
      # The hyprland backend serves screencast and screenshot; the gtk one
      # serves file pickers, which the hyprland backend does not implement.
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
      config.common.default = "*";
    };

    environment.systemPackages = with pkgs; [
      alacritty
      fuzzel
      grim
      slurp
      wl-clipboard
      playerctl
      brightnessctl # required by the XF86MonBrightness key bindings
      jq
      adwaita-icon-theme # without a cursor theme Hyprland falls back badly
      hypr-scale
      hypr-zen
      hypr-split
      zed-editor
      zed-wrapper

      # The Zenbook A16 keyboard has one illumination key (Fn+F4) that emits
      # KEY_KBDILLUMTOGGLE. The firmware's own breathing mode is off, so the
      # key steps through the LED's four levels here instead. The script exits
      # early when the machine has no asus::kbd_backlight.
      (pkgs.writeShellScriptBin "kbd-backlight-cycle" ''
        set -eu
        led=/sys/class/leds/asus::kbd_backlight/brightness
        [ -r "$led" ] || exit 0
        case "$(cat "$led")" in
          0) next=1 ;;
          1) next=2 ;;
          2) next=3 ;;
          *) next=0 ;;
        esac
        exec ${pkgs.brightnessctl}/bin/brightnessctl --device='asus::kbd_backlight' set "$next"
      '')
    ];

    # brightnessctl ships 90-brightnessctl.rules, which hands the panel
    # backlight to the video group and the keyboard backlight to the input
    # group. NixOS links a package's udev rules only when it is listed here,
    # so without this the Hyprland brightness bindings run as simon and fail
    # with "Operation not permitted".
    services.udev.packages = [pkgs.brightnessctl];

    # brightnessctl's own rule puts keyboard backlights in the input group,
    # which would mean adding simon to input and with it the right to read
    # every keypress. The keyboard LED goes to video instead, the same group
    # the panel backlight already uses.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="leds", KERNEL=="asus::kbd_backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/leds/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness"
    '';

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "Hyprland";
      # Qt 6.5 and later read the XDG portal's color-scheme through this
      # platform theme, so Qt applications follow the desktop-theme command
      # instead of keeping a palette of their own. See modules/theme.nix.
      QT_QPA_PLATFORMTHEME = "xdgdesktopportal";
    };

    hjem.users.simon.files.".config/hypr/hyprland.lua".source =
      ./hyprland/hyprland.lua;
  };
}
