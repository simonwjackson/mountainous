# ==============================================================================
# KUJU - GPD Win Mini 2025 (AMD Ryzen AI 9 HX 370)
# ==============================================================================
#
# BATTERY OPTIMIZATION NOTES:
# ---------------------------
# This config is tuned for MAXIMUM BATTERY LIFE. Key features:
# - auto-cpufreq: Automatic governor switching (powersave on battery)
# - Turbo disabled on battery (saves significant power)
# - CPU capped at 2GHz on battery (prevents power spikes)
# - USB/PCI autosuspend enabled
# - AMD GPU forced to low power on battery
# - powertop auto-tune enabled
#
# WARNING: Gaming on battery will be SLOW with default settings!
# Use the "GAMING ON BATTERY" commands below to unlock performance.
#
# ==============================================================================
# GAMING ON BATTERY (run before launching game)
# ==============================================================================
#
# ENABLE GAMING MODE:
#   # Unlock CPU (allow turbo, remove frequency cap)
#   sudo auto-cpufreq --force performance
#
#   # Unlock GPU (allow dynamic clocking)
#   echo "auto" | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
#
#   # Set TDP for gaming (18-25W is good balance of performance vs battery)
#   sudo ryzenadj --stapm-limit=20000 --fast-limit=25000 --slow-limit=20000
#
# RETURN TO BATTERY SAVER (after gaming):
#   # Re-enable auto-cpufreq battery management
#   sudo auto-cpufreq --force reset
#
#   # Lock GPU to low power
#   echo "low" | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
#
#   # Set ultra-low TDP
#   sudo ryzenadj --stapm-limit=10000 --fast-limit=12000 --slow-limit=10000
#
# ==============================================================================
# AFTER FIRST BOOT
# ==============================================================================
#
# 1. Calibrate fan control sensors:
#      sudo sensors-detect    # Detect available sensors
#      sudo pwmconfig         # Generate fan curve config
#    Then update hardware.fancontrol.config below with correct hwmon paths
#
# 2. Test display rotation:
#    If screen is rotated wrong, adjust transform value in home.nix:
#      transform,1 = 90° clockwise
#      transform,3 = 90° counter-clockwise
#
# 3. Check power consumption:
#      sudo powertop          # Analyze power usage
#      auto-cpufreq --stats   # Check CPU frequency/governor
#
# ==============================================================================
# TDP REFERENCE (ryzenadj values in milliwatts)
# ==============================================================================
#
#   ULTRA-LOW (reading, browsing):
#     ryzenadj --stapm-limit=8000 --fast-limit=10000 --slow-limit=8000
#
#   BATTERY SAVER (light tasks):
#     ryzenadj --stapm-limit=10000 --fast-limit=12000 --slow-limit=10000
#
#   BALANCED (general use):
#     ryzenadj --stapm-limit=15000 --fast-limit=18000 --slow-limit=15000
#
#   GAMING ON BATTERY:
#     ryzenadj --stapm-limit=20000 --fast-limit=25000 --slow-limit=20000
#
#   GAMING PLUGGED IN:
#     ryzenadj --stapm-limit=28000 --fast-limit=35000 --slow-limit=28000
#
#   MAX PERFORMANCE (benchmarks, thermals will spike):
#     ryzenadj --stapm-limit=35000 --fast-limit=40000 --slow-limit=35000
#
# ==============================================================================
{
  config,
  pkgs,
  lib,
  inputs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    inputs.gpd-fan-driver.nixosModules.default
  ];

  # ============================================================================
  # BOOT CONFIGURATION - AMD Ryzen AI 9 HX 370 (Zen 5) Gaming Handheld
  # ============================================================================
  # Reference: nixos-hardware has gpd-win-max-2-2023 module, but 2025 model
  # has different quirks (AMD Ryzen AI 9 HX 370 vs older Intel/AMD models)
  # ============================================================================
  boot = {
    # Zen kernel for gaming performance and latest hardware support
    # Requires 6.12+ for proper AMD Strix GPU support
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

    # Blacklist conflicting BMI160 modules for proper BMI260 sensor support
    # GPD Win Max 2 2025 uses BMI260 IMU, needs IIO subsystem instead
    blacklistedKernelModules = [
      "bmi160_spi"
      "bmi160_i2c"
      "bmi160_core"
    ];

    extraModulePackages = [];

    # Kernel parameters optimized for AMD Strix gaming handheld
    kernelParams = [
      # Resume device for hibernation (must match swap partition)
      "resume=/dev/disk/by-partlabel/disk-main-swap"

      # ========================================================================
      # AMD GPU optimizations for Radeon 890M (Strix/RDNA 3.5)
      # ========================================================================
      # CRITICAL: Fix VCN ring timeout issues on RDNA 3.5
      # Disables VCN (Video Core Next) DPG (Dynamic Power Gating)
      # Without this, GPU may hang during video decode/encode operations
      "amdgpu.ppfeaturemask=0xfffd7fff"

      "amdgpu.gpu_recovery=1" # Enable GPU hang recovery
      "amdgpu.dc=1" # Display Core for better display
      "amdgpu.dpm=1" # Dynamic Power Management

      # CRITICAL: Disable PSR (Panel Self Refresh) - fixes screen staying on during suspend
      # and random display freezes on AMD Ryzen AI 9 HX 370
      # Reference: https://bugs.launchpad.net/bugs/2111739
      "amdgpu.dcdebugmask=0x12"

      # ========================================================================
      # AMD CPU power management (Zen 5 architecture)
      # ========================================================================
      "amd_pstate=active" # Active P-state driver for better power/performance
      "processor.max_cstate=8" # Allow deeper C-states for better idle power

      # ========================================================================
      # Sleep/Suspend Configuration (AMD Ryzen AI 9 HX 370)
      # ========================================================================
      # CRITICAL: AMD dropped S3 sleep support on newer CPUs
      # Only s2idle (suspend-to-idle) works reliably on Ryzen AI 9 HX 370
      # Using 'deep' (S3) will cause sleep failures and potential hangs
      "mem_sleep_default=s2idle"

      # NVMe power state fix - critical for AMD sleep/wake reliability
      # Prevents NVMe drive from entering problematic power states during suspend
      "nvme_core.default_ps_max_latency_us=0"

      # RTC ACPI alarm fix - prevents premature wake from suspend
      # Framework/GPD community tested fix for suspend-then-hibernate
      "rtc_cmos.use_acpi_alarm=1"

      # ========================================================================
      # Display Configuration
      # ========================================================================
      # Screen rotation for portrait panels mounted as landscape
      # GPD Win Mini 2025: REQUIRED (portrait screen in landscape mount)
      # GPD Win Max 2 2025: NOT needed (true landscape screen)
      "fbcon=nodefer" # Earlier framebuffer initialization

      # ========================================================================
      # Boot Configuration
      # ========================================================================
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

    # Ensure required directories exist
    directories.paths = {
      "/snowscape/knowledge" = {
        owner = "simonwjackson";
        group = "users";
        mode = "0755";
        parents = true; # Also create /snowscape if needed
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

    # Hyprland window manager
    hyprland.enable = true;

    # Gaming - local Steam install only
    gaming.enable = true;

    # Syncthing for knowledge sync
    syncthing = {
      enable = true;
      deviceId = "JD7WTBJ-N4R623A-7EYMYTM-3PK4NS4-LGEE2GJ-PVE3XO3-3RLFXMX-R53EEQU";
      folders.knowledge.path = "/snowscape/knowledge";
    };
  };

  # ============================================================================
  # DISPLAY ROTATION - Portrait panel mounted as landscape (Hyprland)
  # ============================================================================
  # GPD Win Mini 2025 uses a portrait screen rotated 90 degrees
  # Hyprland monitor config: transform 1 = 90 degrees clockwise
  # Add to home.nix or hyprland.conf:
  #   monitor = eDP-1,1920x1080@120,0x0,1,transform,1
  # ============================================================================

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

    # Thunderbolt/USB4 support
    hardware.bolt.enable = true;

    # Disable SDDM (use greetd instead for TUI login)
    displayManager.sddm.enable = lib.mkForce false;

    # TUI login manager with auto-login to Hyprland
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = "greeter";
        };
        initial_session = {
          command = "Hyprland";
          user = "simonwjackson";
        };
      };
    };
  };

  # OBS Studio with virtual camera
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  # Mosh - mobile shell for unstable connections
  programs.mosh.enable = true;

  # ============================================================================
  # THERMAL/FAN & TDP CONFIGURATION - Quiet Operation with Dynamic Performance
  # ============================================================================
  # Goal: Keep fan quiet as long as possible while allowing dynamic TDP
  #
  # Strategy:
  # 1. Use power-profiles-daemon for system-wide power profiles
  # 2. Use ryzenadj for manual TDP adjustments when needed
  # 3. Use fancontrol with gpd-fan driver for custom fan curve
  # ============================================================================

  # IMPORTANT: power-profiles-daemon conflicts with auto-cpufreq
  # We use auto-cpufreq for maximum battery optimization
  services.power-profiles-daemon.enable = false;

  # Tools for TDP/fan control
  # - ryzenadj: manual TDP control (doesn't lock to constant TDP)
  #   Usage: ryzenadj --stapm-limit=15000 --fast-limit=20000 --slow-limit=18000
  # - lm_sensors: sensor detection and monitoring
  environment.systemPackages = with pkgs; [
    ryzenadj
    lm_sensors
  ];

  # ============================================================================
  # FAN CONTROL - GPD Fan Driver + Quiet Curve
  # ============================================================================
  # Uses external gpd-fan-driver module (kernel 6.18+ will have it natively)
  # https://github.com/Cryolitia/gpd-fan-driver
  hardware.gpd-fan.enable = true;

  # Dynamic fancontrol - finds hwmon devices by name at runtime
  # Survives hwmon number changes across reboots
  systemd.services.gpd-fancontrol = {
    description = "GPD Dynamic Fan Control";
    wantedBy = ["multi-user.target"];
    after = ["systemd-modules-load.service"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.gpd-fancontrol}/bin/gpd-fancontrol";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # ============================================================================
  # POWER MANAGEMENT - MAXIMUM BATTERY OPTIMIZATION
  # ============================================================================
  # Note: suspend-then-hibernate is handled by mountainous.hybrid-sleep
  # (enabled via laptop profile) - no need to configure logind manually

  # Auto-cpufreq: Automatic CPU frequency scaling for battery life
  # Much better than static governors - adapts dynamically
  services.auto-cpufreq = {
    enable = true;
    settings = {
      battery = {
        governor = "powersave";
        turbo = "never"; # Disable turbo on battery for max runtime
        energy_performance_preference = "power";
        scaling_min_freq = 400000; # Allow CPU to clock down to 400MHz
        scaling_max_freq = 2000000; # Cap at 2GHz on battery
      };
      charger = {
        governor = "schedutil"; # Dynamic scaling when plugged in
        turbo = "auto";
        energy_performance_preference = "balance_performance";
      };
    };
  };

  # Powertop auto-tune: Enable all power saving tunables
  powerManagement.powertop.enable = true;

  # Enable power management
  powerManagement.enable = true;

  # Audio power saving (Intel HDA codec)
  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=1
  '';

  # USB autosuspend and other power tweaks via udev
  services.udev.extraRules = ''
    # Set fan to quiet immediately when device appears (before fancontrol starts)
    ACTION=="add", SUBSYSTEM=="hwmon", ATTR{name}=="gpdfan", ATTR{pwm1}="0"

    # Enable USB autosuspend for all devices
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend_delay_ms}="1000"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="auto"

    # SATA link power management
    ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="med_power_with_dipm"

    # PCI power management
    ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"

    # AMD GPU power saving on battery
    ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card*", ATTR{device/power_dpm_force_performance_level}="low"

    # ========================================================================
    # SUSPEND FIX: Disable I2C device wakeup sources
    # ========================================================================
    # These touchpad/touchscreen devices can prevent proper suspend or cause
    # immediate wakeup, keeping the screen on during sleep.
    # Reference: https://github.com/Sabrina-Fox/WM2-Help
    # Reference: https://github.com/Cryolitia/nixos-config

    # Touchpad wakeup disable (PNP0C50 = HID-over-I2C touchpad)
    SUBSYSTEM=="i2c", KERNEL=="i2c-PNP0C50:00", ATTR{power/wakeup}="disabled"

    # Touchscreen wakeup disable (GXTP7385 = Goodix touchscreen, if present)
    SUBSYSTEM=="i2c", KERNEL=="i2c-GXTP7385:00", ATTR{power/wakeup}="disabled"

    # GPD Win Mini 2025 touchpad devices (from HARDWARE.md)
    # Verify with: ls /sys/bus/i2c/devices/
    SUBSYSTEM=="i2c", KERNEL=="i2c-HTIX5288:00", ATTR{power/wakeup}="disabled"
    SUBSYSTEM=="i2c", KERNEL=="i2c-NVTK0603:00", ATTR{power/wakeup}="disabled"

    # ========================================================================
    # SUSPEND FIX: Disable USB controller wakeup (prevents s2idle failures)
    # ========================================================================
    # XHC controllers can prevent reaching deepest sleep state
    # Error: "amd_pmc: Last suspend didn't reach deepest state"
    SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x15b6", ATTR{power/wakeup}="disabled"
  '';

  # Disable ACPI wakeup sources that interfere with s2idle
  # Run at boot to disable USB/PCIe wakeup triggers
  systemd.services.disable-wakeup-sources = {
    description = "Disable problematic ACPI wakeup sources for s2idle";
    wantedBy = ["multi-user.target"];
    after = ["systemd-modules-load.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Disable USB controller wakeup (XHC0-4)
      for dev in XHC0 XHC1 XHC3 XHC4; do
        if grep -q "$dev.*enabled" /proc/acpi/wakeup; then
          echo $dev > /proc/acpi/wakeup
        fi
      done
      # Disable PCIe bridge wakeup (GPP devices)
      for dev in GPP0 GPP1 GPP3 GPP4 GPP5; do
        if grep -q "$dev.*enabled" /proc/acpi/wakeup; then
          echo $dev > /proc/acpi/wakeup
        fi
      done
      # CRITICAL: Disable Thunderbolt/USB4 wakeup (NHI0, NHI1)
      # These prevent reaching S0i3 deepest sleep state
      for dev in NHI0 NHI1; do
        if grep -q "$dev.*enabled" /proc/acpi/wakeup; then
          echo $dev > /proc/acpi/wakeup
        fi
      done
    '';
  };

  # WiFi power saving (re-enable on battery - was disabled for gaming)
  # NOTE: This is now handled dynamically by auto-cpufreq / scripts
  # networking.networkmanager.wifi.powersave = true; # Conflicts with gaming profile

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
