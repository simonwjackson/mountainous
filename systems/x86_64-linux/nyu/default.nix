{
  modulesPath,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled disabled;
in {
  imports = [
  ];

  mountainous = {
    boot = disabled;
    disks = {
      frostbite = {
        enable = true;
        encrypted = false;
        device = "/dev/disk/by-id/usb-_USB_DISK_3.0_070D16680516C865-0:0";
        swapSize = "4G";
      };
    };
    gaming = {
      steam = disabled;
    };
    impermanence = enabled;
    profiles = {
      base = enabled;
      workstation = enabled;
    };
  };
  #
  system.stateVersion = "24.11";
}
