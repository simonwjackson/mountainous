{
  config,
  pkgs,
  lib,
  modulesPath,
  inputs,
  ...
}: {
  imports = [
    ./disko.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # NFS client utilities for mounting remote gaming storage
  environment.systemPackages = with pkgs; [
    nfs-utils
  ];

  # NFS mount for zao's gaming/games directory
  fileSystems."/snowscape/gaming/games" = {
    device = "zao:/games"; # zao exports /tundra/merged/iceberg/gaming as fsid=0 (NFS root)
    fsType = "nfs";
    options = [
      "nofail" # Don't fail boot if unavailable
      "_netdev" # This is a network mount
      "x-systemd.automount" # Only mount on access
      "noauto"
      "x-systemd.idle-timeout=600" # Unmount after 10 min idle
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
      "x-systemd.requires=tailscaled.service"
      "soft" # Don't hang on network issues
      "timeo=14"
      "nfsvers=4"
    ];
  };

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

    # Gaming feature with remote Steam library (kita always on same network as aka)
    gaming = {
      enable = true;
      library.remote = {
        enable = true;
        server = "aka";
      };

      # Citron - performance settings for Intel Iris Plus 655
      # Saves synced via Syncthing, games accessed via NFS from zao
      citron = {
        enable = true;
        keys = inputs.switch-prod-keys;
        savePath = "/snowscape/gaming/profiles/simonwjackson/progress/saves/nintendo-switch";
        gameDirectories = ["/snowscape/gaming/games/nintendo-switch"];
        graphics = {
          resolution = 0.5; # Low res for integrated GPU
          antiAliasing = "none"; # Disable AA for performance
          backend = "vulkan";
          asyncShaders = true;
          # FSR + 100 sharpness from base defaults
        };
      };
    };

    # Syncthing for gaming profiles sync (saves)
    syncthing = {
      enable = true;
      deviceId = "J6JEBGV-GDLTLZA-JKIS5PM-EYJ6IS5-QBDM3KP-LSGBR2D-S5VXSYE-TWMVYQ5";
      folders = {
        gaming-profiles = {
          path = "/snowscape/gaming/profiles";
          ignorePerms = true; # Shared storage - don't sync perms
        };
      };
    };

    # Directory structure for gaming storage
    directories.paths = {
      "/snowscape" = {
        owner = "root";
        group = "root";
        mode = "0755";
      };
      "/snowscape/gaming" = {
        owner = "simonwjackson";
        group = "users";
        mode = "0755";
      };
      "/snowscape/gaming/games" = {
        owner = "media";
        group = "media";
        mode = "0755";
      };
      "/snowscape/gaming/profiles" = {
        owner = "simonwjackson";
        group = "users";
        mode = "0755";
      };
    };

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
