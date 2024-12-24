{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  inherit (lib.mountainous) enabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # disko.devices.disk.sleet = {
  #   type = "disk";
  #   device = "/dev/disk/by-id/usb-Generic_MassStorageClass_000000002958-0:0";
  #   content = {
  #     type = "gpt";
  #     partitions = {
  #       data = {
  #         size = "100%";
  #         content = {
  #           type = "filesystem";
  #           format = "f2fs";
  #           mountpoint = "/tundra/sleet";
  #           mountOptions = ["noatime"];
  #         };
  #       };
  #     };
  #   };
  # };

  mountainous = {
    services.gamescope-reaper.duration = 20;
    disks = {
      frostbite = {
        enable = true;
        encrypt = false;
        device = "/dev/disk/by-id/nvme-WD_PC_SN740_SDDPTQE-2T00_23328D402812";
        swapSize = "16G";
      };
    };
    gaming = {
      core = enabled;
      emulation = {
        enable = true;
        gen-7 = true;
        gen-8 = true;
      };
      steam = enabled;
    };
    hardware = {
      devices.gpd-win-mini = enabled;
    };
    impermanence = {
      enable = true;
    };
    networking.core.names = [
      {
        name = "wifi";
        mac = "e4:60:17:d1:e6:d8";
      }
    ];
    profiles = {
      base = enabled;
      laptop = enabled;
      workspace = enabled;
    };
    # snowscape = {
    #   enable = true;
    #   glacier = "unzen";
    #   paths = [
    #     "/avalanche/volumes/blizzard"
    #     "/avalanche/disks/sleet/0/00"
    #   ];
    # };
  };

  # WARN: Do not change this unless reinstalling
  system.stateVersion = "23.11";
}
