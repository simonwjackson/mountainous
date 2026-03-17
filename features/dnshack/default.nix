{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.dnshack;
in {
  options.mountainous.features.dnshack = {
    enable = mkEnableOption "Android DNS bridge via dnshack";

    preloadGlobally = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to export LD_PRELOAD globally for login sessions.";
    };
  };
}
