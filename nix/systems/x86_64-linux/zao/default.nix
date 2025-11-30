{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  # Boot configuration for 11th Gen Intel Core i9-11900H (Tiger Lake)
  # Dual USB boot with GRUB for redundancy, btrfs RAID for storage
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "uas" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];

    # Zen kernel for low-latency game streaming (Sunshine) and media server (Jellyfin)
    # Matches aka and hotaka gaming systems for fleet consistency
    kernelPackages = pkgs.linuxPackages_zen;

    # Kernel parameters for server performance and stability
    kernelParams = [
      "nvme_core.default_ps_max_latency_us=0" # Prevent NVMe power state issues
      "intel_pstate=active" # Use Intel P-state driver
    ];

    loader = {
      efi.canTouchEfiVariables = false;
      efi.efiSysMountPoint = "/boot";
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true; # Install to /EFI/BOOT/BOOTX64.EFI for SD card
        device = "nodev"; # EFI only, no MBR
      };
    };
  };

  # Hardware configuration
  # Hybrid graphics: Intel integrated (i915) + NVIDIA RTX 3060 Mobile
  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    bluetooth.enable = true;

    # NVIDIA proprietary drivers with Prime offload
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = lib.mkDefault true;
      powerManagement.finegrained = false;
      open = false; # Use proprietary driver, not open source kernel modules
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      # Prime configuration for hybrid graphics
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # Bus IDs detected from system
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };

    # Graphics configuration for hybrid GPU setup
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but sometimes works better)
        libva-vdpau-driver
        libvdpau-va-gl
      ];
      extraPackages32 = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
      ];
    };
  };

  # Load NVIDIA driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  # Hardware monitoring and maintenance tools
  environment.systemPackages = with pkgs; [
    # Storage health
    smartmontools # SMART monitoring (smartctl)
    nvme-cli # NVMe health and management
    btrfs-progs # Btrfs utilities (scrub, balance, etc.)

    # System monitoring
    lm_sensors # Temperature monitoring
    htop # Process monitor
    btop # Beautiful system monitor

    # Hardware info
    pciutils # lspci
    usbutils # lsusb
    dmidecode # Hardware info
  ];

  # Networking
  networking.hostName = "zao";
  networking.useDHCP = lib.mkDefault true;

  # Ensure persistent storage is available during boot for impermanence
  fileSystems."/tundra/permafrost".neededForBoot = true;

  # Thunderbolt networking to Mac Mini (via WD19TB dock)
  # Provides high-speed direct connection (~20-40 Gbps) for file transfers
  networking.interfaces.thunderbolt0 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = "192.168.2.1";
        prefixLength = 24;
      }
    ];
  };

  # Enable profiles for desktop/gaming server
  mountainous = {
    profiles = {
      base.enable = true;
      workspace.enable = true;
    };

    # Device configuration: laptop chassis used as headless server
    device = {
      role = "server"; # Usage: runs 24/7, serves game streams
      capabilities = {
        battery = true; # Has battery (graceful shutdown on power loss)
        formFactor = "laptop"; # Thermal profile of a laptop
        touchscreen = false;
      };
    };

    # Unified gaming feature (reads from device.role/traits)
    gaming = {
      enable = true;

      # Enable game streaming with Sunshine
      streaming = {
        enable = true;
        monitors.primary = "DP-1"; # Virtual display for streaming
      };
    };

    # Unified impermanence configuration
    # Note: /nix and /var/log are separate btrfs subvolumes managed by disko
    impermanence = {
      enable = true;
      # Persistent storage is managed by disko, so we don't specify persistDevice
      # The mount is already configured in disko.nix
      persistDevice = null; # Managed by disko.nix
      persistFsType = "btrfs";

      # zao-specific persistence: /tundra/igloo directory
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

  # Fix ownership for zao-specific persistent directory
  # The base impermanence feature handles home and nix profiles,
  # but we need to add our custom /tundra/igloo directory
  systemd.tmpfiles.settings."10-persistent-ownership" = {
    "/tundra/permafrost/tundra/igloo".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0700";
    };
  };

  # Storage and disk health maintenance
  # Btrfs maintenance - critical for RAID0 data integrity
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = ["/tundra/permafrost"];
  };

  # SSD TRIM maintenance (weekly)
  services.fstrim.enable = true;

  # SMART monitoring for NVMe health
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications = {
      wall.enable = true;
      x11.enable = false;
    };
  };

  # Server-specific optimizations for always-plugged-in laptop
  # Intel thermal management - prevents throttling and manages temps
  services.thermald.enable = true;

  # Disable battery-saving features since this runs as a server
  services.auto-cpufreq.enable = lib.mkForce false;

  # Prevent sleep/suspend - keep server running 24/7
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore"; # Don't suspend when lid closes
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "ignore";
    IdleAction = "ignore";
  };

  # CPU governor for consistent performance (not battery optimization)
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  system.stateVersion = "25.05";
}
