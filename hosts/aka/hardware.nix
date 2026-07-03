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
