# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: let
  inherit (lib.backpacker) enabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  backpacker = {
    hardware = {
      cpu.type = "intel";
      bluetooth = enabled;
    };
    desktop.plasma = enabled;
    gaming = {
      core = enabled;
      emulation = {
        enable = true;
        gen-7 = true;
      };
      steam = enabled;
    };
    performance = enabled;
    networking.core.names = [
      {
        name = "primary";
        mac = "68:fe:f7:11:c1:fd";
      }
    ];
    syncthing = {
      enable = false;
      # key = config.age.secrets.fiji-syncthing-key.path;
      # cert = config.age.secrets.fiji-syncthing-cert.path;
    };
  };

  #  swapDevices = [ { device = "/swap/swapfile"; } ];

  boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/e0301dfa-9f5a-4342-a1ae-8864536430ee";
    fsType = "btrfs";
    options = ["subvol=root" "compress=zstd"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/e0301dfa-9f5a-4342-a1ae-8864536430ee";
    fsType = "btrfs";
    options = ["subvol=home" "compress=zstd"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/e0301dfa-9f5a-4342-a1ae-8864536430ee";
    fsType = "btrfs";
    options = ["subvol=nix" "compress=zstd" "noatime"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/3411-11CB";
    fsType = "vfat";
  };

  system.stateVersion = "22.11"; # Did you read the comment?
}
