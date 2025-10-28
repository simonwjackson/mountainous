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

  # Boot configuration for AYANEO AIR (AMD Ryzen 5 5560U)
  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "usb_storage"
        "sd_mod"
        "sdhci_pci"
      ];
      kernelModules = ["amdgpu"]; # Early KMS for AMD graphics
    };

    kernelModules = [
      "kvm-amd"       # AMD virtualization
      "amdgpu"        # AMD graphics driver
      "mt7921e"       # MediaTek WiFi 6E
      "btusb"         # Bluetooth
      "hid_multitouch" # Touchscreen
    ];

    extraModulePackages = [];

    # Kernel parameters optimized for AMD gaming handheld
    kernelParams = [
      # AMD GPU optimizations
      "amdgpu.ppfeaturemask=0xffffffff" # Enable all GPU power features
      "amdgpu.gpu_recovery=1"            # Enable GPU hang recovery
      "amdgpu.dc=1"                      # Display Core for better display
      "amdgpu.dpm=1"                     # Dynamic Power Management

      # AMD CPU power management
      "amd_pstate=active"                # Active P-state driver for better power

      # Power management for handheld
      "mem_sleep_default=deep"           # Deep sleep for better battery

      # Display
      "video=eDP-1:1920x1080@60"         # Force native resolution

      # Quiet boot
      "loglevel=4"
      "quiet"
      "splash"
    ];

    # systemd-boot (UEFI) - simpler than GRUB for single-boot systems
    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Limit generations (save space on 512GB)
        editor = false;          # Disable boot editor for security
      };
    };

    # Resume from hibernate
    resumeDevice = "/dev/disk/by-partlabel/disk-main-swap";
  };

  # Hardware configuration for AMD Ryzen 5 5560U (Zen 3) + Radeon Graphics
  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;

    # AMD Radeon Graphics (Cezanne)
    graphics = {
      enable = true;
      enable32Bit = true; # Essential for gaming (32-bit games/libraries)
      extraPackages = with pkgs; [
        # AMD Vulkan drivers
        amdvlk
        # AMD OpenCL
        rocm-opencl-icd
        rocm-opencl-runtime
        # Video acceleration
        libva
        libvdpau-va-gl
      ];
      extraPackages32 = with pkgs; [
        driversi686Linux.amdvlk # 32-bit Vulkan for older games
      ];
    };

    # Enable AMD GPU OpenCL support
    amdgpu.opencl.enable = true;
  };

  # Networking
  networking.hostName = "hotaka";
  networking.useDHCP = lib.mkDefault true;
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false; # Disable WiFi powersave for gaming

  # Enable profiles for gaming handheld
  mountainous = {
    profiles = {
      base.enable = true;
      gaming.enable = true; # Steam, gamemode, controllers, etc.
    };

    # Override base profile's impermanence - configure locally
    impermanence.enable = lib.mkForce false;
  };

  # Configure ephemeral root filesystem (tmpfs) for impermanence
  # This is managed by disko.nix's nodev section
  # (Root is tmpfs, persistent data at /tundra/permafrost)

  # Persistent storage on NVMe SSD
  # Override disko-generated config to use stable device path
  # No LUKS encryption - direct XFS partition
  fileSystems."/tundra/permafrost" = lib.mkForce {
    device = "/dev/disk/by-partlabel/disk-main-root";
    fsType = "xfs";
    neededForBoot = true;
    options = [
      "noatime"
      "nodiratime"
      "discard"
      "logbufs=8"
      "logbsize=256k"
      "largeio"
      "swalloc"
    ];
  };

  # Local impermanence configuration for hotaka (gaming handheld)
  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      # Core system
      "/nix" # Nix store must persist (large, contains all packages)
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/var/log"

      # Gaming-specific persistence (CRITICAL for gaming handheld!)
      "/var/lib/bluetooth" # Bluetooth pairings (controllers, headphones)

      # User home directory with gaming data
      {
        directory = "/home/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0700";
      }

      # User-specific Nix profiles
      {
        directory = "/nix/var/nix/profiles/per-user/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0755";
      }
    ];

    files = [
      "/etc/machine-id"
    ];
  };

  # Fix ownership of persistent directories on boot
  # Workaround for impermanence bug where parent directories are created with root ownership
  # See: https://github.com/nix-community/impermanence/issues/74
  systemd.tmpfiles.settings."10-persistent-ownership" = {
    "/tundra/permafrost/home/simonwjackson".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0700";
    };
    "/tundra/permafrost/nix/var/nix/profiles/per-user/simonwjackson".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0755";
    };
  };

  # SSH host keys in persistent storage
  # Keys are deployed via nixos-anywhere during initial installation
  services.openssh.hostKeys = [
    {
      path = "/tundra/permafrost/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/tundra/permafrost/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  # Handheld-specific services
  services = {
    # Enable thermald? No - AMD doesn't need it (Intel-specific)
    # thermald.enable = false;

    # Enable TLP for better battery life
    # (Choose either TLP or auto-cpufreq, not both!)
    tlp = {
      enable = true;
      settings = {
        # CPU governor
        CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        # CPU boost (turbo)
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 1; # Keep enabled for responsive gaming on battery

        # CPU performance scaling
        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 70; # Cap at 70% on battery for better life

        # Energy performance preference (EPP)
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

        # AMD GPU power management
        RADEON_DPM_PERF_LEVEL_ON_AC = "auto";
        RADEON_DPM_PERF_LEVEL_ON_BAT = "low";
        RADEON_DPM_STATE_ON_AC = "performance";
        RADEON_DPM_STATE_ON_BAT = "battery";

        # Disable USB autosuspend (breaks controllers)
        USB_AUTOSUSPEND = 0;

        # Platform profile (if supported by AYANEO)
        PLATFORM_PROFILE_ON_AC = "performance";
        PLATFORM_PROFILE_ON_BAT = "low-power";

        # Disk power management
        DISK_IDLE_SECS_ON_AC = 0;
        DISK_IDLE_SECS_ON_BAT = 2;
        MAX_LOST_WORK_SECS_ON_AC = 15;
        MAX_LOST_WORK_SECS_ON_BAT = 60;

        # WiFi power saving (disabled for gaming)
        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "off"; # Keep off even on battery for online gaming

        # Sound power saving
        SOUND_POWER_SAVE_ON_AC = 0;
        SOUND_POWER_SAVE_ON_BAT = 1;
      };
    };

    # ACPI event handling (lid, power button)
    acpid.enable = true;

    # Firmware updates
    fwupd.enable = true;

    # libinput for touchscreen
    libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = false;
        tapping = true;
        disableWhileTyping = false; # Handheld - no traditional typing
        accelProfile = "adaptive";
      };
    };
  };

  # Gamemode for automatic performance switching
  programs.gamemode.enable = true;

  # Steam with optimization
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true; # Steam Deck-like UI
  };

  # XFS-specific settings
  # XFS doesn't need special services, but ensure xfsprogs is available
  environment.systemPackages = with pkgs; [
    xfsprogs # XFS utilities (xfs_repair, xfs_info, etc.)
  ];

  # Suspend-then-hibernate for better battery life
  # Suspend for quick resume, hibernate after timeout for zero drain
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30min
  '';

  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "suspend";
    powerKey = "suspend";
    powerKeyLongPress = "poweroff";
  };

  # Handheld power management
  # Use schedutil governor (better for dynamic gaming workloads than performance/powersave)
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

  system.stateVersion = "25.05";
}
