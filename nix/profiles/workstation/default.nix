{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkDefault mkEnableOption mkIf;

  cfg = config.mountainous.profiles.workstation;
in {
  options.mountainous.profiles.workstation = {
    enable = mkEnableOption "Whether to enable the shared workstation profile for desktops and laptops.";
  };

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson = {
      imports = [
        ../../modules/home/firefox
      ];

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
