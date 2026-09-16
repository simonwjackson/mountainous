# One feature, one file. The compositor, its session, and its dotfile.
#
# This is the shape every later feature copies: the system half and the
# $HOME half sit together, because they are the same decision.
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
      ];

      hjem.users.simon.files.".config/niri/config.kdl".text = ''
        input {
            keyboard {
                xkb {
                    layout "us"
                }
            }
            touchpad {
                tap
                natural-scroll
            }
        }

        binds {
            Mod+Return { spawn "alacritty"; }
            Mod+D      { spawn "fuzzel"; }
            Mod+Q      { close-window; }
            Mod+Left   { focus-column-left; }
            Mod+Right  { focus-column-right; }
            Mod+Shift+E { quit; }
        }
      '';
    };
}
