# The browser spine: CDP control in QML for Ctrl+L. Chromium retains window
# ownership and its origin/security UI. See desktop-themes/chromium-windows.md.
{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.chromium-windows =
        let
          desktop = self.nixosConfigurations.myoko.config;
        in
        assert
          desktop.systemd.user.services.quickshell.environment.MOUNTAINOUS_BROWSER_INTEGRATION
          == (if desktop.mountainous.browser.shellNavigation.enable then "1" else "0");
        pkgs.runCommand "chromium-windows"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.lua
              pkgs.bash
            ];
            QUICKSHELL_LINT_QS = pkgs.quickshell;
            QUICKSHELL_LINT_QT = pkgs.qt6.qtdeclarative;
            QUICKSHELL_LINT_QTBASE = pkgs.qt6.qtbase;
            QML2_IMPORT_PATH = "${pkgs.qt6.qtwebsockets}/lib/qt-6/qml";
            EXPECTED_NAVIGATION = if desktop.mountainous.browser.shellNavigation.enable then "1" else "0";
            CHROMIUM = "${self.nixosConfigurations.myoko.pkgs.chromium}/bin/chromium";
          }
          ''
            lua ${./hyprland/browser-keys.test.lua} ${./hyprland/hyprland.lua}
            node ${./quickshell/cdp-target.test.js} ${./quickshell}
            node ${./quickshell/find-model.test.js} ${./quickshell/find-model.js} ${./quickshell/OmniBar.qml} ${./quickshell/launcher-model.js} ${./quickshell/Launcher.qml}
            node ${./quickshell/app-model.test.js} ${./quickshell/app-model.js}
            if [ "$EXPECTED_NAVIGATION" = 1 ]; then
              grep -q -- '--remote-debugging-port=0' "$CHROMIUM"
            else
              ! grep -q -- '--remote-debugging-port=0' "$CHROMIUM"
            fi
            # Quickshell discovers pragma Singleton itself; qmllint needs an
            # explicit complete index. This index is test-only, never delivered.
            cp -R ${./quickshell} qml
            chmod -R u+w qml
            for file in qml/[A-Z]*.qml; do
              name=$(basename "$file" .qml)
              if grep -q '^pragma Singleton' "$file"; then printf 'singleton ' >> qml/qmldir; fi
              printf '%s 1.0 %s.qml\n' "$name" "$name" >> qml/qmldir
            done
            bash ${../scripts/lint-quickshell-qml} qml/CdpBrowser.qml qml/OmniBar.qml qml/PlatinumGoToAddress.qml qml/Win98OpenDialog.qml
            touch "$out"
          '';
    };

  nixos.modules.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.browser.shellNavigation;
    in
    {
      options.mountainous.browser.shellNavigation.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Let Go to Address / Open navigate ordinary Chromium over loopback
          CDP, and consume its Ctrl+L. Disable and restart Chromium and the
          desktop session to return ordinary Chromium's own Ctrl+L. This
          does not enable the no-tab prototype or change profile cookies.
        '';
      };
      config = {
        # Wrap, do not replace the profile. --remote-debugging-port=0 selects
        # a random loopback port. Both user-data roots keep their own endpoint.
        nixpkgs.overlays = lib.optional cfg.enable (
          _final: prev: {
            chromium = prev.chromium.override { commandLineArgs = "--remote-debugging-port=0"; };
          }
        );
        environment.sessionVariables.MOUNTAINOUS_BROWSER_INTEGRATION = if cfg.enable then "1" else "0";
        systemd.user.services.quickshell.environment = {
          QML2_IMPORT_PATH = "${pkgs.qt6.qtwebsockets}/lib/qt-6/qml";
          MOUNTAINOUS_BROWSER_INTEGRATION = if cfg.enable then "1" else "0";
        };
        hjem.users.simon.files.".config/quickshell/mountainous/CdpBrowser.qml".source =
          ./quickshell/CdpBrowser.qml;
      };
    };
}
