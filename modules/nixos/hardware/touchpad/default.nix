{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.hardware.touchpad;
in {
  options.mountainous.hardware.touchpad = {
    enable = lib.mkEnableOption "Whether to enable touchpad configs";
  };

  config = lib.mkIf cfg.enable {
    services.libinput.enable = true;
    services.libinput.touchpad.disableWhileTyping = true;
    services.libinput.touchpad.tapping = true;
  };
}
