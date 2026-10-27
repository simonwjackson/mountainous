# Test the actual toolkit integration, not only the generated INI text.
# Qt5 puts headers in dev and platform plugins in bin; Qt6 keeps them in
# out. Both roots below are intentional, not host plugin-path fallbacks.
{
  pkgs,
  qtPlatformTheme,
  qt,
  ct,
  kvantum,
  name,
}:
pkgs.runCommand name
  {
    nativeBuildInputs = [
      pkgs.stdenv.cc
      pkgs.makeWrapper
    ];
  }
  ''
    mkdir -p "$out/bin"
    c++ -std=c++17 -fPIC ${../tests/native-qt.cpp} -o "$out/bin/native-qt-probe" \
      -isystem ${pkgs.lib.getDev qt.qtbase}/include \
      -isystem ${pkgs.lib.getDev qt.qtbase}/include/QtCore \
      -isystem ${pkgs.lib.getDev qt.qtbase}/include/QtGui \
      -isystem ${pkgs.lib.getDev qt.qtbase}/include/QtWidgets \
      -isystem ${pkgs.lib.getLib qt.qtbase}/include \
      -isystem ${pkgs.lib.getLib qt.qtbase}/include/QtCore \
      -isystem ${pkgs.lib.getLib qt.qtbase}/include/QtGui \
      -isystem ${pkgs.lib.getLib qt.qtbase}/include/QtWidgets \
      -L${pkgs.lib.getLib qt.qtbase}/lib -Wl,-rpath,${pkgs.lib.getLib qt.qtbase}/lib -lQt${pkgs.lib.versions.major qt.qtbase.version}Widgets -lQt${pkgs.lib.versions.major qt.qtbase.version}Gui -lQt${pkgs.lib.versions.major qt.qtbase.version}Core
    wrapProgram "$out/bin/native-qt-probe" \
      --set QT_PLUGIN_PATH '${pkgs.lib.getBin qt.qtbase}/${qt.qtbase.qtPluginPrefix}:${pkgs.lib.getLib qt.qtbase}/${qt.qtbase.qtPluginPrefix}:${ct}/${qt.qtbase.qtPluginPrefix}:${kvantum}/${qt.qtbase.qtPluginPrefix}' \
      --set QT_QPA_PLATFORM offscreen \
      --set QT_QPA_PLATFORMTHEME '${qtPlatformTheme}'
  ''
