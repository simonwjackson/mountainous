{
  config,
  pkgs,
  inputs,
  lib,
  modulesPath,
  ...
}: let
  inherit (lib.mountainous) enabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  boot = {
    swraid.enable = true;
    initrd = {
      availableKernelModules = ["xhci_pci" "nvme" "usb_storage" "sd_mod"];
      kernelModules = ["dm-snapshot"];
    };
    kernelModules = ["kvm-intel"]; # Adjust to kvm-amd if using AMD
    extraModulePackages = [];
    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        zfsSupport = false;
        extraConfig = ''
          GRUB_PRELOAD_MODULES="part_gpt mdraid1x"
        '';
      };
    };
  };

  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;

  mountainous = {
    hardware.devices.dell-9710 = enabled;
    performance = enabled;
    syncthing = {
      key = config.age.secrets.fiji-syncthing-key.path;
      cert = config.age.secrets.fiji-syncthing-cert.path;
    };
  };

  system.stateVersion = "24.11";
}
