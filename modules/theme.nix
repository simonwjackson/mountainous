# The watched state files drive the bar, title bars, web and native apps.
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
  # Each theme's icon and cursor themes (themes.json "art"), as shell cases.
  artCases = builtins.concatStringsSep "\n" (
    map (
      theme:
      "${theme.id}) icons=${theme.art.icons}; cursors=${theme.art.cursors}; cursor_size=${toString theme.art.cursorSize} ;;"
    ) themes
  );
  appearanceCases = builtins.concatStringsSep "\n" (
    builtins.concatMap (
      theme:
      map (appearance: "${theme.id}:${appearance.id}) printf '${appearance.mode}' ;;") theme.appearances
    ) themes
  );
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
      desktopArt = import ../lib/desktop-art.nix { inherit pkgs inputs; };
    in
    pkgs.writeShellApplication {
      name = "desktop-theme";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.dconf
        pkgs.glib
        (pkgs.python3.withPackages (p: [ p.pygobject3 ]))
        # The session's Quickshell (lib/quickshell.nix), so Myoko carries one.
        (import ../lib/quickshell.nix { inherit pkgs; })
        pkgs.util-linux
      ];
      text = ''
        state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/mountainous"
        state_file="$state_dir/theme"
        extra_file="$state_dir/theme-extra"
        name_file="$state_dir/theme-name"
        appearance_file="$state_dir/theme-appearance"
        sounds_file="$state_dir/theme-sounds"

        # Serialize toggles and publish only complete files.
        mkdir -p "$state_dir"
        exec 9>"$state_dir/theme.lock"
        flock 9

        usage() {
          printf 'usage: desktop-theme dark|light|toggle|status|reapply\n' >&2
          printf '       desktop-theme set <theme>|list|picker\n' >&2
          printf '       desktop-theme apply <theme> <appearance-id> on|off\n' >&2
          printf '       desktop-theme rollback <failed-theme> <fallback-theme>\n' >&2
          printf '       desktop-theme extra on|off|toggle|status\n' >&2
          printf '       desktop-theme sounds on|off|toggle|status\n' >&2
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

        # A missing file means on; only explicit off disables the sound bank.
        read_sounds() {
          if [ -r "$sounds_file" ] && [ "$(tr -d '[:space:]' < "$sounds_file")" = off ]; then
            printf off
          else
            printf on
          fi
        }

        sounds() {
          case "''${1:-}" in
            on|off) value="$1" ;;
            toggle) if [ "$(read_sounds)" = on ]; then value=off; else value=on; fi ;;
            status) read_sounds; printf '\n'; return ;;
            *) usage ;;
          esac
          printf '%s\n' "$value" > "$sounds_file.new"
          mv -f "$sounds_file.new" "$sounds_file"
          printf '%s\n' "$value"
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
        # Sets icons, cursors and cursor_size for a theme (themes.json "art").
        art_names() {
          case "$1" in
        ${artCases}
          esac
        }

        # Hyprland draws the pointer for every client that uses the cursor
        # shape protocol (GTK4, Qt 6, Chromium). setcursor switches it live;
        # hyprland.lua reads the same choice at login. Hyprland 0.56 redraws
        # the pointer only when its shape name changes, so it is hidden for
        # one cursor tick (500 ms): showing it again reloads the current
        # shape from the new theme. Never left hidden: both calls run here.
        cursors() {
          if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl > /dev/null; then
            art_names "$(read_name)"
            if hyprctl --instance 0 setcursor "$cursors" "$cursor_size" > /dev/null 2>&1; then
              hyprctl --instance 0 eval 'hl.config({ cursor = { invisible = true } })' > /dev/null 2>&1 || true
              sleep 0.6
              hyprctl --instance 0 eval 'hl.config({ cursor = { invisible = false } })' > /dev/null 2>&1 || true
            fi
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

        read_mode() {
          value=""
          if [ -r "$state_file" ]; then value=$(tr -d '[:space:]' < "$state_file"); fi
          case "$value" in light) printf light ;; *) printf dark ;; esac
        }

        # Old light/dark callers remain aliases, not new saved identifiers.
        default_appearance() {
          if [ "$2" = dark ]; then printf dark-grey
          elif [ "$1" = memphis ]; then printf standard
          else printf light; fi
        }
        appearance_mode() {
          case "$1:$2" in
        ${appearanceCases}
            *) return 1 ;;
          esac
        }
        resolve_appearance() {
          case "$2" in
            dark|light) default_appearance "$1" "$2" ;;
            *) appearance_mode "$1" "$2" > /dev/null || return 1; printf '%s' "$2" ;;
          esac
        }
        read_appearance() {
          local saved=""
          if [ -r "$appearance_file" ]; then saved=$(tr -d '[:space:]' < "$appearance_file"); fi
          if appearance_mode "$1" "$saved" > /dev/null; then printf '%s' "$saved"
          else default_appearance "$1" "$(read_mode)"; fi
        }
        read_state() {
          local theme
          theme=$(read_name)
          appearance_mode "$theme" "$(read_appearance "$theme")"
        }
        write_appearance() {
          printf '%s\n' "$1" > "$appearance_file.new"
          mv -f "$appearance_file.new" "$appearance_file"
        }
        native_appearance() {
          case "$2" in standard|light) printf light ;; dark-grey)
            if [ "$1" = platinum ] && [ "$3" = on ]; then printf extra; else printf dark; fi ;;
            *) printf '%s' "$2" ;;
          esac
        }

        apply_native() {
          mode="$1"
          name="''${2:-$(read_name)}"
          extra_value="''${3:-$(read_extra)}"
          appearance_choice="''${4:-$(read_appearance "$name")}"
          mode=$(appearance_mode "$name" "$appearance_choice") || return
          appearance=$(native_appearance "$name" "$appearance_choice" "$extra_value")
          gtk_theme="Mountainous-$name-$appearance"
          if [ "$mode" = light ]; then scheme=prefer-light; else mode=dark; scheme=prefer-dark; fi
          if [ "$name" = platinum ]; then font=ChicagoFLF; else font='W95FA Grid'; fi

          # Explicit returns also stop on failure when recovery calls this
          # function in a conditional (where Bash disables errexit).
          dconf write /org/gnome/desktop/interface/color-scheme "'$scheme'" || return
          dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'" || return
          dconf write /org/gnome/desktop/interface/font-name "'$font 12'" || return
          art_names "$name"
          dconf write /org/gnome/desktop/interface/icon-theme "'$icons'" || return
          dconf write /org/gnome/desktop/interface/cursor-theme "'$cursors'" || return
          dconf write /org/gnome/desktop/interface/cursor-size "$cursor_size" || return
          python3 ${../scripts/apply-native-theme.py} ${nativeThemes} "$name" "$mode" "$extra_value" --appearance "$appearance_choice" --art ${desktopArt}
        }

        apply() {
          # Ordinary changes publish only after native synchronisation.
          apply_native "$@" || return
          printf '%s\n' "$mode" > "$state_file.new"
          mv -f "$state_file.new" "$state_file"
          write_extra "$extra_value"
          write_name "$name"
          # Migrate only missing keys. Unknown future IDs survive reapply,
          # Extra dark and theme switches until an explicit choice replaces them.
          if [ ! -e "$appearance_file" ] || [ "$#" -ge 4 ]; then write_appearance "$appearance_choice"; fi
          printf '%s\n' "$mode"
        }

        case "''${1:-toggle}" in
          dark|light)
            apply "$1" "$(read_name)" "$(read_extra)" "$(default_appearance "$(read_name)" "$1")"
            changed=1 ;;
          toggle)
            if [ "$(read_state)" = dark ]; then
              apply light "$(read_name)" "$(read_extra)" "$(default_appearance "$(read_name)" light)"
            else
              apply dark "$(read_name)" "$(read_extra)" dark-grey
            fi
            changed=1
            ;;
          # Also writes the extra file, so the bar has a file to watch.
          reapply)
            apply "$(read_state)"
            sounds "$(read_sounds)" > /dev/null
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
              printf '%s\n' "$(read_state)" > "$state_file.new"
              mv -f "$state_file.new" "$state_file"
              if [ ! -e "$appearance_file" ]; then write_appearance "$(read_appearance "$3")"; fi
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
            selected=$(resolve_appearance "$2" "$3") || usage
            case "$4" in on|off) ;; *) usage ;; esac
            # Apply the session first: a failed dconf write must not publish
            # a new theme. All three preferences share this lock.
            apply "$(appearance_mode "$2" "$selected")" "$2" "$4" "$selected"
            changed=1
            ;;
          extra) extra "''${2:-}" ;;
          sounds) if [ "$#" -ne 2 ]; then usage; fi; sounds "$2" ;;
          status)
            printf 'mode=%s extra=%s theme=%s\n' "$(read_state)" "$(read_extra)" "$(read_name)"
            ;;
          *) usage ;;
        esac
        if [ "$changed" = 1 ]; then
          titlebars
          cursors
          # Unique bus connections cover default, custom-class and NON_UNIQUE
          # applications. The helper never auto-activates a missing terminal.
          python3 ${../scripts/reload-ghostty.py} || true
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
        kitPalettes = import ../lib/kit-palettes.nix {
          inherit pkgs;
          kit = inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml;
        };
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
            pkgs.nodejs
          ];
          DBUS_SESSION_CONFIG = "${pkgs.dbus}/share/dbus-1/session.conf";
          SCHEMES_JSON = ../scripts/system-colour-schemes.json;
          KIT_PALETTES = kitPalettes;
          # Phase 4: icons, cursors and the desktop pattern, asserted after
          # every set, toggle and reapply in scripts/test-native-themes.
          DESKTOP_ART = import ../lib/desktop-art.nix { inherit pkgs inputs; };
          DESKTOP_PATTERN_TEST = "${./quickshell}/desktop-art.test.js";
          DESKTOP_PATTERN_JS = "${./quickshell}/desktop-art.js";
          THEMES_JSON = "${./quickshell}/themes.json";
          FONTCONFIG_FILE = pkgs.makeFontsConf {
            fontDirectories = [
              config.packages.chicagoflf
              config.packages.w95fa-grid
              config.packages.terminal-fonts
              pkgs.dejavu_fonts
              pkgs.nerd-fonts.symbols-only
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
          python3 ${../tests/native-palettes.py} ${../scripts/generate-native-themes.py} ${kitPalettes} "$native"
          python3 ${../tests/desktop-art.py} "$DESKTOP_ART" "$THEMES_JSON" ${./web-apps.json} ${./web-app-pwas.json}
          node "$DESKTOP_PATTERN_TEST" "$DESKTOP_PATTERN_JS" "$THEMES_JSON"
          export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config" XDG_STATE_HOME="$TMPDIR/state" XDG_CACHE_HOME="$TMPDIR/cache"
          mkdir -p "$HOME"
          for config in "$native"/share/mountainous/native/*/ghostty.conf; do
            ghostty +validate-config --config-file="$config"
          done
          touch $out
        '';
    checks.desktop-appearances =
      pkgs.runCommand "desktop-appearances"
        {
          nativeBuildInputs = [ pkgs.nodejs ];
          KIT_PALETTES = import ../lib/kit-palettes.nix {
            inherit pkgs;
            kit = inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml;
          };
          SCHEMES_JSON = ../scripts/system-colour-schemes.json;
          HENSOU_QML_ROOT = "${
            inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
          }/lib/qt-6/qml";
        }
        ''
          node ${./quickshell/desktop-art.test.js} ${./quickshell/desktop-art.js} ${./quickshell}/themes.json
          node ${./quickshell/web-theme.test.js} ${./quickshell/web-theme.js} ${./quickshell/web-theme-page.js} ${./quickshell}
          touch $out
        '';
    checks.desktop-appearance-surface =
      pkgs.runCommand "desktop-appearance-surface"
        {
          nativeBuildInputs = [
            (pkgs.python3.withPackages (p: [ p.pillow ]))
            pkgs.quickshell
            pkgs.labwc
            pkgs.grim
          ];
          SCHEMES_JSON = ../scripts/system-colour-schemes.json;
          QML2_IMPORT_PATH = "${pkgs.qt6.qtwebsockets}/lib/qt-6/qml:${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
          QML_IMPORT_PATH = "${pkgs.qt6.qtwebsockets}/lib/qt-6/qml:${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
          FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
        }
        ''
          export NOTIFICATION_SCHEMA_JS="$TMPDIR/notification-schema.js"
          bash ${./quickshell/notification-schema-js.sh} ${../packages/notify-sync/schema/ui-socket.v1.json} > "$NOTIFICATION_SCHEMA_JS"
          python3 ${../scripts/test-theme-appearance-host.py} ${./quickshell} \
            ${inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml}/lib/qt-6/qml \
            ${pkgs.quickshell}/bin/qs ${pkgs.labwc}/bin/labwc
          touch $out
        '';
    checks.theme-appearance-host =
      pkgs.runCommand "theme-appearance-host"
        {
          nativeBuildInputs = [
            pkgs.python3
            pkgs.quickshell
          ];
        }
        ''
          python3 ${../scripts/test-theme-appearance-host.py} ${./quickshell} \
            ${inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml}/lib/qt-6/qml \
            ${pkgs.quickshell}/bin/qs
          touch $out
        '';
    checks.ghostty-reload =
      pkgs.runCommand "ghostty-reload"
        {
          nativeBuildInputs = [
            pkgs.dbus
            (pkgs.python3.withPackages (p: [ p.pygobject3 ]))
          ];
        }
        ''
          dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- python3 ${../tests/ghostty-reload.py} ${../scripts/reload-ghostty.py}
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
          export THEMES_JSON=${./quickshell/themes.json}
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
