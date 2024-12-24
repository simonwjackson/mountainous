{
  modulesPath,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled disabled;
in {
  boot = {
    kernelModules = [
      "nvme"
    ];
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
      };
    };
  };

  disko.devices.disk.sleet = {
    type = "disk";
    device = "/dev/disk/by-id/usb-Generic_STORAGE_DEVICE_000000000819-0:0";
    content = {
      type = "gpt";
      partitions = {
        data = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "f2fs";
            mountpoint = "/tundra/sleet";
            mountOptions = ["noatime"];
          };
        };
      };
    };
  };

  mountainous = {
    boot = enabled;
    disks = {
      frostbite = {
        enable = true;
        device = "/dev/disk/by-id/nvme-WDSN740-SDDPNQD-1T00-1004_22501B805583";
        swapSize = "16G";
      };
    };
    gaming = {
      core = enabled;
      steam = enabled;
    };
    hardware = {
      devices.samsung-galaxy-book3-360 = enabled;
    };
    impermanence = {
      enable = true;
    };
    networking.core.names = [
      {
        name = "wifi";
        mac = "d4:d8:53:90:2b:6c";
      }
    ];
    profiles = {
      base = enabled;
      laptop = enabled;
      workstation = enabled;
    };
    snowscape = {
      enable = true;
      glacier = "unzen";
      paths = [
        "/avalanche/volumes/blizzard"
        "/avalanche/disks/sleet/0/00"
      ];
    };
  };

  system.stateVersion = "24.11";
}
