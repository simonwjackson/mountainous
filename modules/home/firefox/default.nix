{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption;

  cfg = config.mountainous.firefox;
in {
  imports = [
    ./tridactyl
  ];

  options.mountainous.firefox = {
    enable = mkEnableOption "Whether to enable the firefox browser";
  };

  config = lib.mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      nativeMessagingHosts = [pkgs.tridactyl-native];

      # package = pkgs.firefox-esr.override {
      #   # See nixpkgs' firefox/wrapper.nix to check which options you can use
      #   cfg = {
      #     # Tridactyl native connector
      #   };
      # };

      policies = {
        AutofillAddressEnabled = false;
        AutofillCreditCardEnabled = false;
        DisableAppUpdate = true;
        DisableFirefoxAccounts = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DontCheckDefaultBrowser = true;
        ExtensionSettings = {
          # Augmented Steam
          "{1be309c5-3e4f-4b99-927d-bb500eb4fa88}" = {
            installation_mode = "normal_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/augmented-steam/latest.xpi";
          };

          # Tridactyl
          "tridactyl.vim.betas@cmcaine.co.uk" = {
            installation_mode = "normal_installed";
            install_url = "https://tridactyl.cmcaine.co.uk/betas/tridactyl-latest.xpi";
          };

          # Fakespot
          "{44df5123-f715-9146-bfaa-c6e8d4461d44}" = {
            installation_mode = "normal_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/fakespot-fake-reviews-amazon/latest.xpi";
          };

          # uBlock
          "uBlock0@raymondhill.net" = {
            installation_mode = "normal_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          };

          # SponsorBlock
          "sponsorBlocker@ajay.app" = {
            installation_mode = "normal_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
          };

          # Styl-us
          "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = {
            installation_mode = "normal_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/styl-us/latest.xpi";
          };

          # Dark Reader
          "addon@darkreader.org" = {
            installation_mode = "normal_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
            # default_area = "navbar";
          };

          # Temp Containers
          "{c607c8df-14a7-4f28-894f-29e8722976af}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/temporary-containers/latest.xpi";
            installation_mode = "normal_installed";
          };

          # Smart Referer
          "smart-referer@meh.paranoid.pk" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/smart-referer/latest.xpi";
            installation_mode = "normal_installed";
          };

          # libredirect
          "7esoorv3@alefvanoon.anonaddy.me" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/libredirect/latest.xpi";
            installation_mode = "normal_installed";
          };

          # I don't care about cookies
          "idcac-pub@guus.ninja" = {
            installation_mode = "normal_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/istilldontcareaboutcookies/latest.xpi";
          };

          # 1Password
          "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
          };

          # Fire nvim
          "firenvim@lacamb.re" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/firenvim/latest.xpi";
            installation_mode = "normal_installed";
          };

          # Privacy Badger
          "jid1-MnnxcxisBPnSXQ@jetpack" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
          };
        };
        ManualAppUpdateOnly = true;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        PasswordManagerEnabled = false;
      };

      profiles.simonwjackson = {
        isDefault = true;
        settings = {
          "browser.uiCustomization.state" = ''
            {
               "placements": {
                 "widget-overflow-fixed-list": [],
                 "unified-extensions-area": [
                   "firenvim_lacamb_re-browser-action",
                   "_44df5123-f715-9146-bfaa-c6e8d4461d44_-browser-action",
                   "7esoorv3_alefvanoon_anonaddy_me-browser-action",
                   "idcac-pub_guus_ninja-browser-action",
                   "jid1-mnnxcxisbpnsxq_jetpack-browser-action",
                   "smart-referer_meh_paranoid_pk-browser-action",
                   "ublock0_raymondhill_net-browser-action",
                   "_7a7a4a92-a2a0-41d1-9fd7-1e92480d612d_-browser-action",
                   "_c607c8df-14a7-4f28-894f-29e8722976af_-browser-action",
                   "sponsorblocker_ajay_app-browser-action"
                 ],
                 "nav-bar": [
                   "customizableui-special-spring1",
                   "urlbar-container",
                   "customizableui-special-spring2",
                   "fxa-toolbar-menu-button",
                   "unified-extensions-button",
                   "addon_darkreader_org-browser-action",
                   "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action"
                 ],
                 "toolbar-menubar": [
                   "menubar-items"
                 ],
                 "TabsToolbar": [
                   "firefox-view-button",
                   "tabbrowser-tabs",
                   "new-tab-button",
                   "alltabs-button"
                 ],
                 "PersonalToolbar": [
                   "personal-bookmarks"
                 ]
               },
               "seen": [
                 "firenvim_lacamb_re-browser-action",
                 "_44df5123-f715-9146-bfaa-c6e8d4461d44_-browser-action",
                 "7esoorv3_alefvanoon_anonaddy_me-browser-action",
                 "addon_darkreader_org-browser-action",
                 "idcac-pub_guus_ninja-browser-action",
                 "jid1-mnnxcxisbpnsxq_jetpack-browser-action",
                 "smart-referer_meh_paranoid_pk-browser-action",
                 "ublock0_raymondhill_net-browser-action",
                 "_7a7a4a92-a2a0-41d1-9fd7-1e92480d612d_-browser-action",
                 "_c607c8df-14a7-4f28-894f-29e8722976af_-browser-action",
                 "sponsorblocker_ajay_app-browser-action",
                 "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action",
                 "developer-button"
               ],
               "dirtyAreaCache": [
                 "unified-extensions-area",
                 "nav-bar",
                 "toolbar-menubar",
                 "TabsToolbar",
                 "PersonalToolbar"
               ],
               "currentVersion": 20,
               "newElementCount": 3
             }
          '';
          # Firefox onebar
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "browser.tabs.firefox-view" = false;
          # end

          "devtools.chrome.enabled" = true; # Browser Toolbox
          "devtools.debugger.remote-enabled" = true; # Remote Debugging

          "signon.rememberSignons" = false;
          "browser.tabs.closeWindowWithLastTab" = true;
          "layout.css.prefers-color-scheme.content-override" = 2;
          "xpinstall.signatures.required" = false;
          "extensions.langpacks.signatures.required" = false;
          # Performance settings
          # "gfx.webrender.all" = true; # Force enable GPU acceleration
          "media.ffmpeg.vaapi.enabled" = true;
          "widget.dmabuf.force-enabled" = true; # Required in recent Firefoxes

          # Re-bind ctrl to super (would interfere with tridactyl otherwise)
          # "ui.key.accelKey" = 91;

          # Keep the reader button enabled at all times
          "reader.parse-on-load.force-enabled" = true;

          # Hide the "sharing indicator", it's especially annoying
          # with tiling WMs on wayland
          "privacy.webrtc.legacyGlobalIndicator" = false;

          # Actual settings
          "app.shield.optoutstudies.enabled" = false;
          "app.update.auto" = false;
          "browser.bookmarks.restore_default_bookmarks" = false;
          # "browser.contentblocking.category" = "strict";
          "browser.ctrlTab.recentlyUsedOrder" = false;
          "browser.discovery.enabled" = false;
          "browser.laterrun.enabled" = false;
          "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" =
            false;
          "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" =
            false;
          "browser.newtabpage.activity-stream.feeds.snippets" = false;
          "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.havePinned" = "";
          "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.searchEngines" = "";
          "browser.newtabpage.activity-stream.section.highlights.includePocket" =
            false;
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.newtabpage.pinned" = false;
          "browser.protections_panel.infoMessage.seen" = true;
          # "browser.quitShortcut.disabled" = true;
          "browser.shell.checkDefaultBrowser" = false;
          "browser.ssb.enabled" = true;
          "browser.toolbars.bookmarks.visibility" = "never";
          # "browser.urlbar.placeholderName" = "DuckDuckGo";
          "browser.urlbar.suggest.openpage" = false;
          "datareporting.policy.dataSubmissionEnable" = false;
          "datareporting.policy.dataSubmissionPolicyAcceptedVersion" = 2;
          # "dom.security.https_only_mode" = true;
          # "dom.security.https_only_mode_ever_enabled" = true;
          "extensions.getAddons.showPane" = false;
          "extensions.htmlaboutaddons.recommendations.enabled" = false;
          "extensions.pocket.enabled" = false;
          # "identity.fxaccounts.enabled" = false;
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
        };

        userChrome = builtins.readFile ./userChrome.css;
        userContent = builtins.readFile ./userContent.css;
      };
    };
  };
}
