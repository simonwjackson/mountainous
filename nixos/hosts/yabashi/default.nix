{ config, pkgs, modulesPath, lib, ... }: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../profiles/global
    ../../users/simonwjackson
  ];

  boot = {
    tmp.cleanOnBoot = true;
    loader.grub.device = "/dev/vda";

    initrd = {
      availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
      kernelModules = [ "nvme" ];
    };
  };

  fileSystems."/" = { device = "/dev/vda1"; fsType = "ext4"; };
  swapDevices = [{ device = "/dev/vda2"; }];
  zramSwap.enable = false;

  networking.hostName = "yabashi";

  environment.systemPackages = with pkgs; [
    # tailscale # make the tailscale command usable to users
    neovim
    git
    tmux
    mosh
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
