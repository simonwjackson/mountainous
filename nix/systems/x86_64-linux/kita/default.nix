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

  # Auto-discovery NFS mounts via autofs with optimized options
  # Access any host's exports at /net/<hostname>/<export-path>
  # e.g., /net/aka/snowscape/gaming/games/steam
  services.autofs = {
    enable = true;
    autoMaster = let
      # Performance-optimized NFS options for read-heavy gaming workloads
      nfsOpts = "nfsvers=4,soft,nocto,async,timeo=14,retrans=2";
    in ''
      /net -hosts -${nfsOpts} --timeout=600
    '';
  };

  # NFS client utilities
  environment.systemPackages = with pkgs; [nfs-utils];

  # Boot configuration for Intel NUC8i3BEK (Coffee Lake i3-8109U)
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "thunderbolt" "ahci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];

    loader = {
      efi.canTouchEfiVariables = false;
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "/dev/disk/by-id/ata-KINGSTON_SUV500M8240G_50026B7683B6CE9D";
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
    };

    # Gaming with Steam - games accessed via autofs from aka
    # Steam library available at /net/aka/snowscape/gaming/games/steam
    gaming.enable = true;

    impermanence = {
      enable = true;
      persistFsType = "btrfs";

      # Create @nix subvolume for Nix store
      persistNixStore = true;

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
