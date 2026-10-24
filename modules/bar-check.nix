# Pure bar policies and the actual Qt singleton, without a running compositor.
{ self, ... }:
{
  perSystem =
    { pkgs, lib, config, ... }:
    let
      desktop = self.nixosConfigurations.myoko.config;
      files = desktop.hjem.users.simon.files;
      # Unit cleanup is part of recorder lifecycle: capture the evaluated policy
      # without pulling the host closure into this focused check.
      lifecycleUnitEvidence = builtins.unsafeDiscardStringContext (
        builtins.toJSON {
          configurationRevision = desktop.system.configurationRevision;
          toplevelDrvPath = desktop.system.build.toplevel.drvPath;
          quickshell = desktop.systemd.user.services.quickshell.serviceConfig;
          userManagerRuntimeDir = "/run/user/${toString desktop.users.users.simon.uid}";
          runtimeOverride = (desktop.systemd.globalEnvironment // desktop.systemd.user.services.quickshell.environment).XDG_RUNTIME_DIR or null;
          unitOverrideStrategy = desktop.systemd.user.units."quickshell.service".overrideStrategy;
        }
      );
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
        || lib.hasSuffix ".sh" name
        || lib.hasInfix "/dev/" name;
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
            node ${./quickshell/media-hold.test.js} ${./quickshell/media-hold.js}
            node ${./quickshell/bar-plan.test.js} ${./quickshell/bar-plan.js} ${./quickshell/bar-fixtures.json}
            node ${./quickshell/MenuState.test.js} ${./quickshell/MenuState.qml}
            qmllint -I "$QML_IMPORT_PATH" ${./quickshell/MenuState.qml}
            touch $out
          '';
      # Run the production QML with a headless software Wayland compositor.
      # The recorder and backend are real child processes with controlled exits.
      # Two real mpv MPRIS players on a private session bus prove the media hold.
      checks.dictation-lifecycle =
        assert desktop.systemd.user.services.quickshell.serviceConfig.KillMode == "mixed";
        assert desktop.users.users.simon.uid == 1000;
        assert ((desktop.systemd.globalEnvironment // desktop.systemd.user.services.quickshell.environment).XDG_RUNTIME_DIR or null) == null;
        pkgs.runCommand "dictation-lifecycle"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.quickshell
              pkgs.labwc
              pkgs.systemd
            ];
            QUICKSHELL = "${pkgs.quickshell}/bin/qs";
            LABWC = "${pkgs.labwc}/bin/labwc";
            DBUS_DAEMON = "${pkgs.dbus}/bin/dbus-daemon";
            DBUS_SESSION_CONF = "${pkgs.dbus}/share/dbus-1/session.conf";
            MPV = lib.getExe pkgs.mpv;
            MPV_MPRIS = "${pkgs.mpvScripts.mpris}/share/mpv/scripts/mpris.so";
          }
          ''
            printf 'Evaluated recorder unit settings: %s\n' ${lib.escapeShellArg lifecycleUnitEvidence}
            bash ${../tests/quickshell-dropin-order.sh}
            node ${./quickshell/dictation-lifecycle.test.js} ${./quickshell/Dictation.qml} ${./quickshell}/Theme.qml
            touch $out
          '';
      # The Platinum bar's shadow window: no reserved space, no input,
      # mapped only with its bar, painted only on the light and grey bars.
      checks.bar-shadow =
        pkgs.runCommand "bar-shadow"
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
            node ${./quickshell/bar-shadow.test.js} ${./quickshell}
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
          bash ${./quickshell/stage-runtime.test.sh} ${./quickshell}
          node ${./quickshell/themes/platinum/picker-plan.test.js} ${./quickshell/themes/platinum/picker-plan.js}
          bash ${./quickshell/notification-schema-js.sh} ${../packages/notify-sync/schema/ui-socket.v1.json} > notification-schema.js
          node ${./quickshell/theme-dev/lifecycle.test.js} ${./quickshell} ${config.packages.desktop-theme}/bin/desktop-theme "$PWD/notification-schema.js"
          node ${./quickshell/theme-dev/picker-geometry.test.js} ${./quickshell} "$PWD/notification-schema.js"
          touch $out
        '';
      checks.bar-delivery =
        assert allDelivered;
        assert noDevelopment;
        assert builtins.hasAttr (prefix + "PlatinumDesktop.qml") files;
        assert builtins.hasAttr (prefix + "themes/platinum/previews/light.png") files;
        assert builtins.hasAttr (prefix + "themes.json") files;
        assert !(builtins.hasAttr (prefix + "qmldir") files);
        # Win98: its flat QML, its policies, icons and thumbnails; never the
        # control gallery, its scripts or the harness.
        assert builtins.hasAttr (prefix + "Win98Desktop.qml") files;
        assert builtins.hasAttr (prefix + "Win98PickerView.qml") files;
        assert builtins.hasAttr (prefix + "themes/win98/taskbar-plan.js") files;
        assert builtins.hasAttr (prefix + "themes/win98/icons/mark.svg") files;
        assert builtins.hasAttr (prefix + "themes/win98/previews/light.png") files;
        assert !(builtins.hasAttr (prefix + "themes/win98/dev/Win98Gallery.qml") files);
        assert !(builtins.hasAttr (prefix + "themes/win98/taskbar-plan.test.js") files);
        assert !(builtins.hasAttr (prefix + "theme-dev/win98/harness.qml") files);
        pkgs.runCommand "bar-delivery" { } "touch $out";
    };
}
