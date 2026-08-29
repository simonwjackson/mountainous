{
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    systemd-boot.extraInstallCommands = ''
      # Mirror ESP to second NVMe for boot redundancy
      ${pkgs.coreutils}/bin/mkdir -p /boot/efi-backup
      if ! ${pkgs.util-linux}/bin/mountpoint -q /boot/efi-backup; then
        ${pkgs.util-linux}/bin/mount /dev/disk/by-partlabel/disk-nvme1-ESP /boot/efi-backup || true
      fi
      # Only mirror when the backup ESP is genuinely mounted. If the mount
      # failed, skip rather than rsync /boot into a directory on itself, which
      # would recurse and fill the primary ESP. --exclude is a second guard.
      if ${pkgs.util-linux}/bin/mountpoint -q /boot/efi-backup; then
        ${pkgs.rsync}/bin/rsync -a --delete --exclude='/efi-backup' /boot/ /boot/efi-backup/
        ${pkgs.util-linux}/bin/umount /boot/efi-backup || true
      else
        echo "efi-backup: backup ESP unavailable; skipped ESP mirror to avoid recursion" >&2
      fi
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
