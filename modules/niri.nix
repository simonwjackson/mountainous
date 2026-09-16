# One feature, one file. The compositor, its session, and its dotfile.
#
# The keymap follows Kamoi (~/code/sandbox/irori), which tiles the web on
# Android with the same idea niri applies to a desktop. Kamoi's README is its
# product manual, and the chords below are its chords wherever niri can honour
# them.
#
# Three things Kamoi does that niri 26.04 cannot, checked against all 142
# actions `niri msg action` exposes:
#
#   Meta+Shift+G  mirror the workspace        no mirror action
#   Meta+Shift+F  sticky floater              no sticky action
#   per-page seam fractions                   niri sizes per column
#
# Those are model differences, not gaps. Kamoi is dwm-shaped, with a master
# pane and a stack. niri is a scrollable ribbon of columns. Bending one into
# the other would fight the compositor rather than use it.
#
# Note on config.kdl: niri does NOT merge a user config with its shipped
# default. Whatever is in this file is the complete set of keybinds.
{
  nixos.modules.desktop =
    {
      config,
      pkgs,
      ...
    }:
    let
      niriPkg = config.programs.niri.package;

      # Kamoi's interface scale: one control that resizes the whole UI, held
      # apart from per-application zoom. niri has no runtime scale action, but
      # `niri msg output <name> scale <x>` does the same job over IPC.
      niri-scale = pkgs.writeShellApplication {
        name = "niri-scale";
        runtimeInputs = [
          pkgs.jq
          pkgs.gawk
          niriPkg
        ];
        text = ''
          # Steps match Kamoi: a coarse step for the keys and the wheel, a
          # finer one for Ctrl+Meta+wheel.
          COARSE=0.1
          FINE=0.025
          MIN=0.5
          MAX=3.0
          # "100%" for this panel. 2880x1800 across 340mm is about 215 PPI,
          # so 1.5 gives a logical 1920x1200. Kamoi's Meta+0 returns to the
          # native size; here the native size is the one that is readable.
          DEFAULT=1.5

          info=$(niri msg --json focused-output)
          name=$(printf '%s' "$info" | jq -r '.name')
          cur=$(printf '%s' "$info" | jq -r '.logical.scale')

          case "''${1:-}" in
            up)        delta=$COARSE ;;
            down)      delta=-$COARSE ;;
            fine-up)   delta=$FINE ;;
            fine-down) delta=-$FINE ;;
            reset)     niri msg output "$name" scale "$DEFAULT"; exit 0 ;;
            set)       niri msg output "$name" scale "''${2:?scale required}"; exit 0 ;;
            *)         echo "usage: niri-scale up|down|fine-up|fine-down|reset|set <x>" >&2; exit 2 ;;
          esac

          new=$(awk -v c="$cur" -v d="$delta" -v lo="$MIN" -v hi="$MAX" \
            'BEGIN { v = c + d; if (v < lo) v = lo; if (v > hi) v = hi; printf "%.3f", v }')
          niri msg output "$name" scale "$new"
        '';
      };

      # Kamoi's zen mode: the same single window, but inside a margin, so the
      # page reads as a column rather than a wall.
      #
      # niri allows one action per bind, so this cannot be a plain bind: zen
      # needs both a width and a centre. It also needs to toggle, and niri
      # exposes no way to read a column's current width, so the off switch
      # returns to default-column-width rather than to whatever you had.
      niri-zen = pkgs.writeShellApplication {
        name = "niri-zen";
        runtimeInputs = [ niriPkg ];
        text = ''
          state="''${XDG_RUNTIME_DIR:-/tmp}/niri-zen"
          if [ -e "$state" ]; then
            rm -f "$state"
            niri msg action set-column-width "50%"   # default-column-width
          else
            touch "$state"
            niri msg action set-column-width "66%"
            niri msg action center-column
          fi
        '';
      };
    in
    {
      programs.niri.enable = true;

      services.greetd = {
        enable = true;
        settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
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
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      };

      environment.systemPackages = with pkgs; [
        alacritty
        fuzzel
        swaybg
        wl-clipboard
        playerctl
        jq
        niri-scale
        niri-zen
      ];

      hjem.users.simon.files.".config/niri/config.kdl".text = ''
        // Samsung Galaxy Book3 Pro 360 panel: 2880x1800 across 340x220mm,
        // about 215 PPI, 120Hz. Scale 1.5 gives a logical 1920x1200.
        output "eDP-1" {
            mode "2880x1800@120.001"
            scale 1.5
            // on-demand keeps VRR for video and games without letting an
            // idle desktop drop the refresh rate and stutter the cursor.
            variable-refresh-rate on-demand=true
        }

        input {
            keyboard {
                xkb {
                    layout "us"
                }
                numlock
            }
            touchpad {
                tap
                natural-scroll
                dwt
            }
            // Kamoi: "Moving into a window focuses it." Focus stops at the
            // window; the page keeps its scroll position.
            focus-follows-mouse max-scroll-amount="0%"
        }

        layout {
            // Kamoi's window gap default is 8dp, and the gap always shows
            // the black backdrop.
            gaps 8
            background-color "#000000"

            center-focused-column "never"
            default-column-width { proportion 0.5; }

            // Kamoi Meta+G toggles the horizontal split between even and
            // golden ratios. These are the two ratios plus its inverse.
            preset-column-widths {
                proportion 0.5
                proportion 0.61803
                proportion 0.38197
            }

            // Kamoi: "Windows carry no border. The black gap separates them,
            // and the pointer says which window is live."
            focus-ring {
                off
            }
            border {
                off
            }
        }

        prefer-no-csd

        hotkey-overlay {
            // Leave the startup pop-up on. With no bar and no focus ring,
            // it is the only discoverable surface.
        }

        screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

        binds {
            Mod+Shift+Slash { show-hotkey-overlay; }

            //
            // GROUP 1: layout and windows
            //
            Mod+N hotkey-overlay-title="New window: alacritty" { spawn "alacritty"; }
            Mod+C repeat=false { close-window; }

            // Kamoi Meta+1/2/3 set the page capacity: one fullscreen window,
            // two columns, or three. niri sizes the focused column rather
            // than the whole workspace, so this applies to the column you
            // are on, not to every window at once.
            Mod+1 hotkey-overlay-title="Capacity: one window"    { set-column-width "100%"; }
            Mod+2 hotkey-overlay-title="Capacity: two columns"   { set-column-width "50%"; }
            Mod+3 hotkey-overlay-title="Capacity: three columns" { set-column-width "33.33%"; }

            // Even split, golden ratio, and its inverse.
            Mod+G       { switch-preset-column-width; }
            Mod+Shift+G { switch-preset-column-width-back; }

            // Kamoi Meta+Enter promotes to the master pane. On a ribbon the
            // equivalent is the first column.
            Mod+Return hotkey-overlay-title="Promote to first column" { move-column-to-first; }

            // Monocle: one window, no gaps, filling the screen. Toggles.
            Mod+M hotkey-overlay-title="Monocle" { maximize-window-to-edges; }

            // Zen: the same window inside a margin, for reading.
            Mod+Shift+M hotkey-overlay-title="Zen" { spawn "${niri-zen}/bin/niri-zen"; }

            Mod+F       { toggle-window-floating; }
            Mod+Shift+F { switch-focus-between-floating-and-tiling; }

            // Kamoi Ctrl+Meta+= / - grow and shrink a floater.
            Ctrl+Mod+Equal { set-window-width "+10%"; }
            Ctrl+Mod+Minus { set-window-width "-10%"; }

            // Column and window geometry.
            Mod+R           { switch-preset-window-height; }
            Mod+Ctrl+R      { reset-window-height; }
            Mod+Shift+Equal { set-column-width "+10%"; }
            Mod+Shift+Minus { set-column-width "-10%"; }
            Mod+Ctrl+F      { expand-column-to-available-width; }
            Mod+W           { toggle-column-tabbed-display; }
            Mod+BracketLeft  { consume-or-expel-window-left; }
            Mod+BracketRight { consume-or-expel-window-right; }
            Mod+Comma        { consume-window-into-column; }
            Mod+Period       { expel-window-from-column; }

            //
            // GROUP 2: navigation and switching
            //
            Mod+H { focus-column-left; }
            Mod+L { focus-column-right; }
            Mod+J { focus-window-down; }
            Mod+K { focus-window-up; }
            Mod+Left  { focus-column-left; }
            Mod+Right { focus-column-right; }
            Mod+Down  { focus-window-down; }
            Mod+Up    { focus-window-up; }

            // Kamoi Meta+Tab, quick press: straight back to the window you
            // came from, with nothing drawn. The hold-to-preview card grid
            // has no niri equivalent; the overview below is the nearest.
            Mod+Tab repeat=false { focus-window-previous; }
            Mod+O   repeat=false { toggle-overview; }

            Mod+Ctrl+H { move-column-left; }
            Mod+Ctrl+L { move-column-right; }
            Mod+Ctrl+J { move-window-down; }
            Mod+Ctrl+K { move-window-up; }
            Mod+Ctrl+Left  { move-column-left; }
            Mod+Ctrl+Right { move-column-right; }

            Mod+Home { focus-column-first; }
            Mod+End  { focus-column-last; }

            // Workspaces. Kamoi views its strip one page at a time and
            // reaches the rest with a three-finger swipe; niri stacks
            // workspaces vertically.
            Mod+Page_Down { focus-workspace-down; }
            Mod+Page_Up   { focus-workspace-up; }
            Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
            Mod+Ctrl+Page_Up   { move-column-to-workspace-up; }
            Mod+Shift+Page_Down { move-workspace-down; }
            Mod+Shift+Page_Up   { move-workspace-up; }

            Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
            Mod+WheelScrollUp   cooldown-ms=150 { focus-workspace-up; }
            Mod+WheelScrollRight { focus-column-right; }
            Mod+WheelScrollLeft  { focus-column-left; }

            //
            // GROUP 3: scale
            //
            // The interface scale sizes everything. Per-application zoom is
            // the application's own business, which is why Ctrl+= is absent.
            Mod+Equal hotkey-overlay-title="Interface scale up"   { spawn "${niri-scale}/bin/niri-scale" "up"; }
            Mod+Minus hotkey-overlay-title="Interface scale down" { spawn "${niri-scale}/bin/niri-scale" "down"; }
            Mod+0     hotkey-overlay-title="Interface scale 100%" { spawn "${niri-scale}/bin/niri-scale" "reset"; }

            // Kamoi previews the scale under the wheel and commits on
            // release. niri has no press-and-hold bind, so each detent
            // commits on its own.
            Mod+Shift+WheelScrollUp   cooldown-ms=50 { spawn "${niri-scale}/bin/niri-scale" "up"; }
            Mod+Shift+WheelScrollDown cooldown-ms=50 { spawn "${niri-scale}/bin/niri-scale" "down"; }
            Ctrl+Mod+WheelScrollUp    cooldown-ms=50 { spawn "${niri-scale}/bin/niri-scale" "fine-up"; }
            Ctrl+Mod+WheelScrollDown  cooldown-ms=50 { spawn "${niri-scale}/bin/niri-scale" "fine-down"; }

            //
            // Placeholder for Kamoi's omni bar, which is group 4 and not
            // built yet. fuzzel launches applications and nothing else.
            //
            Mod+Space { spawn "fuzzel"; }
            F1        { spawn "fuzzel"; }

            Print      { screenshot; }
            Ctrl+Print { screenshot-screen; }
            Alt+Print  { screenshot-window; }

            XF86MonBrightnessUp   allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "+10%"; }
            XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "10%-"; }
            XF86AudioRaiseVolume  allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+ -l 1.0"; }
            XF86AudioLowerVolume  allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05-"; }
            XF86AudioMute         allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
            XF86AudioMicMute      allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }
            XF86AudioPlay         allow-when-locked=true { spawn-sh "playerctl play-pause"; }
            XF86AudioNext         allow-when-locked=true { spawn-sh "playerctl next"; }
            XF86AudioPrev         allow-when-locked=true { spawn-sh "playerctl previous"; }

            Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
            Mod+Shift+P { power-off-monitors; }
            Mod+Shift+E { quit; }
            Ctrl+Alt+Delete { quit; }
        }
      '';
    };
}
