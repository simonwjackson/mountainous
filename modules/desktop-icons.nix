# Desktop icons (Hensou Phase 5): the shell draws the icons that Hensou
# Files' desktop provider supplies over $XDG_RUNTIME_DIR/hensou/desktop.sock
# (Hensou docs/design/desktop-icons.md, ADR 0006). The QML lives in
# modules/quickshell (DesktopIcons*.qml, DesktopIconSession.qml,
# desktop-icons-model.js, lettermark.js, Lettermark.qml) and is delivered
# with the rest of the shell (bars.nix). The harness and its fixture
# provider are in modules/quickshell/theme-dev/desktop-icons.
{ inputs, ... }:
{
  perSystem =
    { pkgs, config, ... }:
    {
      # The pure policies (the session and its resubscribe on a display or
      # theme change, selection, rubber band, keyboard navigation through
      # cascaded icons, drag and drop, menus, each theme's confirmations,
      # the art) and the lettermark rule; then the real layer under
      # Quickshell in a private headless sway with a virtual pointer and
      # keyboard (theme-dev/desktop-icons/behaviour.sh), against
      # provider.js.
      checks.desktop-icons =
        pkgs.runCommand "desktop-icons"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.gnused
              pkgs.nodejs
              pkgs.sway-unwrapped
              pkgs.grim
              pkgs.wtype
              config.packages.quickshell-mountainous
              (pkgs.python3.withPackages (p: [ p.pywayland ]))
            ];
            __EGL_VENDOR_LIBRARY_DIRS = "${pkgs.mesa}/share/glvnd/egl_vendor.d";
            LIBGL_DRIVERS_PATH = "${pkgs.mesa}/lib/dri";
            FONTCONFIG_FILE = pkgs.makeFontsConf {
              fontDirectories = [
                config.packages.w95fa-grid
                config.packages.chicagoflf
                pkgs.dejavu_fonts
              ];
            };
            XDG_DATA_DIRS = "${config.packages.desktop-art}/share:${pkgs.hicolor-icon-theme}/share";
            QML2_IMPORT_PATH = "${
              inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
            }/lib/qt-6/qml:${pkgs.qt6.qtwebsockets}/lib/qt-6/qml:${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
            WLR_PROTOCOL = "${pkgs.wlr-protocols}/share/wlr-protocols/unstable/wlr-virtual-pointer-unstable-v1.xml";
            WAYLAND_XML = "${pkgs.wayland-scanner.out}/share/wayland/wayland.xml";
          }
          ''
            export HOME=$TMPDIR
            node ${./quickshell/lettermark.test.js} ${./quickshell/lettermark.js}
            node ${./quickshell/desktop-icons-model.test.js} ${./quickshell/desktop-icons-model.js} ${./quickshell/lettermark.js}
            bash ${./quickshell}/theme-dev/desktop-icons/behaviour.sh ${./quickshell} $TMPDIR/behaviour
            touch $out
          '';
    };
}
