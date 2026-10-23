# The Windows 98 theme's controls (modules/quickshell/Win98*.qml, assets in
# themes/win98): qmllint with the qmldir Quickshell would write, then the
# test gallery under a real headless Quickshell, every page in both
# appearances, with the Start menu's keyboard and roll-out checks. The
# gallery and its scripts are not delivered; see themes/win98/dev/.
{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      quickshell = ./quickshell;
      qmlPaths = builtins.concatStringsSep ":" [
        "${pkgs.quickshell}/lib/qt-6/qml"
        "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
        "${pkgs.qt6.qtbase}/lib/qt-6/qml"
      ];
    in
    {
      # The Win98 Desktop itself: its pure policies, then the real
      # ThemeDesktop and Win98Desktop over the production panel owners in a
      # private headless sway session (no output device). behaviour.sh runs
      # the approved mock's interaction checks with a virtual pointer and
      # keyboard; switch.sh switches Platinum and Win98 ten times and asserts
      # the reserved edge at the compositor, then rolls back a broken Win98.
      checks.win98-desktop =
        pkgs.runCommand "win98-desktop"
          {
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
              (pkgs.python3.withPackages (p: [ p.pywayland ]))
            ];
            FONTCONFIG_FILE = pkgs.makeFontsConf {
              fontDirectories = [
                config.packages.w95fa-grid
                pkgs.dejavu_fonts
              ];
            };
            QML2_IMPORT_PATH = "${pkgs.qt6.qtwebsockets}/lib/qt-6/qml";
            # No EGL in the sandbox: Qt Quick's software renderer. The checks
            # here assert behaviour and placement, not exact pixels.
            QT_QUICK_BACKEND = "software";
            WLR_PROTOCOL = "${pkgs.wlr-protocols}/share/wlr-protocols/unstable/wlr-virtual-pointer-unstable-v1.xml";
            WAYLAND_XML = "${pkgs.wayland-scanner.out}/share/wayland/wayland.xml";
          }
          ''
            export HOME=$TMPDIR
            node ${quickshell}/themes/win98/taskbar-plan.test.js ${quickshell}/themes/win98/taskbar-plan.js
            node ${quickshell}/themes/win98/models.test.js ${quickshell}/themes/win98/tray-model.js ${quickshell}/themes/win98/start-model.js
            bash ${quickshell}/notification-schema-js.sh ${../packages/notify-sync/schema/ui-socket.v1.json} > $TMPDIR/notification-schema.js
            export SESSION_SCHEMA=$TMPDIR/notification-schema.js
            bash ${quickshell}/theme-dev/win98/behaviour.sh ${quickshell} $TMPDIR/behaviour
            bash ${quickshell}/theme-dev/win98/switch.sh ${quickshell} $TMPDIR/switch
            touch $out
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
            ];
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
