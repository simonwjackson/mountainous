# Original sound assets and the semantic playback contract. No real audio in tests.
{ inputs, ... }:
{
  nixos.modules.desktop = { pkgs, ... }: {
    systemd.user.services.quickshell.environment.QML_IMPORT_PATH =
      "${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
  };
  perSystem = { pkgs, config, ... }: {
    checks.desktop-sounds =
      pkgs.runCommand "desktop-sounds"
        {
          nativeBuildInputs = [
            pkgs.nodejs
            pkgs.python3
            pkgs.qt6.qtdeclarative
            pkgs.quickshell
            pkgs.labwc
            pkgs.grim
            pkgs.wlr-randr
            pkgs.pulseaudio
          ];
          QUICKSHELL = "${pkgs.quickshell}/bin/qs";
          LABWC = "${pkgs.labwc}/bin/labwc";
          FONTCONFIG_FILE = pkgs.makeFontsConf {
            fontDirectories = [
              config.packages.chicagoflf
              config.packages.w95fa-grid
            ];
          };
          QML2_IMPORT_PATH = "${inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml}/lib/qt-6/qml:${pkgs.qt6.qtwebsockets}/lib/qt-6/qml";
          QML = "${pkgs.qt6.qtdeclarative}/bin/qml";
          QML_IMPORT_PATH = "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
        }
        ''
          export HOME="$TMPDIR/home" XDG_CACHE_HOME="$TMPDIR/cache"
          mkdir -p "$HOME" "$out"
          export EVIDENCE_DIR="$out"
          bash ${./quickshell/notification-schema-js.sh} ${../packages/notify-sync/schema/ui-socket.v1.json} > notification-schema.js
          node ${./quickshell/theme-dev/sound-picker.test.js} ${./quickshell} ${config.packages.desktop-theme}/bin/desktop-theme "$PWD/notification-schema.js"
          node ${./quickshell/theme-dev/sound-bank.test.js} ${./quickshell}
          node ${./quickshell/theme-dev/sounds.test.js} ${./quickshell}
          node ${./quickshell/MenuState.test.js} ${./quickshell/MenuState.qml}
          python3 ${./desktop-sounds/generate.py} generated
          diff -r generated/platinum/sounds ${./quickshell/themes/platinum/sounds}
          diff -r generated/win98/sounds ${./quickshell/themes/win98/sounds}
          qmllint -I ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml -I ${pkgs.qt6.qtmultimedia}/lib/qt-6/qml ${./quickshell}/ThemeSoundPlayer.qml ${./quickshell}/ThemeSoundBank.qml
          touch $out/passed
        '';
  };
}
