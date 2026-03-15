{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.mountainous.features.firefox;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.firefox = {
    enable = mkEnableOption "Firefox browser feature";

    cascade.enable = mkEnableOption "Cascade Firefox userChrome theme";

    userChrome = mkOption {
      type = types.nullOr types.lines;
      default = null;
      description = "Optional userChrome.css content for the default Firefox profile.";
    };

    extensions = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          slug = mkOption {
            type = types.str;
            description = "Mozilla add-on slug for the extension URL";
          };
          mode = mkOption {
            type = types.enum ["normal_installed" "force_installed" "allowed" "blocked"];
            default = "force_installed";
            description = "Installation mode for the extension";
          };
        };
      });
      default = {
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
      description = "Firefox extensions to install via policies.";
    };

    nativeMessagingHosts = mkOption {
      type = types.listOf types.package;
      default = [pkgs.ff2mpv];
      description = "Native messaging hosts to make available to Firefox extensions.";
    };

    lockExtensions = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of extension IDs that users cannot disable.";
    };

    extraPolicies = mkOption {
      type = types.attrs;
      default = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
      };
      description = "Additional Firefox policies to apply.";
    };

    extraPrefs = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional Firefox preferences for the default profile.";
    };
  };

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}
