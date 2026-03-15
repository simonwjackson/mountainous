{
  osConfig,
  lib,
  ...
}: let
  cfg = osConfig.mountainous.features.firefox;

  mkExtensionSettings = extensions:
    lib.mapAttrs (_: ext: {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/${ext.slug}/latest.xpi";
      installation_mode = ext.mode;
    })
    extensions;
in {
  config = lib.mkIf cfg.enable {
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

      profiles.default =
        {
          id = 0;
          name = "default";
          isDefault = true;
          settings =
            {
              "toolkit.legacyUserProfileCustomizations.stylesheets" = lib.mkDefault true;
            }
            // cfg.extraPrefs;
        }
        // lib.optionalAttrs (cfg.userChrome != null) {
          userChrome = cfg.userChrome;
        };
    };
  };
}
