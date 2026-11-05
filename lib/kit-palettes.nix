# One real Qt evaluation shared by the native and compositor seam checks.
{ pkgs, kit }:
let
  qt = pkgs.qt6.env "kit-palette-probe-qt" [
    pkgs.qt6.qtbase
    pkgs.qt6.qtdeclarative
  ];
in
pkgs.runCommand "kit-palettes.json"
  {
    nativeBuildInputs = [
      pkgs.python3
      qt
    ];
    QML_IMPORT_PATH = "${kit}/lib/qt-6/qml:${qt}/lib/qt-6/qml";
    QML2_IMPORT_PATH = "${kit}/lib/qt-6/qml:${qt}/lib/qt-6/qml";
    QT_QPA_PLATFORM = "offscreen";
    QT_QUICK_BACKEND = "software";
  }
  ''
    python3 ${../tests/kit-palettes.py} ${../tests/tst_kit_palettes.qml} > "$out"
  ''
