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
      availableKernelModules = [
        "xhci_pci"
        "nvme"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [
        "dm-snapshot"
      ];
    };
    kernelModules = [
      "kvm-intel"
    ]; # Adjust to kvm-amd if using AMD
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
    boot.enable = false;
    hardware.devices.dell-9710 = enabled;
    performance = enabled;
    services = {
      photos = {
        enable = true;
        photos = "/net/unzen/nfs/snowscape/photos";
        address = {
          host = "192.168.200.1";
          client = "192.168.200.10";
        };
      };
      watch = {
        enable = true;
        address = {
          host = "192.168.200.1";
          client = "192.168.200.11";
        };
        paths = {
          music = "/net/unzen/nfs/snowscape/music/albums";
          videos = "/net/unzen/nfs/snowscape/videos";
        };
      };
    };
    syncthing = {
      key = config.age.secrets.fiji-syncthing-key.path;
      cert = config.age.secrets.fiji-syncthing-cert.path;
    };
  };

  networking = {
    nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      externalInterface = "enp48s0u2u4";
    };

    firewall = {
      enable = true;
    };
  };

  systemd.services."container@watch" = {
    requires = ["autofs.service"];
    after = ["autofs.service"];
    preStart = ''
      ls /net/unzen/nfs/snowscape >/dev/null 2>&1 || true
      sleep 10
    '';
  };

  systemd.services."container@photos" = {
    requires = ["autofs.service"];
    after = ["autofs.service"];
    preStart = ''
      ls /net/unzen/nfs/snowscape >/dev/null 2>&1 || true
      sleep 10
    '';
  };

  system.stateVersion = "24.11";
}
