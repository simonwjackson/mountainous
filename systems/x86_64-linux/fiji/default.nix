{
  config,
  inputs,
  lib,
  modulesPath,
  options,
  pkgs,
  ...
}: let
  inherit (lib.backpacker) enabled disabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  backpacker = {
    boot = enabled;
    desktops = {
      hyprland = {
        enable = true;
        autoLogin = true;
      };
    };
    networking.core.names = [
      {
        name = "wifi";
        mac = "d4:d8:53:90:2b:6c";
      }
    ];
    performance = enabled;
    profiles = {
      laptop = enabled;
      workspace = disabled;
    };
    syncthing = {
      key = config.age.secrets.fiji-syncthing-key.path;
      cert = config.age.secrets.fiji-syncthing-cert.path;
    };
  };

  mountainous = {
    hardware.devices.samsung-galaxy-book3-360 = enabled;
  };

  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-WDSN740-SDDPNQD-1T00-1004_22501B805583";
    content = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          name = "BOOT";
          start = "0";
          end = "1G";
          fs-type = "vfat";
          bootable = true;
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        }
        {
          name = "swap";
          start = "1G";
          end = "17G";
          part-type = "primary";
          content = {
            type = "swap";
            randomEncryption = false;
          };
        }
        {
          name = "root";
          start = "17G";
          end = "145G";
          part-type = "primary";
          content = {
            type = "btrfs";
            subvolumes = {
              "/" = {
                mountpoint = "/";
                mountOptions = ["compress=zstd"];
              };
              "/home" = {
                mountpoint = "/home";
                mountOptions = ["compress=zstd"];
              };
              "/nix" = {
                mountpoint = "/nix";
                mountOptions = ["compress=zstd" "noatime"];
              };
            };
          };
        }
        {
          name = "snowscape";
          start = "145G";
          end = "100%";
          part-type = "primary";
          content = {
            type = "filesystem";
            format = "xfs";
            mountpoint = "/glacier/snowscape";
          };
        }
      ];
    };
  };

  fileSystems."/home/simonwjackson/documents" = {
    device = "/glacier/snowscape/documents";
    options = ["bind"];
  };

  system.stateVersion = "23.05"; # Did you read the comment?
}
