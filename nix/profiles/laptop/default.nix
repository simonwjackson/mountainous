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
        delay = 60;  # Changed from 5 minutes to 60 minutes (1 hour)
        hibernate = true;
      };
    };

    environment.systemPackages = with pkgs; [
      acpi
    ];

    # Automatic timezone detection based on location
    services.automatic-timezoned.enable = true;
    services.geoclue2 = {
      enable = true;
      # Enable avahi for local network discovery
      enableDemoAgent = false;
      geoProviderUrl = "https://location.services.mozilla.com/v1/geolocate?key=geoclue";
    };
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
    };
    services.timesyncd.enable = lib.mkDefault true;

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
