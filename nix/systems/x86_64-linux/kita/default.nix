{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    ./disko.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Boot configuration for Intel NUC8i3BEK (Coffee Lake i3-8109U)
  # RAID1 USB boot with GRUB for redundancy
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "thunderbolt" "ahci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];

    # Enable software RAID for:
    # - RAID1 USB boot (dual USB drives for redundancy)
    swraid = {
      enable = true;
      mdadmConf = ''
        MAILADDR nobody@nowhere
      '';
    };

    loader = {
      efi = {
        canTouchEfiVariables = false; # USB boot compatibility
        efiSysMountPoint = "/boot";
      };
      grub = {
        enable = true;
        # RAID1 boot: Install to both USB drives for redundancy
        devices = [
          "/dev/disk/by-id/usb-SanDisk_Ultra_Fit_4C530000230426119230-0:0"
          "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0322119070015232-0:0"
        ];
        efiSupport = true;
        efiInstallAsRemovable = true; # USB boot reliability
        copyKernels = true; # Kernel redundancy
        fsIdentifier = "uuid"; # UUID-based mounting
      };
    };
  };

  # Hardware configuration
  # Intel Iris Plus Graphics 655 (integrated only)
  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    bluetooth.enable = true;

    # Graphics configuration for Intel Iris Plus 655
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but sometimes works better)
        libvdpau-va-gl
      ];
      extraPackages32 = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
      ];
    };
  };

  # Networking
  networking.hostName = "kita";
  networking.useDHCP = lib.mkDefault true;

  # Enable profiles for desktop system
  mountainous = {
    profiles = {
      base.enable = true;
      workspace.enable = true;
      gaming.enable = true;
    };

    impermanence = {
      enable = true;
      persistFsType = "btrfs";

      # Disko handles /nix, not impermanence
      persistNixStore = false;

      # Kita-specific: persist logs for debugging
      persistLogs = true;

      # Extra directories beyond the base
      extraDirectories = [
        {
          directory = "/tundra/igloo";
          user = "simonwjackson";
          group = "users";
          mode = "0700";
        }
      ];
    };
  };

  # NUC power management
  # Always-on desktop system optimized for consistent performance
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  system.stateVersion = "25.05";
}
