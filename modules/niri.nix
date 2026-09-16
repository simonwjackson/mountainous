# One feature, one file. The compositor, its session, and its dotfile.
#
# This is the shape every later feature copies: the system half and the
# $HOME half sit together, because they are the same decision.
#
# Note on config.kdl: niri does NOT merge a user config with its shipped
# default. Whatever is in this file is the complete set of keybinds. An
# earlier version of this file had six binds and no way to list them.
{
  nixos.modules.desktop =
    { pkgs, ... }:
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
        playerctl # media keys
      ];

      hjem.users.simon.files.".config/niri/config.kdl".text = ''
        // Built-in panel is 2880x1800 on a 16" screen, about 212 PPI.
        // At scale 1 the UI is unreadable. 1.5 gives a logical 1920x1200.
        output "eDP-1" {
            mode "2880x1800"
            scale 1.5
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
            }
        }

        layout {
            gaps 12
            default-column-width { proportion 0.5; }
            focus-ring {
                width 3
                active-color "#7fc8ff"
            }
        }

        hotkey-overlay {
            // Leave the "Important Hotkeys" pop-up on at startup. It is the
            // only discoverable surface on a fresh install.
        }

        binds {
            // THE help menu. Mod is Super on a TTY.
            Mod+Shift+Slash { show-hotkey-overlay; }

            Mod+Return hotkey-overlay-title="Terminal: alacritty" { spawn "alacritty"; }
            Mod+T      hotkey-overlay-title="Terminal: alacritty" { spawn "alacritty"; }
            Mod+D      hotkey-overlay-title="Launcher: fuzzel"    { spawn "fuzzel"; }

            Mod+O repeat=false { toggle-overview; }
            Mod+Q repeat=false { close-window; }

            // Focus
            Mod+Left  { focus-column-left; }
            Mod+Right { focus-column-right; }
            Mod+Up    { focus-window-up; }
            Mod+Down  { focus-window-down; }
            Mod+H     { focus-column-left; }
            Mod+L     { focus-column-right; }
            Mod+K     { focus-window-up; }
            Mod+J     { focus-window-down; }

            // Move
            Mod+Ctrl+Left  { move-column-left; }
            Mod+Ctrl+Right { move-column-right; }
            Mod+Ctrl+Up    { move-window-up; }
            Mod+Ctrl+Down  { move-window-down; }

            // Workspaces
            Mod+Page_Down { focus-workspace-down; }
            Mod+Page_Up   { focus-workspace-up; }
            Mod+U         { focus-workspace-down; }
            Mod+I         { focus-workspace-up; }
            Mod+1 { focus-workspace 1; }
            Mod+2 { focus-workspace 2; }
            Mod+3 { focus-workspace 3; }
            Mod+4 { focus-workspace 4; }
            Mod+5 { focus-workspace 5; }

            // Sizing
            Mod+R       { switch-preset-column-width; }
            Mod+F       { maximize-column; }
            Mod+Shift+F { fullscreen-window; }
            Mod+C       { center-column; }
            Mod+Minus   { set-column-width "-10%"; }
            Mod+Equal   { set-column-width "+10%"; }
            Mod+V       { toggle-window-floating; }
            Mod+W       { toggle-column-tabbed-display; }
            Mod+BracketLeft  { consume-or-expel-window-left; }
            Mod+BracketRight { consume-or-expel-window-right; }

            // Screenshots
            Print      { screenshot; }
            Ctrl+Print { screenshot-screen; }
            Alt+Print  { screenshot-window; }

            // Laptop hardware keys. brightnessctl comes from galaxy-book3.
            XF86MonBrightnessUp   allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "+10%"; }
            XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "10%-"; }
            XF86AudioRaiseVolume  allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+ -l 1.0"; }
            XF86AudioLowerVolume  allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05-"; }
            XF86AudioMute         allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
            XF86AudioMicMute      allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }
            XF86AudioPlay         allow-when-locked=true { spawn-sh "playerctl play-pause"; }
            XF86AudioNext         allow-when-locked=true { spawn-sh "playerctl next"; }
            XF86AudioPrev         allow-when-locked=true { spawn-sh "playerctl previous"; }

            // Escape hatches
            Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
            Mod+Shift+P { power-off-monitors; }
            Mod+Shift+E { quit; }
            Ctrl+Alt+Delete { quit; }
        }
      '';
    };
}
