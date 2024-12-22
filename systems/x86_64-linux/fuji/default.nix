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
    (import ./disko.nix {
      device = "/dev/disk/by-id/nvme-WDSN740-SDDPNQD-1T00-1004_22501B805583";
    })
  ];

  boot = {
    supportedFilesystems = ["btrfs"]; # Keep your existing filesystems
    kernelModules = [
      "cryptd"
      "aesni_intel"
      "dm_mod"
      "nvme"
    ];
    loader = {
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
      systemd-boot = {
        enable = true;
      };
    };
    initrd = {
      availableKernelModules = [
        "ahci"
        "btrfs"
        "cryptd"
        "crypto_aes"
        "ehci_pci"
        "sd_mod"
        "uas"
        "usb_storage"
        "usbhid"
        "xhci_pci"
      ];
    };
  };

  mountainous = {
    boot = enabled;
    gaming = {
      core = enabled;
      steam = enabled;
    };
    hardware = {
      bluetooth.device = "D4:D8:53:90:2B:70";
      devices.samsung-galaxy-book3-360 = enabled;
    };
    impermanence = {
      enable = true;
      persistPath = "/tundra/permafrost";
    };
    networking.core.names = [
      {
        name = "wifi";
        mac = "d4:d8:53:90:2b:6c";
      }
    ];
    profiles = {
      laptop = enabled;
      workspace = disabled;
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
    syncthing = {
      key = config.age.secrets.fuji-syncthing-key.path;
      cert = config.age.secrets.fuji-syncthing-cert.path;
    };
  };

  system.stateVersion = "24.11";
}
