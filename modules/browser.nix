# The browser spine: CDP control in QML for Ctrl+L. Chromium retains window
# ownership and its origin/security UI. See desktop-themes/chromium-windows.md.
{ self, inputs, ... }:
let
  tablessPolicy = "mdndkociaebjkggmhnemegoegnbfbgoo;https://clients2.google.com/service/update2/crx";
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.chromium-tabless =
        let
          configured =
            enable:
            (self.nixosConfigurations.myoko.extendModules {
              modules = [ { mountainous.browser.tabless.enable = pkgs.lib.mkForce enable; } ];
            }).config;
          enabled = configured true;
          disabled = configured false;
          policy = builtins.fromJSON enabled.environment.etc."chromium/policies/managed/default.json".text;
        in
        assert policy.ExtensionInstallForcelist == [ tablessPolicy ];
        assert
          disabled.programs.chromium.extensions == null
          || !(builtins.elem tablessPolicy disabled.programs.chromium.extensions);
        assert enabled.programs.chromium.initialPrefs.vertical_tabs.enabled;
        assert enabled.programs.chromium.initialPrefs.vertical_tabs.collapsed_state;
        assert !enabled.programs.chromium.initialPrefs.vertical_tabs.expand_on_hover;
        assert enabled.programs.chromium.initialPrefs.browser.custom_chrome_frame == false;
        assert !(disabled.programs.chromium.initialPrefs ? vertical_tabs);
        pkgs.runCommand "chromium-tabless" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
          node ${./quickshell/app-model.test.js} ${./quickshell/app-model.js}
          touch "$out"
        '';
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
            QML2_IMPORT_PATH = "${
              inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml
            }/lib/qt-6/qml:${pkgs.qt6.qtwebsockets}/lib/qt-6/qml";
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
      tabless = config.mountainous.browser.tabless;
    in
    {
      options.mountainous.browser.tabless.enable = lib.mkEnableOption ''
        Tab-less from the Chrome Web Store (one normal window per unpinned
        new tab). Seeds collapsed vertical tabs in new profiles only. This
        uses the same Web Store ID as a manual install, never a second
        unpacked copy. Adoption must be confirmed on Myoko after deployment.
        Turning this off later uninstalls that copy, even if first installed
        by hand; reinstall it manually to return to manual management.
        See docs/plans/desktop-themes/tabless.md for memory and navigation costs
      '';
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
        programs.chromium = lib.mkIf tabless.enable {
          # The upstream module emits ExtensionInstallForcelist. Never load
          # an unpacked second copy alongside Simon's existing Web Store ID.
          extensions = [ tablessPolicy ];
          # A first-run seed, not a policy or a live-profile rewrite. No
          # feature switch is needed in Chromium 153 (VerticalTabsLaunch).
          initialPrefs = lib.mkDefault {
            vertical_tabs = {
              enabled = true;
              collapsed_state = true;
              expand_on_hover = false;
            };
          };
        };
        # Wrap, do not replace the profile. --remote-debugging-port=0 selects
        # a random loopback port. Both user-data roots keep their own endpoint.
        nixpkgs.overlays = lib.optional cfg.enable (
          _final: prev: {
            chromium = prev.chromium.override { commandLineArgs = "--remote-debugging-port=0"; };
          }
        );
        environment.sessionVariables.MOUNTAINOUS_BROWSER_INTEGRATION = if cfg.enable then "1" else "0";
        systemd.user.services.quickshell.environment = {
          # bars.nix owns the complete shell QML import path.
          MOUNTAINOUS_BROWSER_INTEGRATION = if cfg.enable then "1" else "0";
        };
        hjem.users.simon.files.".config/quickshell/mountainous/CdpBrowser.qml".source =
          ./quickshell/CdpBrowser.qml;
      };
    };
}
