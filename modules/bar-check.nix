# Pure bar policies and the actual Qt singleton, without a running compositor.
{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      files = self.nixosConfigurations.myoko.config.hjem.users.simon.files;
      prefix = ".config/quickshell/mountainous/";
      delivered = builtins.filter (lib.hasPrefix prefix) (builtins.attrNames files);
      relative = path: lib.removePrefix (toString ./quickshell + "/") (toString path);
      sourceFiles = map relative (lib.filesystem.listFilesRecursive ./quickshell);
      development =
        name:
        lib.hasPrefix "notification-dev/" name
        || lib.hasPrefix "builder-dev/" name
        || lib.hasPrefix "theme-dev/" name
        || lib.hasSuffix ".test.js" name
        || lib.hasSuffix ".py" name
        || lib.hasSuffix ".sh" name;
      required = builtins.filter (
        name:
        !(development name)
        && (lib.hasSuffix ".qml" name || lib.hasSuffix ".js" name || name == "themes.json" || lib.hasPrefix "themes/" name || lib.hasPrefix "icons/" name)
      ) sourceFiles;
      allDelivered = builtins.all (name: builtins.hasAttr (prefix + name) files) required;
      noDevelopment = builtins.all (name: !(development (lib.removePrefix prefix name))) delivered;
    in
    {
      checks.bar-model =
        pkgs.runCommand "bar-model"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.qt6.qtdeclarative
            ];
            QML = "${pkgs.qt6.qtdeclarative}/bin/qml";
            QML_IMPORT_PATH = "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml";
          }
          ''
            node ${./quickshell/battery.test.js} ${./quickshell/battery.js}
            node ${./quickshell/oci-model.test.js} ${./quickshell/oci-model.js}
            node ${./quickshell/bar-plan.test.js} ${./quickshell/bar-plan.js} ${./quickshell/bar-fixtures.json}
            node ${./quickshell/MenuState.test.js} ${./quickshell/MenuState.qml}
            qmllint -I "$QML_IMPORT_PATH" ${./quickshell/MenuState.qml}
            touch $out
          '';
      # Run the production QML with a headless software Wayland compositor.
      # The recorder and backend are real child processes with controlled exits.
      checks.dictation-lifecycle =
        pkgs.runCommand "dictation-lifecycle"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.quickshell
              pkgs.labwc
            ];
            QUICKSHELL = "${pkgs.quickshell}/bin/qs";
            LABWC = "${pkgs.labwc}/bin/labwc";
          }
          ''
            node ${./quickshell/dictation-lifecycle.test.js} ${./quickshell/Dictation.qml} ${./quickshell}/Theme.qml
            touch $out
          '';
      checks.desktop-theme-shell =
        pkgs.runCommand "desktop-theme-shell" {
          nativeBuildInputs = [pkgs.nodejs pkgs.python3 pkgs.quickshell pkgs.labwc pkgs.bash];
          QML2_IMPORT_PATH = "${pkgs.qt6.qtwebsockets}/lib/qt-6/qml";
          FONTCONFIG_FILE = pkgs.makeFontsConf {fontDirectories = [pkgs.dejavu_fonts];};
          QUICKSHELL = "${pkgs.quickshell}/bin/qs";
          LABWC = "${pkgs.labwc}/bin/labwc";
        } ''
          python3 ${./quickshell/theme-dev/check-boundaries.py} ${./quickshell}
          node ${./quickshell/themes/platinum/picker-plan.test.js} ${./quickshell/themes/platinum/picker-plan.js}
          bash ${./quickshell/notification-schema-js.sh} ${../packages/notify-sync/schema/ui-socket.v1.json} > notification-schema.js
          node ${./quickshell/theme-dev/lifecycle.test.js} ${./quickshell} ${self.nixosConfigurations.myoko.config.system.build.desktopTheme}/bin/desktop-theme "$PWD/notification-schema.js"
          touch $out
        '';
      checks.bar-delivery =
        assert allDelivered;
        assert noDevelopment;
        assert builtins.hasAttr (prefix + "PlatinumDesktop.qml") files;
        assert builtins.hasAttr (prefix + "themes/platinum/previews/light.png") files;
        assert builtins.hasAttr (prefix + "themes.json") files;
        assert !(builtins.hasAttr (prefix + "qmldir") files);
        pkgs.runCommand "bar-delivery" { } "touch $out";
    };
}
