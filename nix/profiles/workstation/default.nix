{
  config,
  lib,
  pkgs,
  cascade,
  ...
}: let
  inherit (lib) mkDefault mkEnableOption mkIf;

  cfg = config.mountainous.profiles.workstation;

  cascadeUserChrome = pkgs.writeText "mountainous-firefox-cascade.css" ''
    @import url("file://${cascade}/chrome/includes/cascade-config.css");
    @import url("file://${cascade}/chrome/includes/cascade-colours.css");

    @import url("file://${cascade}/chrome/includes/cascade-layout.css");
    @import url("file://${cascade}/chrome/includes/cascade-responsive.css");
    @import url("file://${cascade}/chrome/includes/cascade-floating-panel.css");

    @import url("file://${cascade}/chrome/includes/cascade-nav-bar.css");
    @import url("file://${cascade}/chrome/includes/cascade-tabs.css");

    @media (prefers-color-scheme: dark) {
      :root {
        --uc-identity-colour-blue: #7aa2f7;
        --uc-identity-colour-turquoise: #2ac3de;
        --uc-identity-colour-green: #9ece6a;
        --uc-identity-colour-yellow: #e0af68;
        --uc-identity-colour-orange: #ff9e64;
        --uc-identity-colour-red: #f7768e;
        --uc-identity-colour-pink: #ff75a0;
        --uc-identity-colour-purple: #bb9af7;

        --uc-base-colour: #1a1b26;
        --uc-highlight-colour: #24283b;
        --uc-inverted-colour: #c0caf5;
        --uc-muted-colour: #565f89;
        --uc-accent-colour: #7aa2f7;
      }
    }

    @media (prefers-color-scheme: light) {
      :root {
        --uc-identity-colour-blue: #2e7de9;
        --uc-identity-colour-turquoise: #007197;
        --uc-identity-colour-green: #587539;
        --uc-identity-colour-yellow: #8c6c3e;
        --uc-identity-colour-orange: #b15c00;
        --uc-identity-colour-red: #8c4351;
        --uc-identity-colour-pink: #c64343;
        --uc-identity-colour-purple: #7847bd;

        --uc-base-colour: #e1e2e7;
        --uc-highlight-colour: #d5d6db;
        --uc-inverted-colour: #3760bf;
        --uc-muted-colour: #848cb5;
        --uc-accent-colour: #2e7de9;
      }
    }
  '';
in {
  options.mountainous.profiles.workstation = {
    enable = mkEnableOption "Whether to enable the shared workstation profile for desktops and laptops.";
  };

  config = mkIf cfg.enable {
    programs.dconf.enable = mkDefault true;

    xdg.portal.extraPortals = [pkgs.darkman];
    xdg.portal.config.common."org.freedesktop.impl.portal.Settings" = ["darkman"];

    home-manager.users.simonwjackson = {
      imports = [
        ../../modules/home/firefox
        ../../modules/home/theme
      ];

      mountainous.theme = {
        enable = mkDefault true;
        defaultMode = mkDefault "dark";
      };

      home.packages = [pkgs.lazygit];

      programs.firefox.profiles.default = {
        settings = {
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        };
        userChrome = cascadeUserChrome;
      };

      mountainous.firefox = {
        enable = mkDefault true;
        extensions = mkDefault {
          "uBlock0@raymondhill.net" = {slug = "ublock-origin";};
          "addon@darkreader.org" = {slug = "darkreader";};
          "sponsorBlocker@ajay.app" = {slug = "sponsorblock";};
          "@react-devtools" = {slug = "react-devtools";};
          "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {slug = "1password-x-password-manager";};
          "{1be309c5-3e4f-4b99-927d-bb500eb4fa88}" = {slug = "augmented-steam";};
          "jid1-BYcQOfYfmBMd9A@jetpack" = {slug = "pushbullet";};
          "tridactyl.vim@cmcaine.co.uk" = {slug = "tridactyl-vim";};
          "ff2mpv@yossarian.net" = {slug = "ff2mpv";};
        };
        nativeMessagingHosts = mkDefault [pkgs.ff2mpv];
        extraPolicies = mkDefault {
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          DisablePocket = true;
        };
      };
    };
  };
}
