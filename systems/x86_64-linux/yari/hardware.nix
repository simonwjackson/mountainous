{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}: {
  imports = [(modulesPath + "/profiles/qemu-guest.nix")];

  mountainous.boot.type = "bios";
  mountainous.printing.enable = false;

  boot.loader.grub.device = "/dev/vda";
  boot.initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi"];
  boot.initrd.kernelModules = ["nvme"];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };
}
