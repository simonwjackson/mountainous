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
    environment.systemPackages = with pkgs; [
      acpi
    ];

    networking.networkmanager.wifi.powersave = lib.mkDefault true;

    services = {
      geoclue2 = {
        enable = true;
        # Enable demo agent to keep GeoClue alive for system services
        enableDemoAgent = true;
        # BeaconDB - community replacement for defunct Mozilla Location Services
        geoProviderUrl = "https://api.beacondb.net/v1/geolocate";
        submissionUrl = "https://api.beacondb.net/v2/geosubmit";
        # Allow automatic-timezoned and gammastep to use geoclue
        appConfig = {
          "automatic-timezoned" = {
            isAllowed = true;
            isSystem = true;
            users = [];
          };
          "gammastep" = {
            isAllowed = true;
            isSystem = false;
            users = [];
          };
        };
      };
      avahi = {
        enable = true;
        nssmdns4 = true;
        nssmdns6 = true;
      };
      timesyncd.enable = lib.mkDefault true;
      tlp.enable = lib.mkDefault true;
      thermald.enable = lib.mkDefault (config.hardware.cpu.intel.updateMicrocode or false);
      power-profiles-daemon.enable = lib.mkDefault false;
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
