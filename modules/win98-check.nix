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
