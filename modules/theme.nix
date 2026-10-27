# Publish one desktop appearance preference through dconf and the Settings
# portal. Ghostty follows that preference directly, while Quickshell reads the
# generated state file. Applications with explicit theme overrides can ignore
# the desktop preference.
#
# "Extra dark" is a second, separate preference in its own state file. Only
# the Quickshell top bar reads it: in dark mode it turns the bar black, for
# the OLED panel. The mode stays dark or light, so GTK, Ghostty and dconf do
# not see it.
let
  themes = builtins.fromJSON (builtins.readFile ./quickshell/themes.json);
  validFaces = registry: builtins.all (
    theme: builtins.elem (theme.pyxampFace or null) [ "platinum" "winamp" ]
  ) registry;
  themeNames = builtins.concatStringsSep "|" (map (theme: theme.id) themes);
  themeList = builtins.concatStringsSep "\n" (map (theme: "${theme.id}\t${theme.label}") themes);
  desktopThemeCommand =
    pkgs:
    assert validFaces themes;
    pkgs.writeShellApplication {
      name = "desktop-theme";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.dconf
        pkgs.quickshell
        pkgs.util-linux
      ];
      text = ''
        state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/mountainous"
        state_file="$state_dir/theme"
        extra_file="$state_dir/theme-extra"
        name_file="$state_dir/theme-name"

        # Serialize toggles and publish only complete files.
        mkdir -p "$state_dir"
        exec 9>"$state_dir/theme.lock"
        flock 9

        usage() {
          printf 'usage: desktop-theme dark|light|toggle|status|reapply\n' >&2
          printf '       desktop-theme set <theme>|list|picker\n' >&2
          printf '       desktop-theme apply <theme> dark|light on|off\n' >&2
          printf '       desktop-theme extra on|off|toggle|status\n' >&2
          exit 2
        }

        # A missing or unreadable file means off.
        read_extra() {
          if [ -r "$extra_file" ] && [ "$(tr -d '[:space:]' < "$extra_file")" = on ]; then
            printf 'on'
          else
            printf 'off'
          fi
        }

        write_extra() {
          printf '%s\n' "$1" > "$extra_file.new"
          mv -f "$extra_file.new" "$extra_file"
        }

        extra() {
          case "''${1:-}" in
            on|off) value="$1" ;;
            toggle)
              if [ "$(read_extra)" = on ]; then value=off; else value=on; fi
              ;;
            status)
              read_extra
              printf '\n'
              return
              ;;
            *) usage ;;
          esac
          write_extra "$value"
          changed=1
          printf '%s\n' "$value"
        }

        # The Platinum window title bars (modules/hyprland/titlebars.lua)
        # read the same files. Ask the running Hyprland to read them again.
        # Outside a Hyprland session, or on a host without the module, this
        # does nothing; the next config load reads the files anyway.
        titlebars() {
          if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl > /dev/null; then
            hyprctl eval 'local ok, t = pcall(require, "titlebars"); if ok then t.apply() end' > /dev/null 2>&1 || true
          fi
        }
        changed=0

        valid_theme() {
          case "$1" in ${themeNames}) return 0 ;; *) return 1 ;; esac
        }

        read_name() {
          value=""
          if [ -r "$name_file" ]; then value=$(tr -d '[:space:]' < "$name_file"); fi
          if valid_theme "$value"; then printf '%s' "$value"; else printf platinum; fi
        }

        write_name() {
          printf '%s\n' "$1" > "$name_file.new"
          mv -f "$name_file.new" "$name_file"
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
          dark) apply dark; changed=1 ;;
          light) apply light; changed=1 ;;
          toggle)
            if [ "$(read_state)" = dark ]; then
              apply light
            else
              apply dark
            fi
            changed=1
            ;;
          # Also writes the extra file, so the bar has a file to watch.
          reapply)
            write_name "$(read_name)"
            write_extra "$(read_extra)"
            apply "$(read_state)"
            changed=1
            ;;
          set)
            if [ "$#" -ne 2 ] || ! valid_theme "$2"; then usage; fi
            write_name "$2"
            changed=1
            printf '%s\n' "$2"
            ;;
          list) printf '%s\n' '${themeList}' ;;
          picker)
            flock -u 9
            qs -c mountainous ipc call themePicker open
            ;;
          apply)
            if [ "$#" -ne 4 ] || ! valid_theme "$2"; then usage; fi
            case "$3" in dark|light) ;; *) usage ;; esac
            case "$4" in on|off) ;; *) usage ;; esac
            # Apply the session first: a failed dconf write must not publish
            # a new theme. All three preferences share this lock.
            apply "$3"
            write_extra "$4"
            write_name "$2"
            changed=1
            ;;
          extra) extra "''${2:-}" ;;
          status)
            printf 'mode=%s extra=%s theme=%s\n' "$(read_state)" "$(read_extra)" "$(read_name)"
            ;;
          *) usage ;;
        esac
        if [ "$changed" = 1 ]; then titlebars; fi
      '';
    };
in {
  # The packaged switcher in a private D-Bus session with a real dconf:
  # mode, the extra-dark file, toggles, reapply and a missing file.
  perSystem = {pkgs, ...}: {
    # Native CLI target for headless checks on each flake system. The NixOS
    # module below uses the same factory for the installed command.
    packages.desktop-theme = desktopThemeCommand pkgs;
    checks.desktop-theme =
      assert validFaces themes;
      assert !(validFaces [ { id = "missing"; } ]);
      assert !(validFaces [ { id = "invalid"; pyxampFace = "unknown"; } ]);
      pkgs.runCommand "desktop-theme" {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.dbus
          pkgs.dconf
        ];
        DBUS_SESSION_CONFIG = "${pkgs.dbus}/share/dbus-1/session.conf";
      } ''
        bash ${../scripts/test-desktop-theme} ${desktopThemeCommand pkgs}/bin/desktop-theme
        touch $out
      '';
  };

  nixos.modules.desktop = {pkgs, ...}: let
    desktop-theme = desktopThemeCommand pkgs;

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
