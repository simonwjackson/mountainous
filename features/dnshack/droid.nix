{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.mountainous.features.dnshack;
  dnshack = pkgs.callPackage inputs.dnshack { };
  preloadPath = "${dnshack}/lib/libdnshackbridge.so";
  resolverPath = "${dnshack}/bin/dnshackresolver";
in {
  config = lib.mkIf cfg.enable {
    environment.packages = [ dnshack ];

    environment.sessionVariables = {
      DNSHACK_RESOLVER_CMD = resolverPath;
    } // lib.optionalAttrs cfg.preloadGlobally {
      LD_PRELOAD = preloadPath;
    };

    home-manager.config.home.sessionVariables = {
      DNSHACK_RESOLVER_CMD = resolverPath;
    } // lib.optionalAttrs cfg.preloadGlobally {
      LD_PRELOAD = preloadPath;
    };
  };
}
