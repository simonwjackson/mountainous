# The Windows 98 theme's controls (modules/quickshell/Win98*.qml, assets in
# themes/win98): qmllint with the qmldir Quickshell would write, then the
# test gallery under a real headless Quickshell, every page in both
# appearances, with the Start menu's keyboard and roll-out checks. The
# gallery and its scripts are not delivered; see themes/win98/dev/.
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
      # A private headless sway session for the real Win98 Desktop (no
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
        QML2_IMPORT_PATH = "${inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml}/lib/qt-6/qml:${pkgs.qt6.qtwebsockets}/lib/qt-6/qml:${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
        WLR_PROTOCOL = "${pkgs.wlr-protocols}/share/wlr-protocols/unstable/wlr-virtual-pointer-unstable-v1.xml";
        WAYLAND_XML = "${pkgs.wayland-scanner.out}/share/wayland/wayland.xml";
      };
    in
    {
      # The Win98 Desktop itself: its pure policies, then the real
      # ThemeDesktop and Win98Desktop over the production panel owners in a
      # private headless sway session (no output device). behaviour.sh runs
      # the approved mock's interaction checks with a virtual pointer and
      # keyboard; switch.sh switches Platinum and Win98 ten times with a menu,
      # cascade or the picker open and asserts the reserved edge (sway) and
      # the mapped layer surfaces (niri) after each swap, then rolls back a
      # broken Win98; geometry.sh checks real control bounds at small sizes;
      # scales.sh checks 2-px bevels on outputs at scales 1.5 and 1. switch.sh
      # opens each theme's Fleet window or glance space before every swap,
      # and under Win98 also the window or taskbar menu, Shut Down Myoko,
      # System Properties, the Cool Switch or the volume pop-up; geometry.sh
      # checks those from 360x640 up. find.sh checks the Find window
      # (Super+P) and IE's Open dialog (Ctrl+L): keys, pointer, the omni
      # claim, and their bounds from 1920x1200 down to 360x640.
      checks.win98-desktop =
        pkgs.runCommand "win98-desktop" sessionEnv
          ''
            export HOME=$TMPDIR
            node ${quickshell}/themes/win98/taskbar-plan.test.js ${quickshell}/themes/win98/taskbar-plan.js
            node ${quickshell}/themes/win98/models.test.js ${quickshell}/themes/win98/tray-model.js ${quickshell}/themes/win98/start-model.js
            node ${quickshell}/themes/win98/fleet-plan.test.js ${quickshell}/themes/win98/fleet-plan.js ${quickshell}/glance-plan.js \
              ${quickshell}/themes/win98/tab-strip.js ${quickshell}/themes/win98/host-icon.js
            node ${quickshell}/themes/win98/find-plan.test.js ${quickshell}/themes/win98/find-plan.js
            node ${quickshell}/themes/win98/task-model.test.js ${quickshell}/themes/win98/task-model.js \
              ${quickshell}/themes/win98/session-model.js ${quickshell}/page-names.js
            bash ${quickshell}/notification-schema-js.sh ${../packages/notify-sync/schema/ui-socket.v1.json} > $TMPDIR/notification-schema.js
            export SESSION_SCHEMA=$TMPDIR/notification-schema.js
            bash ${quickshell}/theme-dev/win98/behaviour.sh ${quickshell} $TMPDIR/behaviour
            bash ${quickshell}/theme-dev/win98/switch.sh ${quickshell} $TMPDIR/switch
            bash ${quickshell}/theme-dev/win98/geometry.sh ${quickshell} $TMPDIR/geometry
            bash ${quickshell}/theme-dev/win98/scales.sh ${quickshell} $TMPDIR/scales
            bash ${quickshell}/theme-dev/win98/find.sh ${quickshell} $TMPDIR/find
            touch $out
          '';
      # The Win98 Fleet window and glance space in the same session: fleet.sh
      # (behaviour, motion, every fixture, and the bounds from 360x640 to the
      # 2560x1600 tablet). Its own attribute, so each build stays short.
      checks.win98-fleet = pkgs.runCommand "win98-fleet" sessionEnv ''
        export HOME=$TMPDIR
        node ${quickshell}/themes/win98/fleet-plan.test.js ${quickshell}/themes/win98/fleet-plan.js ${quickshell}/glance-plan.js \
          ${quickshell}/themes/win98/tab-strip.js ${quickshell}/themes/win98/host-icon.js
        bash ${quickshell}/notification-schema-js.sh ${../packages/notify-sync/schema/ui-socket.v1.json} > $TMPDIR/notification-schema.js
        export SESSION_SCHEMA=$TMPDIR/notification-schema.js
        bash ${quickshell}/theme-dev/win98/fleet.sh ${quickshell} $TMPDIR/fleet
        touch $out
      '';
      # The Win98 taskbar and session parity items in the same session:
      # taskbar.sh (minimized buttons, the window and taskbar menus, the
      # windows menu call, held Super+Tab, Lock, Shut Down Myoko, System
      # Properties, Documents and Favorites, the volume pop-up, and no page
      # number anywhere). Session commands and launches are logging stubs.
      # Its own attribute, so each build stays under the 15-minute step.
      checks.win98-taskbar = pkgs.runCommand "win98-taskbar" sessionEnv ''
        export HOME=$TMPDIR
        node ${quickshell}/themes/win98/task-model.test.js ${quickshell}/themes/win98/task-model.js \
          ${quickshell}/themes/win98/session-model.js ${quickshell}/page-names.js
        node ${quickshell}/app-model.test.js ${quickshell}/app-model.js
        node ${quickshell}/window-hide.test.js ${quickshell}/window-hide.js
        node ${quickshell}/window-motion.test.js ${quickshell}/window-motion.js ${quickshell}/glance-plan.js
        bash ${quickshell}/notification-schema-js.sh ${../packages/notify-sync/schema/ui-socket.v1.json} > $TMPDIR/notification-schema.js
        export SESSION_SCHEMA=$TMPDIR/notification-schema.js
        bash ${quickshell}/theme-dev/win98/taskbar.sh ${quickshell} $TMPDIR/taskbar
        touch $out
      '';
      # Chromium and its web apps draw the Phase 4 icon set in both themes
      # (app-icon.js): the Win98 taskbar and the Platinum Control Strip with
      # the patched Quickshell and the art package, and no fallthrough to
      # Chromium's logo or a PWA's own icon. The crops are the output.
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
            }
          )
          ''
            export HOME=$TMPDIR
            node ${quickshell}/app-icon.test.js ${quickshell} ${./web-apps.json} ${./web-app-pwas.json}
            bash ${quickshell}/notification-schema-js.sh ${../packages/notify-sync/schema/ui-socket.v1.json} > $TMPDIR/notification-schema.js
            export SESSION_SCHEMA=$TMPDIR/notification-schema.js
            bash ${quickshell}/theme-dev/win98/app-icons.sh ${quickshell} $TMPDIR/app-icons $out
          '';
      checks.win98-theme =
        pkgs.runCommand "win98-theme"
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
            QML2_IMPORT_PATH = "${inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml}/lib/qt-6/qml";
            QMLLINT = "${pkgs.qt6.qtdeclarative}/bin/qmllint";
            QML_PATHS = qmlPaths;
            QUICKSHELL = "${pkgs.quickshell}/bin/qs";
            LABWC = "${pkgs.labwc}/bin/labwc";
            # The packaged face (modules/fonts.nix), so metrics are the real ones.
            WIN98_FONT = "${config.packages.w95fa-grid}/share/fonts/truetype/W95FAGrid.ttf";
          }
          ''
            export HOME=$TMPDIR
            bash ${quickshell}/themes/win98/dev/lint.sh ${quickshell}
            bash ${quickshell}/themes/win98/dev/check.sh ${quickshell}
            touch $out
          '';
    };
}
