{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      ../modules/workstation.nix
      #../modules/wireguard-client.nix
      ./default.nix
      (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "ehci_pci" "xhci_pci" "ohci_pci" "virtio_pci" "ahci" "usbhid" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

  swapDevices = [ ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # high-resolution display
  hardware.video.hidpi.enable = lib.mkDefault true;

  # Use the GRUB 2 boot loader.
  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;

  networking.hostName = "nixos";
  networking.interfaces.enp0s9.useDHCP = true;

  environment.variables.EDITOR = "nvim";
  programs.neovim.enable = true;
  programs.neovim.viAlias = true;

  hardware.pulseaudio.enable = true;
  hardware.bluetooth.enable = true;
}
