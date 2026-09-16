{
  lib,
  pkgs,
  ...
}: let
  brightnessSync = pkgs.callPackage ../../packages/brightness-sync {};

  brightness = "${brightnessSync}/bin/brightness-extended";
  kitty = "${pkgs.kitty}/bin/kitty";
  playerctl = "${pkgs.playerctl}/bin/playerctl";
  walker = "${pkgs.walker}/bin/walker";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";

  # Rendered inside the binds block, so each line carries its own indent.
  workspaceBinds =
    lib.concatMapStringsSep "\n"
    (n: "    Mod+${n} { focus-workspace ${n}; }\n    Mod+Shift+${n} { move-column-to-workspace ${n}; }") [
      "1"
      "2"
      "3"
      "4"
      "5"
      "6"
      "7"
      "8"
      "9"
    ];
in {
  # presets/desktop starts hypridle with listeners that call hyprctl. That
  # binary does not exist under niri, so the timers would fire into nothing.
  # Idle and lock handling on a niri host is unwritten, not broken.
  services.hypridle.enable = lib.mkForce false;

  home.packages = [
    pkgs.walker
    pkgs.wl-clipboard
    pkgs.xwayland-satellite
  ];

  # niri reads this path at startup and on `niri msg action load-config`.
  # Home Manager owns the file, so edit this module rather than the symlink.
  xdg.configFile."niri/config.kdl".text = ''
    // Generated from features/niri/home.nix. Do not edit in place.

    input {
        keyboard {
            xkb {
                layout "us"
            }
        }

        touchpad {
            tap
            dwt
            natural-scroll
        }
    }

    layout {
        gaps 8
        center-focused-column "never"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }

        default-column-width { proportion 0.5; }

        focus-ring {
            width 2
            active-color "#7aa2f7"
            inactive-color "#565f89"
        }
    }

    prefer-no-csd

    screenshot-path "~/Pictures/Screenshots/%Y-%m-%dT%H:%M:%S.png"

    // niri speaks Wayland only. xwayland-satellite hands X11 clients a display,
    // and DISPLAY has to name the same one for them to find it.
    spawn-at-startup "${pkgs.xwayland-satellite}/bin/xwayland-satellite" ":12"

    environment {
        DISPLAY ":12"
    }

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        Mod+Return { spawn "${kitty}"; }
        Mod+Space { spawn "${walker}"; }
        Mod+Q { close-window; }
        Mod+Ctrl+E { quit; }

        Mod+H { focus-column-left; }
        Mod+L { focus-column-right; }
        Mod+J { focus-window-down; }
        Mod+K { focus-window-up; }

        Mod+Shift+H { move-column-left; }
        Mod+Shift+L { move-column-right; }
        Mod+Shift+J { move-window-down; }
        Mod+Shift+K { move-window-up; }

    ${workspaceBinds}

        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+R { switch-preset-column-width; }
        Mod+V { toggle-window-floating; }

        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }

        XF86AudioRaiseVolume allow-when-locked=true { spawn "${wpctl}" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "${wpctl}" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute allow-when-locked=true { spawn "${wpctl}" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86AudioMicMute allow-when-locked=true { spawn "${wpctl}" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }

        XF86AudioNext allow-when-locked=true { spawn "${playerctl}" "next"; }
        XF86AudioPlay allow-when-locked=true { spawn "${playerctl}" "play-pause"; }
        XF86AudioPrev allow-when-locked=true { spawn "${playerctl}" "previous"; }

        XF86MonBrightnessUp allow-when-locked=true { spawn "${brightness}" "up" "1"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "${brightness}" "down" "1"; }
    }
  '';
}
