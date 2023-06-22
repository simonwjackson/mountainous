{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../modules/syncthing.nix
    ../../modules/tailscale.nix
    ../../modules/networking.nix
    ../../profiles/_common.nix
    ../../users/simonwjackson
  ];

  networking.hostName = "yari";

  # Use the systemd-boot EFI boot loader.

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/b8fa3f29-0374-4570-97c0-9bf6af48c0ad";
    fsType = "ext4";
  };

  fileSystems."/home/simonwjackson/downloads" = {
    device = "unzen:/tank/downloads";
    fsType = "nfs";
  };

  fileSystems."/home/simonwjackson/documents" = {
    device = "unzen:/tank/documents";
    fsType = "nfs";
  };

  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      neovim
      tmux
      git
      mosh
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  services.syncthing = {
    dataDir = "/home/simonwjackson"; # Default folder for new synced folders
    extraFlags = [
      "-gui-address=0.0.0.0:8384"
    ];

    folders = {
      code.path = "/home/simonwjackson/code";
      code.devices = [ "fiji" "unzen" "yari" "kita" ];
    };
  };

  services.xserver.libinput.enable = true;

  system.stateVersion = "23.05"; # Did you read the comment?
}
