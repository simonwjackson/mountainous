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

  # ============================================================================
  # BOOT CONFIGURATION - AMD Ryzen AI 9 HX 370 (Zen 5) Gaming Handheld
  # ============================================================================
  boot = {
    # Zen kernel for gaming performance and latest hardware support
    kernelPackages = pkgs.linuxPackages_zen;

    initrd = {
      availableKernelModules = [
        "nvme" # NVMe SSD support
        "xhci_pci" # USB 3.x controller
        "thunderbolt" # USB4/Thunderbolt support
        "usb_storage" # USB storage devices
        "sd_mod" # SD card reader
      ];
      kernelModules = ["amdgpu"]; # Early KMS for AMD Radeon 890M (Strix/RDNA 3.5)
    };

    kernelModules = [
      "kvm-amd" # AMD virtualization
      "amdgpu" # AMD graphics driver
      "iwlwifi" # Intel Wi-Fi 6E AX210
      "btusb" # Bluetooth support
    ];

    extraModulePackages = [];

    # Kernel parameters optimized for AMD Strix gaming handheld
    kernelParams = [
      # Resume device for hibernation (must match swap partition)
      "resume=/dev/disk/by-partlabel/disk-main-swap"

      # AMD GPU optimizations for Radeon 890M (Strix/RDNA 3.5)
      "amdgpu.ppfeaturemask=0xffffffff" # Enable all GPU power features
      "amdgpu.gpu_recovery=1" # Enable GPU hang recovery
      "amdgpu.dc=1" # Display Core for better display
      "amdgpu.dpm=1" # Dynamic Power Management

      # AMD CPU power management (Zen 5 architecture)
      "amd_pstate=active" # Active P-state driver for better power/performance

      # Power management for portable gaming device
      "mem_sleep_default=deep" # Deep sleep for better battery life

      # NVMe power state fix - critical for AMD sleep/wake reliability
      # Prevents NVMe drive from entering problematic power states during suspend
      "nvme_core.default_ps_max_latency_us=0"

      # Display - let amdgpu KMS auto-detect native resolution
      "fbcon=nodefer" # Earlier framebuffer initialization

      # Quiet boot
      "loglevel=4"
      "quiet"
      "splash"
    ];

    # systemd-boot (UEFI) - simpler than GRUB for single-boot UEFI systems
    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Limit generations to save space
        editor = false; # Disable boot editor for security
      };
    };

    # Resume from hibernate
    resumeDevice = "/dev/disk/by-partlabel/disk-main-swap";
  };

  # ============================================================================
  # HARDWARE CONFIGURATION - AMD Ryzen AI 9 HX 370 + Radeon 890M
  # ============================================================================
  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;

    # Bluetooth configuration (Intel AX210 integrated)
    bluetooth = {
      enable = true;
      powerOnBoot = true; # Power on Bluetooth adapter on boot
      # Enable experimental features for better codec support (headphones, controllers)
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };

    # AMD Radeon 890M Graphics (Strix/RDNA 3.5 integrated GPU)
    graphics = {
      enable = true;
      enable32Bit = true; # Essential for gaming (32-bit games/libraries)
      extraPackages = with pkgs; [
        # Video acceleration
        libva
        libvdpau-va-gl
      ];
    };

    # Enable AMD GPU OpenCL support (for compute workloads)
    amdgpu.opencl.enable = true;
  };

  # ============================================================================
  # NETWORKING
  # ============================================================================
  networking = {
    hostName = "kuju";
    useDHCP = lib.mkDefault true;
    networkmanager.enable = true;
    networkmanager.wifi.powersave = false; # Disable WiFi powersave for gaming
  };

  # ============================================================================
  # MOUNTAINOUS CONFIGURATION - Gaming Handheld Profile
  # ============================================================================
  mountainous = {
    profiles = {
      base.enable = true;
      laptop.enable = true; # Portable device features (battery, power management)
      gaming.enable = true; # Gaming-specific features
    };

    # Device configuration: portable gaming handheld
    device = {
      role = "portable"; # Usage: mobile gaming, battery-conscious
      capabilities = {
        battery = true;
        touchscreen = false; # GPD Win Max 2 style has keyboard/trackpad, not touchscreen
        formFactor = "handheld";
      };
    };

    # Impermanence - ephemeral root with persistent storage
    # Using mountainous impermanence module for managed persistence
    impermanence = {
      enable = true;
      persistFsType = "btrfs";

      # Create @nix subvolume for Nix store (already in disko.nix)
      persistNixStore = true;

      # Persist logs for debugging gaming issues
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

  # ============================================================================
  # SERVICES - Gaming Handheld Optimizations
  # ============================================================================
  services = {
    # SSD optimization (TRIM for NVMe)
    fstrim.enable = true;

    # ACPI event handling (power button, lid)
    acpid.enable = true;

    # Firmware updates
    fwupd.enable = true;

    # Blueman: Bluetooth manager GUI (for pairing controllers, headphones)
    blueman.enable = true;
  };

  # Suspend-then-hibernate for better battery life
  # Suspend for quick resume, hibernate after timeout for zero drain
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m
  '';

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandlePowerKey = "suspend-then-hibernate";
    HandlePowerKeyLongPress = "poweroff";
  };

  # ============================================================================
  # POWER MANAGEMENT - Portable Gaming Device
  # ============================================================================
  # Use schedutil governor (better for dynamic gaming workloads than performance/powersave)
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

  # Additional Steam configuration (base Steam handled by gaming profile)
  programs.steam = {
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true; # Steam Deck-like UI for handheld mode
  };

  # ============================================================================
  # USER CONFIGURATION
  # ============================================================================
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video"];
    openssh.authorizedKeys.keyFiles = [
      ../../../modules/nixos/user/id_rsa.pub
    ];
  };

  system.stateVersion = "25.05";
}
