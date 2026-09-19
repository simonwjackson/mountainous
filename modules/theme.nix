# Publish the desktop preference through dconf and the Settings portal.
# Alacritty and Quickshell also consume generated user files. Applications
# with explicit theme overrides can ignore the desktop preference.
{
  nixos.modules.desktop = {pkgs, ...}: let
    alacrittyDark = pkgs.writeText "alacritty-dark.toml" ''
      [colors.primary]
      background = "#000000"
      foreground = "#e0e0e0"

      [colors.cursor]
      text = "#000000"
      cursor = "#6a9fb5"

      [colors.selection]
      text = "CellForeground"
      background = "#2a2a2a"

      [colors.normal]
      black = "#141414"
      red = "#e06c75"
      green = "#98c379"
      yellow = "#e5c07b"
      blue = "#61afef"
      magenta = "#c678dd"
      cyan = "#56b6c2"
      white = "#e0e0e0"

      [colors.bright]
      black = "#606060"
      red = "#e06c75"
      green = "#98c379"
      yellow = "#e5c07b"
      blue = "#61afef"
      magenta = "#c678dd"
      cyan = "#56b6c2"
      white = "#ffffff"
    '';

    alacrittyLight = pkgs.writeText "alacritty-light.toml" ''
      [colors.primary]
      background = "#f5f5f5"
      foreground = "#1a1a1a"

      [colors.cursor]
      text = "#f5f5f5"
      cursor = "#3d7a94"

      [colors.selection]
      text = "CellForeground"
      background = "#d8d8d8"

      [colors.normal]
      black = "#1a1a1a"
      red = "#b3261e"
      green = "#2e7d32"
      yellow = "#8a6d00"
      blue = "#1f5fa8"
      magenta = "#8e24aa"
      cyan = "#00695c"
      white = "#3a3a3a"

      [colors.bright]
      black = "#606060"
      red = "#c62828"
      green = "#388e3c"
      yellow = "#a07800"
      blue = "#2962a8"
      magenta = "#9c27b0"
      cyan = "#00897b"
      white = "#1a1a1a"
    '';

    themeDir = pkgs.runCommand "mountainous-themes" {} ''
      mkdir -p $out
      cp ${alacrittyDark} $out/alacritty-dark.toml
      cp ${alacrittyLight} $out/alacritty-light.toml
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
        alacritty_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/alacritty"
        themes="${themeDir}"

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
          mkdir -p "$alacritty_dir"

          if [ "$mode" = light ]; then
            scheme=prefer-light
            gtk_theme=Adwaita
            theme_file="$themes/alacritty-light.toml"
          else
            mode=dark
            scheme=prefer-dark
            gtk_theme=Adwaita-dark
            theme_file="$themes/alacritty-dark.toml"
          fi

          # Do not report success if the session preference could not change.
          dconf write /org/gnome/desktop/interface/color-scheme "'$scheme'"
          dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'"

          # Alacritty watches this file and reloads every open window.
          install -m 0644 "$theme_file" "$alacritty_dir/active-theme.toml.new"
          mv -f "$alacritty_dir/active-theme.toml.new" "$alacritty_dir/active-theme.toml"

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
    # A direct build target lets regression tests exercise the packaged command.
    system.build.desktopTheme = desktop-theme;

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

    # Only the import lives here. The imported file is the one the switcher
    # rewrites, so Alacritty reloads on change instead of on restart.
    hjem.users.simon.files.".config/alacritty/alacritty.toml".source = pkgs.writeText "alacritty.toml" ''
      [general]
      import = ["~/.config/alacritty/active-theme.toml"]
    '';
  };
}
