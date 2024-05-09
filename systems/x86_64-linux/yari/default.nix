{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware.nix
    ./matrix.nix
    ./gotify.nix
  ];

  boot.loader.grub.device = "/dev/vda";
  boot.initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi"];
  boot.initrd.kernelModules = ["nvme"];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  zramSwap.enable = true;

  mountainous = {
    boot.type = "bios";
    printing.enable = false;
    hardware.cpu.type = "intel";
    networking = {
      tailscaled.exit-node = true;
      core.names = [
        {
          name = "eth";
          mac = "00:16:3e:c6:25:3e";
        }
      ];
    };
  };

  services.nginx.enable = true;
  networking.firewall.enable = true;

  system.stateVersion = "23.11";
}
