{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.bluetooth;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.bluetooth = {
    enable = mkEnableOption "Bluetooth support";

    powerOnBoot = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to power on the Bluetooth adapter during boot.";
    };
  };
}
