{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption;
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.waydriod;
in {
  options.mountainous.waydriod = {
    enable = mkEnableOption "Whether to enable waydriod";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.waydroid = enabled;
  };
}
