{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.loader = {
    systemd-boot = {
      enable = true;
      extraInstallCommands = ''
        # Mirror the primary ESP to the second NVMe for recovery if nvme0 fails.
        mkdir -p /boot/efi-backup
        ${pkgs.util-linux}/bin/mountpoint -q /boot/efi-backup || \
          ${pkgs.util-linux}/bin/mount /dev/disk/by-partlabel/disk-nvme1-ESP /boot/efi-backup
        ${pkgs.rsync}/bin/rsync -a --delete /boot/ /boot/efi-backup/
        ${pkgs.util-linux}/bin/umount /boot/efi-backup
      '';
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "uas"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = ["amdgpu"];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = lib.mkDefault true;
  };

  services = {
    fwupd.enable = lib.mkDefault true;
    xserver.videoDrivers = ["amdgpu"];
  };
}
