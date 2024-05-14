{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.profiles.laptop;
in {
  options.mountainous.profiles.laptop = {
    enable = lib.mkEnableOption "Whether to enable laptop configurations";
  };

  config = lib.mkIf cfg.enable {
    mountainous = {
      hardware = {
        touchpad = enabled;
        battery = enabled;
        hybrid-sleep = enabled;
      };
    };

    environment.systemPackages = with pkgs; [
      acpi
    ];
  };
}
