# Pure bar policies and the actual Qt singleton, without a running compositor.
{ self, inputs, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      desktop = self.nixosConfigurations.myoko.config;
      quickshell = import ../lib/quickshell.nix { inherit pkgs; };
      files = desktop.hjem.users.simon.files;
      # Unit cleanup is part of recorder lifecycle: capture the evaluated policy
      # without pulling the host closure into this focused check.
      lifecycleUnitEvidence = builtins.unsafeDiscardStringContext (
        builtins.toJSON {
          configurationRevision = desktop.system.configurationRevision;
          toplevelDrvPath = desktop.system.build.toplevel.drvPath;
          quickshell = desktop.systemd.user.services.quickshell.serviceConfig;
          userManagerRuntimeDir = "/run/user/${toString desktop.users.users.simon.uid}";
          runtimeOverride =
            (desktop.systemd.globalEnvironment // desktop.systemd.user.services.quickshell.environment)
            .XDG_RUNTIME_DIR or null;
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
        && (
          lib.hasSuffix ".qml" name
          || lib.hasSuffix ".js" name
          || name == "themes.json"
          || lib.hasPrefix "themes/" name
          || lib.hasPrefix "icons/" name
        )
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
              pkgs.quickshell
              pkgs.labwc
            ];
            QUICKSHELL = "${pkgs.quickshell}/bin/qs";
            LABWC = "${pkgs.labwc}/bin/labwc";
            HENSOU_QML_ROOT = "${
              inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
            }/lib/qt-6/qml";
            QML2_IMPORT_PATH = "${
              inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
            }/lib/qt-6/qml:${pkgs.qt6.qtwebsockets}/lib/qt-6/qml:${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
            FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
            QML = "${pkgs.qt6.qtdeclarative}/bin/qml";
            QML_IMPORT_PATH = "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml";
          }
          ''
            node ${./quickshell/battery.test.js} ${./quickshell/battery.js}
            node ${./quickshell/oci-model.test.js} ${./quickshell/oci-model.js}
            node ${./quickshell/media-hold.test.js} ${./quickshell/media-hold.js}
            node ${./quickshell/page-layout-model.test.js} ${./quickshell/page-layout-model.js}
            node ${./quickshell/bar-plan.test.js} ${./quickshell/bar-plan.js} ${./quickshell/bar-fixtures.json} ${./quickshell/PlatinumTopBar.qml}
            node ${./quickshell/bar-compact.test.js} ${./quickshell/bar-plan.js} ${./quickshell/bar-fixtures.json}
            node ${./quickshell/theme-dev/overflow-geometry.test.js} ${./quickshell}
            node ${./quickshell/MenuState.test.js} ${./quickshell/MenuState.qml}
            qmllint -I "$QML_IMPORT_PATH" ${./quickshell/MenuState.qml}
            touch $out
          '';
      # The Platinum Apple menu, Application menu and Control Strip: their
      # pure policies, and the theme-neutral hide/show and running-app models.
      checks.platinum-desktop =
        pkgs.runCommand "platinum-desktop" { nativeBuildInputs = [ pkgs.nodejs ]; }
          ''
            node ${./quickshell/platinum-token.test.js} ${./quickshell}
            node ${./quickshell/window-hide.test.js} ${./quickshell/window-hide.js}
            node ${./quickshell/window-motion.test.js} ${./quickshell/window-motion.js} ${./quickshell/glance-plan.js}
            node ${./quickshell/app-model.test.js} ${./quickshell/app-model.js}
            node ${./quickshell/page-names.test.js} ${./quickshell/page-names.js}
            node ${./quickshell/themes/platinum/strip-plan.test.js} ${./quickshell/themes/platinum/strip-plan.js} ${./quickshell/page-names.js}
            node ${./quickshell/themes/platinum/menu-models.test.js} ${./quickshell/themes/platinum/menu-models.js} ${./quickshell/sni-tray.js}
            node ${./quickshell/app-icon.test.js} ${./quickshell} ${./web-apps.json} ${./web-app-pwas.json}
            touch $out
          '';
      # The Platinum Find menu and Go to Address (Super+P): the rows, ranking,
      # scopes and empty/no-results states; the omni service's caller rule on
      # every entry point; the web-app launch kind; the menu and dialog plans.
      checks.find-menu = pkgs.runCommand "find-menu" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
        node ${./quickshell/platinum-token.test.js} ${./quickshell}
        node ${./quickshell/find-model.test.js} ${./quickshell/find-model.js} ${./quickshell/OmniBar.qml} ${./quickshell/launcher-model.js} ${./quickshell/Launcher.qml}
        node ${./quickshell/cdp-target.test.js} ${./quickshell}
        node ${./quickshell/cdp-favicon.test.js} ${./quickshell}
        node ${./quickshell/favicon.test.js} ${./quickshell}
        node ${./quickshell/themes/platinum/find-plan.test.js} ${./quickshell/themes/platinum/find-plan.js}
        touch $out
      '';
      # Run the production QML with a headless software Wayland compositor.
      # The recorder and backend are real child processes with controlled exits.
      # Two real mpv players and a configurable Pyxamp-shaped MPRIS publisher
      # on a private session bus prove own playback and retarget-safe media hold.
      checks.dictation-lifecycle =
        assert desktop.systemd.user.services.quickshell.serviceConfig.KillMode == "mixed";
        assert desktop.users.users.simon.uid == 1000;
        assert
          ((desktop.systemd.globalEnvironment // desktop.systemd.user.services.quickshell.environment)
            .XDG_RUNTIME_DIR or null
          ) == null;
        pkgs.runCommand "dictation-lifecycle"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              quickshell
              pkgs.labwc
              pkgs.systemd
            ];
            QML2_IMPORT_PATH = "${
              inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
            }/lib/qt-6/qml";
            QUICKSHELL = "${quickshell}/bin/qs";
            LABWC = "${pkgs.labwc}/bin/labwc";
            HENSOU_QML_ROOT = "${
              inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
            }/lib/qt-6/qml";
            DBUS_DAEMON = "${pkgs.dbus}/bin/dbus-daemon";
            DBUS_SESSION_CONF = "${pkgs.dbus}/share/dbus-1/session.conf";
            MPV = lib.getExe pkgs.mpv;
            MPV_MPRIS = "${pkgs.mpvScripts.mpris}/share/mpv/scripts/mpris.so";
            PYTHON = lib.getExe (pkgs.python3.withPackages (p: [ p.dbus-fast ]));
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
            QML2_IMPORT_PATH = "${
              inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
            }/lib/qt-6/qml";
            QUICKSHELL = "${pkgs.quickshell}/bin/qs";
            LABWC = "${pkgs.labwc}/bin/labwc";
            HENSOU_QML_ROOT = "${
              inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
            }/lib/qt-6/qml";
          }
          ''
            node ${./quickshell/bar-shadow.test.js} ${./quickshell}
            touch $out
          '';
      checks.desktop-theme-shell =
        pkgs.runCommand "desktop-theme-shell"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.python3
              pkgs.quickshell
              pkgs.labwc
              pkgs.bash
            ];
            QML2_IMPORT_PATH = "${
              inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
            }/lib/qt-6/qml:${pkgs.qt6.qtwebsockets}/lib/qt-6/qml:${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
            FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
            QUICKSHELL = "${pkgs.quickshell}/bin/qs";
            LABWC = "${pkgs.labwc}/bin/labwc";
            HENSOU_QML_ROOT = "${
              inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
            }/lib/qt-6/qml";
          }
          ''
            node ${./quickshell/hensou-host.test.js} ${./quickshell/hensou-host.js}
            node ${./quickshell/chrome-open.test.js} ${./quickshell}
            python3 ${./quickshell/theme-dev/check-boundaries.py} ${./quickshell}
            python3 ${./quickshell/theme-dev/check-registry.test.py} ${./quickshell}
            bash ${./quickshell/stage-runtime.test.sh} ${./quickshell}
            node ${./quickshell/themes/platinum/picker-plan.test.js} ${./quickshell/themes/platinum/picker-plan.js}
            bash ${./quickshell/notification-schema-js.sh} ${../packages/notify-sync/schema/ui-socket.v1.json} > notification-schema.js
            node ${./quickshell/theme-dev/lifecycle.test.js} ${./quickshell} ${config.packages.desktop-theme}/bin/desktop-theme "$PWD/notification-schema.js"
            node ${./quickshell/theme-dev/picker-geometry.test.js} ${./quickshell} "$PWD/notification-schema.js"
            node ${./quickshell/theme-dev/reload.test.js} ${./quickshell} ${config.packages.desktop-theme}/bin/desktop-theme "$PWD/notification-schema.js"
            touch $out
          '';
      checks.bar-delivery =
        assert allDelivered;
        # Tokens must only exist under URI Hensou, never in the flat shell scan.
        assert !(builtins.hasAttr (prefix + "PlatinumTokens.qml") files);
        assert !(builtins.hasAttr (prefix + "MemphisTokens.qml") files);
        assert
          desktop.systemd.user.services.quickshell.environment.QML2_IMPORT_PATH == "${
            inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
          }/lib/qt-6/qml:${pkgs.qt6.qtwebsockets}/lib/qt-6/qml";
        assert noDevelopment;
        assert builtins.hasAttr (prefix + "PlatinumDesktop.qml") files;
        assert builtins.hasAttr (prefix + "themes/platinum/previews/light.png") files;
        assert builtins.hasAttr (prefix + "themes.json") files;
        assert !(builtins.hasAttr (prefix + "qmldir") files);
        # Memphis: its flat QML, its policies, icons and thumbnails; never the
        # control gallery, its scripts or the harness.
        assert builtins.hasAttr (prefix + "MemphisDesktop.qml") files;
        assert builtins.hasAttr (prefix + "MemphisPickerView.qml") files;
        assert builtins.hasAttr (prefix + "themes/memphis/taskbar-plan.js") files;
        assert builtins.hasAttr (prefix + "themes/memphis/icons/mark.svg") files;
        assert builtins.hasAttr (prefix + "themes/memphis/previews/light.png") files;
        assert !(builtins.hasAttr (prefix + "themes/memphis/dev/MemphisGallery.qml") files);
        assert !(builtins.hasAttr (prefix + "themes/memphis/taskbar-plan.test.js") files);
        assert !(builtins.hasAttr (prefix + "theme-dev/memphis/harness.qml") files);
        # Memphis's Fleet window and glance space, their policies and icons;
        # never their tests, the fixtures or the beszel-status stand-in.
        assert builtins.hasAttr (prefix + "MemphisFleetView.qml") files;
        assert builtins.hasAttr (prefix + "MemphisGlanceSpace.qml") files;
        assert builtins.hasAttr (prefix + "themes/memphis/fleet-plan.js") files;
        assert builtins.hasAttr (prefix + "themes/memphis/host-icon.js") files;
        assert builtins.hasAttr (prefix + "themes/memphis/icons/glance.svg") files;
        assert !(builtins.hasAttr (prefix + "themes/memphis/fleet-plan.test.js") files);
        assert !(builtins.hasAttr (prefix + "theme-dev/memphis/fleet-fixtures.json") files);
        # Memphis's Find window and Open dialog, their plan and its web sheet;
        # never their tests or the harness fixtures.
        assert builtins.hasAttr (prefix + "MemphisFindWindow.qml") files;
        assert builtins.hasAttr (prefix + "MemphisOpenDialog.qml") files;
        assert builtins.hasAttr (prefix + "MemphisOmniView.qml") files;
        assert builtins.hasAttr (prefix + "themes/memphis/find-plan.js") files;
        assert builtins.hasAttr (prefix + "themes/memphis/web.css") files;
        assert builtins.hasAttr (prefix + "themes/memphis/icons/find.svg") files;
        assert !(builtins.hasAttr (prefix + "themes/memphis/find-plan.test.js") files);
        assert !(builtins.hasAttr (prefix + "theme-dev/memphis/OmniFixture.qml") files);
        assert !(builtins.hasAttr (prefix + "theme-dev/theme-parity.js") files);
        # Memphis's taskbar and session pieces, their policies, the shared
        # About reader and the page names; never their tests or scripts.
        assert builtins.hasAttr (prefix + "MemphisShutDownScreen.qml") files;
        assert builtins.hasAttr (prefix + "MemphisSystemProperties.qml") files;
        assert builtins.hasAttr (prefix + "MemphisCoolSwitch.qml") files;
        assert builtins.hasAttr (prefix + "MemphisVolumePopup.qml") files;
        assert builtins.hasAttr (prefix + "SystemFacts.qml") files;
        assert builtins.hasAttr (prefix + "themes/memphis/task-model.js") files;
        assert builtins.hasAttr (prefix + "themes/memphis/session-model.js") files;
        assert builtins.hasAttr (prefix + "themes/memphis/icons/computer.svg") files;
        assert !(builtins.hasAttr (prefix + "themes/memphis/task-model.test.js") files);
        assert !(builtins.hasAttr (prefix + "theme-dev/memphis/taskbar.sh") files);
        # Platinum phase 3: the strip, the cascading menus and their policies,
        # and the theme-neutral hide/show and running-app models; never tests.
        assert builtins.hasAttr (prefix + "PlatinumControlStrip.qml") files;
        assert builtins.hasAttr (prefix + "PlatinumCascadeMenu.qml") files;
        assert builtins.hasAttr (prefix + "WindowHider.qml") files;
        # Window motion: the shared events, the overlay, each theme's move.
        assert builtins.hasAttr (prefix + "WindowMotion.qml") files;
        assert builtins.hasAttr (prefix + "MotionLayer.qml") files;
        assert builtins.hasAttr (prefix + "MemphisMotionLayer.qml") files;
        assert builtins.hasAttr (prefix + "PlatinumMotionLayer.qml") files;
        assert builtins.hasAttr (prefix + "window-motion.js") files;
        assert !(builtins.hasAttr (prefix + "window-motion.test.js") files);
        assert builtins.hasAttr (prefix + "themes/platinum/strip-plan.js") files;
        assert builtins.hasAttr (prefix + "themes/platinum/menu-models.js") files;
        assert builtins.hasAttr (prefix + "window-hide.js") files;
        assert builtins.hasAttr (prefix + "app-model.js") files;
        assert builtins.hasAttr (prefix + "page-names.js") files;
        assert !(builtins.hasAttr (prefix + "page-names.test.js") files);
        assert !(builtins.hasAttr (prefix + "themes/platinum/strip-plan.test.js") files);
        assert !(builtins.hasAttr (prefix + "app-model.test.js") files);
        # The Find menu (Super+P) and Go to Address, their model and plan.
        assert builtins.hasAttr (prefix + "PlatinumFindMenu.qml") files;
        assert builtins.hasAttr (prefix + "PlatinumGoToAddress.qml") files;
        assert builtins.hasAttr (prefix + "PlatinumTextField.qml") files;
        assert builtins.hasAttr (prefix + "find-model.js") files;
        assert builtins.hasAttr (prefix + "cdp-target.js") files;
        assert builtins.hasAttr (prefix + "WindowIcon.qml") files;
        assert builtins.hasAttr (prefix + "PlatinumToken.qml") files;
        assert !(builtins.hasAttr (prefix + "platinum-token.test.js") files);
        assert
          desktop.systemd.user.services.quickshell.environment.MOUNTAINOUS_PLATINUM_ICON
          == "${config.packages.platinum-icons}/bin/mountainous-platinum-icon";
        assert builtins.elem config.packages.platinum-icons desktop.environment.systemPackages;
        assert builtins.hasAttr (prefix + "favicon.js") files;
        assert !(builtins.hasAttr (prefix + "favicon.test.js") files);
        assert !(builtins.hasAttr (prefix + "cdp-favicon.test.js") files);
        assert builtins.hasAttr (prefix + "chrome-open.js") files;
        assert !(builtins.hasAttr (prefix + "chrome-open.test.js") files);
        assert !(builtins.hasAttr (prefix + "cdp-target.test.js") files);
        assert builtins.hasAttr (prefix + "themes/platinum/find-plan.js") files;
        assert builtins.hasAttr (prefix + "icons/popup.svg") files;
        assert !(builtins.hasAttr (prefix + "find-model.test.js") files);
        assert !(builtins.hasAttr (prefix + "themes/platinum/find-plan.test.js") files);
        # The quiet glyphs: Balloon Help and the tag, the badge, the new icons.
        assert builtins.hasAttr (prefix + "PlatinumBarHelp.qml") files;
        assert builtins.hasAttr (prefix + "PlatinumBarBadge.qml") files;
        assert builtins.hasAttr (prefix + "icons/speaker-3.svg") files;
        assert builtins.hasAttr (prefix + "icons/brightness-8.svg") files;
        assert builtins.hasAttr (prefix + "icons/cloud-meter.svg") files;
        # shell.qml tolerates a missing ThemeSounds only during a reload of
        # a half-linked tree; every generation must carry the sound owner.
        # app-icon.js: both themes' icon names for Chromium and web apps.
        assert builtins.hasAttr (prefix + "ThemeSounds.qml") files;
        assert builtins.hasAttr (prefix + "SoundEvents.qml") files;
        assert builtins.hasAttr (prefix + "app-icon.js") files;
        assert !(builtins.hasAttr (prefix + "app-icon.test.js") files);
        # Delivery must not pass with a working manifest but unreachable bar
        # capabilities. Reuse the focused planner and real-QML probe result.
        pkgs.runCommand "bar-delivery" { } ''
          test -e ${config.checks.bar-model}
          touch $out
        '';
    };
}
