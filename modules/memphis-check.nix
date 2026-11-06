# The Memphis theme's controls (modules/quickshell/Memphis*.qml, assets in
# themes/memphis): qmllint with the qmldir Quickshell would write, then the
# test gallery under a real headless Quickshell, every page in both
# appearances, with the Start menu's keyboard and roll-out checks. The
# gallery and its scripts are not delivered; see themes/memphis/dev/.
{ inputs, ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      quickshell = ./quickshell;
      qmlPaths = builtins.concatStringsSep ":" [
        "${inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml}/lib/qt-6/qml"
        "${pkgs.quickshell}/lib/qt-6/qml"
        "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
        "${pkgs.qt6.qtbase}/lib/qt-6/qml"
        "${pkgs.qt6.qtmultimedia}/lib/qt-6/qml"
      ];
      # A private headless sway session for the real Memphis Desktop (no
      # output device): the tools and the environment its scripts need.
      sessionEnv = {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gnused
          pkgs.nodejs
          # The wrapped sway starts a D-Bus session; the sandbox has none.
          pkgs.sway-unwrapped
          pkgs.grim
          pkgs.wtype
          pkgs.quickshell
          # Reports its mapped layer-shell surfaces (switch.sh).
          pkgs.niri
          (pkgs.python3.withPackages (p: [ p.pywayland ]))
        ];
        # niri and Qt render with GL: Mesa's software rasteriser
        # (llvmpipe), found through these in the sandbox. Qt's own
        # software renderer would draw 1.5-scale lines unevenly, which
        # scales.sh would rightly fail.
        __EGL_VENDOR_LIBRARY_DIRS = "${pkgs.mesa}/share/glvnd/egl_vendor.d";
        LIBGL_DRIVERS_PATH = "${pkgs.mesa}/lib/dri";
        FONTCONFIG_FILE = pkgs.makeFontsConf {
          fontDirectories = [
            config.packages.w95fa-grid
            pkgs.dejavu_fonts
          ];
        };
        QML2_IMPORT_PATH = "${
          inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
        }/lib/qt-6/qml:${pkgs.qt6.qtwebsockets}/lib/qt-6/qml:${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
        WLR_PROTOCOL = "${pkgs.wlr-protocols}/share/wlr-protocols/unstable/wlr-virtual-pointer-unstable-v1.xml";
        WAYLAND_XML = "${pkgs.wayland-scanner.out}/share/wayland/wayland.xml";
      };
    in
    {
      # The Memphis Desktop itself: its pure policies, then the real
      # ThemeDesktop and MemphisDesktop over the production panel owners in a
      # private headless sway session (no output device). behaviour.sh runs
      # the approved mock's interaction checks with a virtual pointer and
      # keyboard; switch.sh switches Platinum and Memphis ten times with a menu,
      # cascade or the picker open and asserts the reserved edge (sway) and
      # the mapped layer surfaces (niri) after each swap, then rolls back a
      # broken Memphis; geometry.sh checks real control bounds at small sizes;
      # scales.sh checks 2-px bevels on outputs at scales 1.5 and 1. switch.sh
      # opens each theme's Fleet window or glance space before every swap,
      # and under Memphis also the window or taskbar menu, Shut Down Myoko,
      # System Properties, the Cool Switch or the volume pop-up; geometry.sh
      # checks those from 360x640 up. find.sh checks the Find window
      # (Super+P) and IE's Open dialog (Ctrl+L): keys, pointer, the omni
      # claim, and their bounds from 1920x1200 down to 360x640.
      checks.memphis-desktop = pkgs.runCommand "memphis-desktop" sessionEnv ''
        export HOME=$TMPDIR
        node ${quickshell}/themes/memphis/taskbar-plan.test.js ${quickshell}/themes/memphis/taskbar-plan.js
        node ${quickshell}/themes/memphis/models.test.js ${quickshell}/themes/memphis/tray-model.js ${quickshell}/themes/memphis/start-model.js
        node ${quickshell}/themes/memphis/fleet-plan.test.js ${quickshell}/themes/memphis/fleet-plan.js ${quickshell}/glance-plan.js \
          ${quickshell}/themes/memphis/tab-strip.js ${quickshell}/themes/memphis/host-icon.js
        node ${quickshell}/themes/memphis/find-plan.test.js ${quickshell}/themes/memphis/find-plan.js
        node ${quickshell}/themes/memphis/combo-plan.test.js ${quickshell}/themes/memphis/combo-plan.js
        node ${quickshell}/themes/memphis/picker-plan.test.js ${quickshell}/themes/memphis/picker-plan.js
        node ${quickshell}/themes/memphis/task-model.test.js ${quickshell}/themes/memphis/task-model.js \
          ${quickshell}/themes/memphis/session-model.js ${quickshell}/page-names.js
        bash ${quickshell}/notification-schema-js.sh ${../packages/notify-sync/schema/ui-socket.v1.json} > $TMPDIR/notification-schema.js
        export SESSION_SCHEMA=$TMPDIR/notification-schema.js
        bash ${quickshell}/theme-dev/memphis/behaviour.sh ${quickshell} $TMPDIR/behaviour
        bash ${quickshell}/theme-dev/memphis/switch.sh ${quickshell} $TMPDIR/switch
        bash ${quickshell}/theme-dev/memphis/geometry.sh ${quickshell} $TMPDIR/geometry
        bash ${quickshell}/theme-dev/memphis/scales.sh ${quickshell} $TMPDIR/scales
        bash ${quickshell}/theme-dev/memphis/find.sh ${quickshell} $TMPDIR/find
        touch $out
      '';
      # The Memphis Fleet window and glance space in the same session: fleet.sh
      # (behaviour, motion, every fixture, and the bounds from 360x640 to the
      # 2560x1600 tablet). Its own attribute, so each build stays short.
      checks.memphis-fleet = pkgs.runCommand "memphis-fleet" sessionEnv ''
        export HOME=$TMPDIR
        node ${quickshell}/themes/memphis/fleet-plan.test.js ${quickshell}/themes/memphis/fleet-plan.js ${quickshell}/glance-plan.js \
          ${quickshell}/themes/memphis/tab-strip.js ${quickshell}/themes/memphis/host-icon.js
        bash ${quickshell}/notification-schema-js.sh ${../packages/notify-sync/schema/ui-socket.v1.json} > $TMPDIR/notification-schema.js
        export SESSION_SCHEMA=$TMPDIR/notification-schema.js
        bash ${quickshell}/theme-dev/memphis/fleet.sh ${quickshell} $TMPDIR/fleet
        touch $out
      '';
      # The Memphis taskbar and session parity items in the same session:
      # taskbar.sh (minimized buttons, the window and taskbar menus, the
      # windows menu call, held Super+Tab, Lock, Shut Down Myoko, System
      # Properties, Documents and Favorites, the volume pop-up, and no page
      # number anywhere). Session commands and launches are logging stubs.
      # Its own attribute, so each build stays under the 15-minute step.
      checks.memphis-taskbar = pkgs.runCommand "memphis-taskbar" sessionEnv ''
        export HOME=$TMPDIR
        node ${quickshell}/themes/memphis/task-model.test.js ${quickshell}/themes/memphis/task-model.js \
          ${quickshell}/themes/memphis/session-model.js ${quickshell}/page-names.js
        node ${quickshell}/app-model.test.js ${quickshell}/app-model.js
        node ${quickshell}/window-hide.test.js ${quickshell}/window-hide.js
        node ${quickshell}/window-motion.test.js ${quickshell}/window-motion.js ${quickshell}/glance-plan.js
        bash ${quickshell}/notification-schema-js.sh ${../packages/notify-sync/schema/ui-socket.v1.json} > $TMPDIR/notification-schema.js
        export SESSION_SCHEMA=$TMPDIR/notification-schema.js
        bash ${quickshell}/theme-dev/memphis/taskbar.sh ${quickshell} $TMPDIR/taskbar
        touch $out
      '';
      # Per-window Chromium/PWA site icons and Platinum tokens take priority.
      # The Phase 4 theme art/lettermarks remain the fallback. Each window
      # is compared with its own PNG; Chromium's upstream logo never leaks.
      checks.app-icons =
        pkgs.runCommand "app-icons"
          (
            sessionEnv
            // {
              nativeBuildInputs = [
                config.packages.quickshell-mountainous
                (pkgs.python3.withPackages (p: [
                  p.pillow
                  p.pywayland
                ]))
              ]
              ++ sessionEnv.nativeBuildInputs;
              XDG_DATA_DIRS = "${config.packages.desktop-art}/share:${pkgs.hicolor-icon-theme}/share";
              DESKTOP_ART = config.packages.desktop-art;
              MOUNTAINOUS_PLATINUM_ICON = "${config.packages.platinum-icons}/bin/mountainous-platinum-icon";
            }
          )
          ''
            export HOME=$TMPDIR
            node ${quickshell}/app-icon.test.js ${quickshell} ${./web-apps.json} ${./web-app-pwas.json}
            bash ${quickshell}/notification-schema-js.sh ${../packages/notify-sync/schema/ui-socket.v1.json} > $TMPDIR/notification-schema.js
            export SESSION_SCHEMA=$TMPDIR/notification-schema.js
            bash ${quickshell}/theme-dev/memphis/app-icons.sh ${quickshell} $TMPDIR/app-icons $out
          '';
      # Files' shell pieces in both themes (theme-dev/memphis/capture-chrome.sh):
      # the apps' tray icons with theme art and lettermarks, an app's menu,
      # Files in Start and the Apple menu, Show Desktop, the narrow
      # overflow; Platinum light, dark and extra dark, Memphis light and
      # dark, at scale 1.5. The shots are the output.
      checks.files-chrome-captures =
        pkgs.runCommand "files-chrome-captures"
          (
            sessionEnv
            // {
              nativeBuildInputs = [
                config.packages.quickshell-mountainous
                (pkgs.python3.withPackages (p: [
                  p.pillow
                  p.pywayland
                ]))
              ]
              ++ sessionEnv.nativeBuildInputs;
              XDG_DATA_DIRS = "${config.packages.desktop-art}/share:${pkgs.hicolor-icon-theme}/share";
              # Platinum draws in ChicagoFLF, Memphis in W95FA Grid.
              FONTCONFIG_FILE = pkgs.makeFontsConf {
                fontDirectories = [
                  config.packages.w95fa-grid
                  config.packages.chicagoflf
                  pkgs.dejavu_fonts
                ];
              };
            }
          )
          ''
            export HOME=$TMPDIR
            bash ${quickshell}/notification-schema-js.sh ${../packages/notify-sync/schema/ui-socket.v1.json} > $TMPDIR/notification-schema.js
            export SESSION_SCHEMA=$TMPDIR/notification-schema.js
            bash ${quickshell}/theme-dev/memphis/capture-chrome.sh ${quickshell} $TMPDIR/chrome $out
          '';
      # The Platinum Control Strip's icons in the real shell at scale 1.5,
      # light, dark and black (theme-dev/platinum-strip.sh): every icon a
      # token of one optical size (26 px opaque, 9 px from the bevel) for
      # site icons, app icons, theme-art apps and Chromium with no page
      # icon, clear of the ▴ (pressed in too), drawn 1:1, the stipple on
      # other pages; a drag's ghost and label; many windows at 600 px. The
      # strip plan's geometry test runs first. Captures are the output.
      checks.platinum-strip =
        pkgs.runCommand "platinum-strip"
          (
            sessionEnv
            // {
              nativeBuildInputs = [
                config.packages.quickshell-mountainous
                (pkgs.python3.withPackages (p: [
                  p.pillow
                  p.numpy
                  p.pywayland
                ]))
              ]
              ++ sessionEnv.nativeBuildInputs;
              XDG_DATA_DIRS = "${config.packages.desktop-art}/share:${pkgs.hicolor-icon-theme}/share";
              DESKTOP_ART = config.packages.desktop-art;
              MOUNTAINOUS_PLATINUM_ICON = "${config.packages.platinum-icons}/bin/mountainous-platinum-icon";
              FONTCONFIG_FILE = pkgs.makeFontsConf {
                fontDirectories = [
                  config.packages.chicagoflf
                  config.packages.w95fa-grid
                  pkgs.dejavu_fonts
                ];
              };
            }
          )
          ''
            export HOME=$TMPDIR
            node ${quickshell}/themes/platinum/strip-plan.test.js ${quickshell}/themes/platinum/strip-plan.js ${quickshell}/page-names.js
            bash ${quickshell}/notification-schema-js.sh ${../packages/notify-sync/schema/ui-socket.v1.json} > $TMPDIR/notification-schema.js
            export SESSION_SCHEMA=$TMPDIR/notification-schema.js
            bash ${quickshell}/theme-dev/platinum-strip.sh ${quickshell} $TMPDIR/platinum-strip $out
          '';
      checks.memphis-theme =
        pkgs.runCommand "memphis-theme"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.quickshell
              pkgs.labwc
              pkgs.qt6.qtdeclarative
              # access.sh reads the gallery's JSON.
              pkgs.python3
            ];
            QML2_IMPORT_PATH = "${
              inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
            }/lib/qt-6/qml";
            QMLLINT = "${pkgs.qt6.qtdeclarative}/bin/qmllint";
            QML_PATHS = qmlPaths;
            QUICKSHELL = "${pkgs.quickshell}/bin/qs";
            LABWC = "${pkgs.labwc}/bin/labwc";
            # The packaged face (modules/fonts.nix), so metrics are the real ones.
            MEMPHIS_FONT = "${config.packages.w95fa-grid}/share/fonts/truetype/W95FAGrid.ttf";
          }
          ''
            export HOME=$TMPDIR
            bash ${quickshell}/themes/memphis/dev/lint.sh ${quickshell}
            bash ${quickshell}/themes/memphis/dev/check.sh ${quickshell}
            touch $out
          '';
    };
}
