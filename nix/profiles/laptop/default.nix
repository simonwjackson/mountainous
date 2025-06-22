# This file (and the global directory) holds config that i use on all hosts
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption;
in {
  options.mountainous.profiles.laptop = {
    enable = mkEnableOption "Whether to enable the laptop profile.";
  };

  config = lib.mkIf config.mountainous.profiles.laptop.enable {
    mountainous = {
      hybrid-sleep = {
        enable = true;
        delay = 5;
        hibernate = true;
      };
    };

    environment.systemPackages = with pkgs; [
      acpi
    ];

    # Automatic timezone detection based on location
    services.automatic-timezoned.enable = true;
    services.geoclue2.enable = true;
    services.timesyncd.enable = true;

    services = {
      libinput = {
        enable = true;
        touchpad = {
          disableWhileTyping = true;
          tapping = true;
        };
      };
    };
  };
}
