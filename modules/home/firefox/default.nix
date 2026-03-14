{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;

  cfg = config.mountainous.firefox;

  # Helper function to create extension settings
  mkExtensionSettings = extensions:
    lib.mapAttrs (id: ext: {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/${ext.slug}/latest.xpi";
      installation_mode = ext.mode;
    })
    extensions;
in {
  options.mountainous.firefox = {
    enable = mkEnableOption "Whether to enable Firefox with declarative extensions";

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
      default = {};
      description = "Firefox extensions to install via policies";
      example = lib.literalExpression ''
        {
          "uBlock0@raymondhill.net" = {
            slug = "ublock-origin";
            mode = "normal_installed";
          };
        }
      '';
    };

    nativeMessagingHosts = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Native messaging hosts to make available to Firefox extensions";
      example = lib.literalExpression "[ pkgs.ff2mpv ]";
    };

    lockExtensions = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of extension IDs that users cannot disable";
      example = ["uBlock0@raymondhill.net"];
    };

    extraPolicies = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional Firefox policies to apply";
      example = lib.literalExpression ''
        {
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          DisablePocket = true;
        }
      '';
    };

    extraPrefs = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional Firefox preferences";
      example = lib.literalExpression ''
        {
          "browser.startup.homepage" = "about:blank";
          "browser.search.defaultenginename" = "DuckDuckGo";
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      nativeMessagingHosts = cfg.nativeMessagingHosts;

      policies = lib.mkMerge [
        {
          ExtensionSettings = mkExtensionSettings cfg.extensions;
        }

        (lib.optionalAttrs (cfg.lockExtensions != []) {
          Extensions.Locked = cfg.lockExtensions;
        })

        cfg.extraPolicies
      ];

      profiles.default = {
        id = 0;
        name = "default";
        isDefault = true;
        settings = cfg.extraPrefs;
      };
    };
  };
}
