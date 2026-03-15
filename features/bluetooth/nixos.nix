{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.features.bluetooth;
in {
  config = mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = mkDefault cfg.powerOnBoot;
    };
  };
}
