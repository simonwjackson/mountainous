{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.presets.workstation;
in {
  config = mkIf cfg.enable {
    networking.networkmanager.enable = mkDefault true;
  };
}
