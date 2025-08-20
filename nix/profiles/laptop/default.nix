# This file (and the global directory) holds config that i use on all hosts
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (lib) mkEnableOption;
in {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  options.mountainous.profiles.laptop = {
    enable = mkEnableOption "Whether to enable the laptop profile.";
  };

  config = lib.mkIf config.mountainous.profiles.laptop.enable {
    mountainous = {
      hybrid-sleep = {
        enable = true;
        delay = 60; # Changed from 5 minutes to 60 minutes (1 hour)
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

    # Automatic blue light filtering based on location
    # Uses manual coordinates as geoclue2 requires additional configuration
    # Coordinates default to Austin, TX area but will update with timezone changes
    home-manager.users.simonwjackson = {
      services.gammastep = {
        enable = true;
        provider = "geoclue2";
        temperature = {
          day = 6500;
          night = 3500;
        };
        settings = {
          general = {
            adjustment-method = "wayland";
            fade = 1; # Smooth transitions
          };
        };
      };
    };
  };
}
