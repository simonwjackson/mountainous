{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.mountainous.hardware.bluetooth;
in {
  options.mountainous.hardware.bluetooth = {
    enable = mkEnableOption "Whether to enable bluetooth";
  };

  config = mkIf cfg.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };
}
