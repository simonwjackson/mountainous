{
  config,
  inputs,
  lib,
  modulesPath,
  options,
  pkgs,
  ...
}: let
  inherit (lib.backpacker) enabled disabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_zen;

  backpacker = {
    hardware.cpu.type = "amd";
    syncthing = {
      enable = false;
    };
    # boot = disabled;
    gaming = {
      core = {
        enable = true;
      };
      # emulation = {
      #   enable = true;
      #   gen-7 = true;
      #   gen-8 = true;
      # };
      steam = enabled;
    };
    desktops = {
      plasma = enabled;
    };
    networking.core.names = [
      {
        name = "wifi";
        mac = "10:6f:d9:29:8e:97";
      }
    ];

    # BUG: ccache broken
    performance = disabled;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";
  services.displayManager.sddm.wayland.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
    initialPassword = "asdfasdfasdf";
    packages = with pkgs; [
      firefox
      tree
    ];
  };

  system.stateVersion = "24.05";

  ###### HARDWARE

  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "usbhid" "uas" "sd_mod" "rtsx_pci_sdmmc"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/743b84ee-0d30-4fd1-8bfd-96bd5ee71c79";
  #   fsType = "btrfs";
  #   options = ["subvol=root" "compress=zstd"];
  # };
  #
  # fileSystems."/home" = {
  #   device = "/dev/disk/by-uuid/743b84ee-0d30-4fd1-8bfd-96bd5ee71c79";
  #   fsType = "btrfs";
  #   options = ["subvol=home" "compress=zstd"];
  # };
  #
  # fileSystems."/snowscape" = {
  #   device = "/dev/disk/by-uuid/743b84ee-0d30-4fd1-8bfd-96bd5ee71c79";
  #   fsType = "btrfs";
  #   options = ["subvol=home"];
  # };
  #
  # fileSystems."/nix" = {
  #   device = "/dev/disk/by-uuid/743b84ee-0d30-4fd1-8bfd-96bd5ee71c79";
  #   fsType = "btrfs";
  #   options = ["subvol=nix" "compress=zstd" "noatime"];
  # };
  #
  # fileSystems."/boot" = {
  #   device = "/dev/disk/by-uuid/12CE-A600";
  #   fsType = "vfat";
  #   options = ["fmask=0022" "dmask=0022"];
  # };

  # disko.devices = {
  #   disk = {
  #     main = {
  #       type = "disk";
  #       device = "/dev/nvme0n1";
  #       content = {
  #         type = "table";
  #         format = "gpt";
  #         partitions = [
  #           {
  #             name = "boot";
  #             start = "0";
  #             end = "550M";
  #             fs-type = "vfat";
  #             bootable = true;
  #             content = {
  #               type = "filesystem";
  #               format = "vfat";
  #               mountpoint = "/boot";
  #               mountOptions = ["fmask=0022" "dmask=0022"];
  #             };
  #           }
  #           {
  #             name = "root";
  #             start = "550M";
  #             end = "100%";
  #             content = {
  #               type = "btrfs";
  #               extraArgs = ["-f"];
  #               subvolumes = {
  #                 "/root" = {
  #                   mountpoint = "/";
  #                   mountOptions = ["subvol=root" "compress=zstd"];
  #                 };
  #                 "/home" = {
  #                   mountpoint = "/home";
  #                   mountOptions = ["subvol=home" "compress=zstd"];
  #                 };
  #                 "/snowscape" = {
  #                   mountpoint = "/snowscape";
  #                   mountOptions = ["subvol=home" "compress=zstd"];
  #                 };
  #                 "/nix" = {
  #                   mountpoint = "/nix";
  #                   mountOptions = ["subvol=nix" "compress=zstd" "noatime"];
  #                 };
  #               };
  #             };
  #           }
  #         ];
  #       };
  #     };
  #   };
  # };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
