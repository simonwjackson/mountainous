{lib, pkgs, modulesPath, ...}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    systemd-boot.extraInstallCommands = ''
      # Mirror ESP to second NVMe for boot redundancy
      mkdir -p /boot/efi-backup
      ${pkgs.util-linux}/bin/mountpoint -q /boot/efi-backup || \
        ${pkgs.util-linux}/bin/mount /dev/disk/by-partlabel/disk-nvme1-ESP /boot/efi-backup
      ${pkgs.rsync}/bin/rsync -a --delete /boot/ /boot/efi-backup/
      ${pkgs.util-linux}/bin/umount /boot/efi-backup
    '';
  };

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "uas"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];

  boot.kernelModules = ["kvm-intel"];

  nixpkgs.hostPlatform = "x86_64-linux";

  hardware = {
    cpu.intel.updateMicrocode = true;
    enableRedistributableFirmware = lib.mkDefault true;
    i2c.enable = lib.mkDefault true;
    nvidia = {
      modesetting.enable = true;
      open = false;
      powerManagement.enable = lib.mkDefault true;
      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };

  security.tpm2.enable = lib.mkDefault true;

  services = {
    fwupd.enable = lib.mkDefault true;
    thermald.enable = lib.mkDefault true;
    hardware.bolt.enable = lib.mkDefault true;
    xserver.videoDrivers = ["nvidia"];
  };
}
