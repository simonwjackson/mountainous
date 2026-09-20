# Publish one desktop appearance preference through dconf and the Settings
# portal. Ghostty follows that preference directly, while Quickshell reads the
# generated state file. Applications with explicit theme overrides can ignore
# the desktop preference.
{
  nixos.modules.desktop = {pkgs, ...}: let
    ghosttyDark = pkgs.writeText "mountainous-dark" ''
      background = 000000
      foreground = e0e0e0
      cursor-color = 6a9fb5
      cursor-text = 000000
      selection-foreground = cell-foreground
      selection-background = 2a2a2a
      palette = 0=141414
      palette = 1=e06c75
      palette = 2=98c379
      palette = 3=e5c07b
      palette = 4=61afef
      palette = 5=c678dd
      palette = 6=56b6c2
      palette = 7=e0e0e0
      palette = 8=606060
      palette = 9=e06c75
      palette = 10=98c379
      palette = 11=e5c07b
      palette = 12=61afef
      palette = 13=c678dd
      palette = 14=56b6c2
      palette = 15=ffffff
    '';

    ghosttyLight = pkgs.writeText "mountainous-light" ''
      background = f5f5f5
      foreground = 1a1a1a
      cursor-color = 3d7a94
      cursor-text = f5f5f5
      selection-foreground = cell-foreground
      selection-background = d8d8d8
      palette = 0=1a1a1a
      palette = 1=b3261e
      palette = 2=2e7d32
      palette = 3=8a6d00
      palette = 4=1f5fa8
      palette = 5=8e24aa
      palette = 6=00695c
      palette = 7=3a3a3a
      palette = 8=606060
      palette = 9=c62828
      palette = 10=388e3c
      palette = 11=a07800
      palette = 12=2962a8
      palette = 13=9c27b0
      palette = 14=00897b
      palette = 15=1a1a1a
    '';

    ghosttyConfig = pkgs.writeText "ghostty-config" ''
      theme = light:mountainous-light,dark:mountainous-dark
      window-theme = system
    '';

    desktop-theme = pkgs.writeShellApplication {
      name = "desktop-theme";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.dconf
        pkgs.util-linux
      ];
      text = ''
        state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/mountainous"
        state_file="$state_dir/theme"

        # Serialize toggles and publish only complete files.
        mkdir -p "$state_dir"
        exec 9>"$state_dir/theme.lock"
        flock 9

        usage() {
          printf 'usage: desktop-theme dark|light|toggle|status|reapply\n' >&2
          exit 2
        }

        read_state() {
          if [ -r "$state_file" ]; then
            tr -d '[:space:]' < "$state_file"
          else
            printf 'dark'
          fi
        }

        apply() {
          mode="$1"

          if [ "$mode" = light ]; then
            scheme=prefer-light
            gtk_theme=Adwaita
          else
            mode=dark
            scheme=prefer-dark
            gtk_theme=Adwaita-dark
          fi

          # Do not report success if the session preference could not change.
          # Ghostty, GTK, Chromium, Qt and Electron all follow this preference.
          dconf write /org/gnome/desktop/interface/color-scheme "'$scheme'"
          dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'"

          printf '%s\n' "$mode" > "$state_file.new"
          mv -f "$state_file.new" "$state_file"
          printf '%s\n' "$mode"
        }

        case "''${1:-toggle}" in
          dark) apply dark ;;
          light) apply light ;;
          toggle)
            if [ "$(read_state)" = dark ]; then
              apply light
            else
              apply dark
            fi
            ;;
          reapply) apply "$(read_state)" ;;
          status)
            read_state
            printf '\n'
            ;;
          *) usage ;;
        esac
      '';
    };
  in {
    # Direct build targets let regression tests exercise the packaged command
    # and inspect the exact Ghostty configuration delivered by hjem.
    system.build.desktopTheme = desktop-theme;
    system.build.ghosttyConfig = pkgs.linkFarm "mountainous-ghostty-config" [
      {
        name = "ghostty/config.ghostty";
        path = ghosttyConfig;
      }
      {
        name = "ghostty/themes/mountainous-dark";
        path = ghosttyDark;
      }
      {
        name = "ghostty/themes/mountainous-light";
        path = ghosttyLight;
      }
    ];

    environment.systemPackages = [
      desktop-theme
      # gsettings is the documented front end to the same dconf keys the
      # switcher writes. dconf alone is enough for the script; gsettings is
      # there so the keys can be read and set by hand.
      pkgs.glib
    ];

    # Restore the saved preference and create the watched file before the bars.
    systemd.user.services.desktop-theme = {
      description = "Apply the saved desktop appearance";
      wantedBy = ["hyprland-session.target"];
      partOf = ["graphical-session.target"];
      before = ["quickshell.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${desktop-theme}/bin/desktop-theme reapply";
        RemainAfterExit = true;
        TimeoutStartSec = 15;
      };
    };

    hjem.users.simon.files = {
      ".config/ghostty/config.ghostty".source = ghosttyConfig;
      ".config/ghostty/themes/mountainous-dark".source = ghosttyDark;
      ".config/ghostty/themes/mountainous-light".source = ghosttyLight;
    };
  };
}
