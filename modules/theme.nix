# The three watched state files drive the bar, title bars, web and native apps.
# Toolkit files are generated outputs, never a second preference store.
{ inputs, ... }:
let
  themes = builtins.fromJSON (builtins.readFile ./quickshell/themes.json);
  validFaces =
    registry:
    builtins.all (
      theme:
      builtins.elem (theme.pyxampFace or null) [
        "platinum"
        "winamp"
      ]
    ) registry;
  # Both ct plugins accept qt5ct and ignore QPA arguments. The argument
  # avoids OBS's obsolete exact-string qt5ct blacklist without changing
  # Qt's plugin selection. A theme is one key, not a semicolon list.
  qtPlatformTheme = "qt5ct:mountainous";
  themeNames = builtins.concatStringsSep "|" (map (theme: theme.id) themes);
  themeList = builtins.concatStringsSep "\n" (map (theme: "${theme.id}\t${theme.label}") themes);
  ghosttyRootConfig =
    pkgs:
    pkgs.writeText "ghostty-config" ''
      # desktop-theme reapply creates this before Quickshell starts.
      config-file = ?mountainous.conf
    '';
  desktopThemeCommand =
    pkgs:
    assert validFaces themes;
    let
      nativeThemes = import ../lib/native-themes.nix { inherit pkgs inputs; };
    in
    pkgs.writeShellApplication {
      name = "desktop-theme";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.dconf
        pkgs.glib
        pkgs.python3
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
          printf '       desktop-theme rollback <failed-theme> <fallback-theme>\n' >&2
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
          apply "$(read_state)" "$(read_name)" "$value" > /dev/null
          changed=1
          printf '%s\n' "$value"
        }

        # The Platinum window title bars (modules/hyprland/titlebars.lua)
        # read the same files. Ask the running Hyprland to read them again.
        # Outside a Hyprland session, or on a host without the module, this
        # does nothing; the next config load reads the files anyway.
        titlebars() {
          if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl > /dev/null; then
            hyprctl --instance 0 eval 'local ok, t = pcall(require, "titlebars"); if ok then t.apply() end' > /dev/null 2>&1 || true
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
          value=""
          if [ -r "$state_file" ]; then value=$(tr -d '[:space:]' < "$state_file"); fi
          case "$value" in light) printf light ;; *) printf dark ;; esac
        }

        apply_native() {
          mode="$1"
          name="''${2:-$(read_name)}"
          extra_value="''${3:-$(read_extra)}"
          appearance="$mode"
          if [ "$name" = platinum ] && [ "$mode" = dark ] && [ "$extra_value" = on ]; then appearance=extra; fi
          gtk_theme="Mountainous-$name-$appearance"
          if [ "$mode" = light ]; then scheme=prefer-light; else mode=dark; scheme=prefer-dark; fi
          if [ "$name" = platinum ]; then font=ChicagoFLF; else font='W95FA Grid'; fi

          # Explicit returns also stop on failure when recovery calls this
          # function in a conditional (where Bash disables errexit).
          dconf write /org/gnome/desktop/interface/color-scheme "'$scheme'" || return
          dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'" || return
          dconf write /org/gnome/desktop/interface/font-name "'$font 12'" || return
          python3 ${../scripts/apply-native-theme.py} ${nativeThemes} "$name" "$mode" "$extra_value"
        }

        apply() {
          # Ordinary changes publish only after native synchronisation.
          apply_native "$@" || return
          printf '%s\n' "$mode" > "$state_file.new"
          mv -f "$state_file.new" "$state_file"
          write_extra "$extra_value"
          write_name "$name"
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
            apply "$(read_state)"
            changed=1
            ;;
          set)
            if [ "$#" -ne 2 ] || ! valid_theme "$2"; then usage; fi
            apply "$(read_state)" "$2" "$(read_extra)" > /dev/null
            changed=1
            printf '%s\n' "$2"
            ;;
          rollback)
            if [ "$#" -ne 3 ] || ! valid_theme "$3"; then usage; fi
            # Compare the raw stored ID: a rejected fixture/new theme may
            # not be in this command's registry. Ignore stale callbacks.
            saved_name=""
            if [ -r "$name_file" ]; then saved_name=$(tr -d '[:space:]' < "$name_file"); fi
            if [ "$saved_name" = "$2" ]; then
              # Chrome recovery must not depend on D-Bus or toolkit files.
              # Preserve mode/Extra dark; publish the known-good name first.
              write_name "$3"
              changed=1
              if ! apply_native "$(read_state)" "$3" "$(read_extra)"; then
                printf 'desktop-theme: restored %s; native settings may lag; run desktop-theme reapply\n' "$3" >&2
              fi
            fi
            printf '%s\n' "$(read_name)"
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
            apply "$3" "$2" "$4"
            changed=1
            ;;
          extra) extra "''${2:-}" ;;
          status)
            printf 'mode=%s extra=%s theme=%s\n' "$(read_state)" "$(read_extra)" "$(read_name)"
            ;;
          *) usage ;;
        esac
        if [ "$changed" = 1 ]; then
          titlebars
          # Ghostty exposes the GTK application action on this session's bus.
          # No process scan, signals, synthetic keys or window focus changes.
          # Absent Ghostty is normal. Other GTK4 apps need a restart to reread
          # their user CSS; named GTK3 themes follow dconf live.
          # NameHasOwner does not auto-activate Ghostty. A theme change
          # must never launch a terminal that the user has not opened.
          if [ "$(gdbus call --session --dest org.freedesktop.DBus \
              --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.NameHasOwner \
              com.mitchellh.ghostty 2>/dev/null)" = '(true,)' ]; then
            gdbus call --session --dest com.mitchellh.ghostty \
              --object-path /com/mitchellh/ghostty --method org.gtk.Actions.Activate \
              reload-config '[]' '{}' > /dev/null 2>&1 || true
          fi
        fi
      '';
    };
in
{
  # The packaged switcher in a private D-Bus session with a real dconf:
  # mode, the extra-dark file, toggles, reapply and a missing file.
  perSystem = { pkgs, config, ... }: {
    # Native CLI target for headless checks on each flake system. The NixOS
    # module below uses the same factory for the installed command.
    packages.desktop-theme = desktopThemeCommand pkgs;
    packages.desktop-native-themes = import ../lib/native-themes.nix { inherit pkgs inputs; };
    checks.native-themes =
      let
        qt5Probe = import ../lib/native-qt-probe.nix {
          inherit pkgs qtPlatformTheme;
          qt = pkgs.libsForQt5;
          ct = pkgs.libsForQt5.qt5ct;
          kvantum = pkgs.libsForQt5.qtstyleplugin-kvantum;
          name = "native-qt5-probe";
        };
        qt6Probe = import ../lib/native-qt-probe.nix {
          inherit pkgs qtPlatformTheme;
          qt = pkgs.qt6Packages;
          ct = pkgs.qt6Packages.qt6ct;
          kvantum = pkgs.qt6Packages.qtstyleplugin-kvantum;
          name = "native-qt6-probe";
        };
      in
      pkgs.runCommand "native-themes"
        {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.dbus
            pkgs.dconf
            pkgs.gnugrep
            (pkgs.python3.withPackages (p: [ p.pillow ]))
            pkgs.ghostty
            pkgs.libsForQt5.qt5ct
            pkgs.qt6Packages.qt6ct
            pkgs.libsForQt5.qtstyleplugin-kvantum
            pkgs.qt6Packages.qtstyleplugin-kvantum
          ];
          DBUS_SESSION_CONFIG = "${pkgs.dbus}/share/dbus-1/session.conf";
          FONTCONFIG_FILE = pkgs.makeFontsConf {
            fontDirectories = [
              config.packages.chicagoflf
              config.packages.w95fa-grid
            ];
          };
          GHOSTTY_ROOT_CONFIG = ghosttyRootConfig pkgs;
          OBS_LIBRARY = "${pkgs.obs-studio}/lib/libobs.so";
          NATIVE_OBS_PROBE = ../tests/native-obs.py;
          NATIVE_QT5_PROBE = "${qt5Probe}/bin/native-qt-probe";
          NATIVE_QT6_PROBE = "${qt6Probe}/bin/native-qt-probe";
        }
        ''
          bash ${../scripts/test-native-themes} ${desktopThemeCommand pkgs}/bin/desktop-theme ${
            import ../lib/native-themes.nix { inherit pkgs inputs; }
          }
          native=${import ../lib/native-themes.nix { inherit pkgs inputs; }}
          python3 ${../tests/native-palettes.py} ${../scripts/generate-native-themes.py} ${./quickshell} "$native"
          export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config" XDG_STATE_HOME="$TMPDIR/state" XDG_CACHE_HOME="$TMPDIR/cache"
          mkdir -p "$HOME"
          for config in "$native"/share/mountainous/native/*/ghostty.conf; do
            ghostty +validate-config --config-file="$config"
          done
          touch $out
        '';
    checks.desktop-theme =
      assert validFaces themes;
      assert !(validFaces [ { id = "missing"; } ]);
      assert
        !(validFaces [
          {
            id = "invalid";
            pyxampFace = "unknown";
          }
        ]);
      pkgs.runCommand "desktop-theme"
        {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.dbus
            pkgs.dconf
          ];
          DBUS_SESSION_CONFIG = "${pkgs.dbus}/share/dbus-1/session.conf";
        }
        ''
          bash ${../scripts/test-desktop-theme} ${desktopThemeCommand pkgs}/bin/desktop-theme
          touch $out
        '';
  };

  nixos.modules.desktop =
    { pkgs, lib, ... }:
    let
      desktop-theme = desktopThemeCommand pkgs;

      nativeThemes = import ../lib/native-themes.nix { inherit pkgs inputs; };
      ghosttyConfig = ghosttyRootConfig pkgs;

    in
    {
      # Direct build targets let regression tests exercise the packaged command
      # and inspect the exact Ghostty configuration delivered by hjem.
      system.build.desktopTheme = desktop-theme;
      system.build.nativeThemes = nativeThemes;
      system.build.ghosttyConfig = pkgs.linkFarm "mountainous-ghostty-config" [
        {
          name = "ghostty/config.ghostty";
          path = ghosttyConfig;
        }
      ];

      # qt5ct and qt6ct both implement the qt5ct platform key. OBS removes
      # the bare key; the supported QPA-argument form above keeps it intact.
      # Do not set QT_STYLE_OVERRIDE; the choice belongs in the qtct files.
      qt.enable = true;
      environment.variables.QT_QPA_PLATFORMTHEME = lib.mkDefault qtPlatformTheme;

      environment.systemPackages = [
        desktop-theme
        nativeThemes
        pkgs.libsForQt5.qt5ct
        pkgs.qt6Packages.qt6ct
        pkgs.libsForQt5.qtstyleplugin-kvantum
        pkgs.qt6Packages.qtstyleplugin-kvantum
        # gsettings is the documented front end to the same dconf keys the
        # switcher writes. dconf alone is enough for the script; gsettings is
        # there so the keys can be read and set by hand.
        pkgs.glib
      ];

      # Restore the saved preference and create the watched file before the bars.
      systemd.user.services.desktop-theme = {
        description = "Apply the saved desktop appearance";
        wantedBy = [ "hyprland-session.target" ];
        partOf = [ "graphical-session.target" ];
        before = [ "quickshell.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${desktop-theme}/bin/desktop-theme reapply";
          RemainAfterExit = true;
          TimeoutStartSec = 15;
        };
      };

      hjem.users.simon.files = {
        ".config/ghostty/config.ghostty".source = ghosttyConfig;
      };
    };
}
