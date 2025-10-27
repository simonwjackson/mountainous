{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./disko.nix
  ];

  # Use Linux 6.12 LTS for best 13th Gen Intel support
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # Boot configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Intel microcode updates (critical for security and stability)
  hardware.cpu.intel.updateMicrocode = true;

  # Kernel parameters for better power management and sleep
  boot.kernelParams = [
    # Try deep sleep if BIOS supports (fallback to s2idle)
    "mem_sleep_default=deep"

    # Intel graphics optimizations
    "i915.fastboot=1"
    "i915.enable_fbc=1"
    "i915.enable_psr=2"

    # Display resolution hint for native 3K OLED panel
    "video=eDP-1:2880x1800@60"
  ];

  # Initrd kernel modules (loaded in early boot for hardware access)
  boot.initrd.availableKernelModules = [
    "nvme" # NVMe SSD support (WD SN740)
    "xhci_pci" # USB 3.2 controllers
    "thunderbolt" # Thunderbolt 4 support
    "usb_storage" # USB storage devices
    "sd_mod" # SD card reader (if present)
  ];

  # Early KMS for i915 (smooth graphical boot)
  boot.initrd.kernelModules = ["i915"];

  # Common kernel modules (loaded after boot)
  boot.kernelModules = [
    "i915" # Intel Iris Xe Graphics
    "snd_sof_pci_intel_tgl" # Sound Open Firmware (Realtek ALC298)
    "iwlmvm" # Intel WiFi 6E AX211
    "btusb" # Bluetooth
    "hid_multitouch" # Touchpad (Imagis) & Touchscreen (Goodix)
    "intel_ishtp_hid" # Intel Sensor Hub (2-in-1 features)
  ];

  # Resume from hibernate
  boot.resumeDevice = "/dev/disk/by-label/swap";

  # Enable base profile
  mountainous = {
    profiles.base.enable = true;

    # Enable Hyprland (Wayland compositor)
    hyprland = {
      enable = true;
    };

    # Override base profile's impermanence - configure locally (like zao)
    impermanence.enable = lib.mkForce false;
  };

  # Disable auto-cpufreq from base profile (conflicts with TLP)
  # TLP is better for laptops with comprehensive device power management
  services.auto-cpufreq.enable = lib.mkForce false;

  # Networking
  networking.hostName = "asana";
  networking.networkmanager = {
    enable = true;
    wifi.powersave = true; # Enable WiFi power saving on battery
  };

  # Timezone
  time.timeZone = "UTC";

  # Graphics configuration for Intel Iris Xe (Raptor Lake-P integrated GPU)
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Support for 32-bit applications/games
    extraPackages = with pkgs; [
      intel-media-driver # VAAPI driver for hardware video decode (LIBVA_DRIVER_NAME=iHD)
      intel-compute-runtime # OpenCL support for compute workloads
      vpl-gpu-rt # Intel Video Processing Library (VPL) for newer hardware
    ];
  };

  # HiDPI font configuration for 3K display (2880x1800, ~226 PPI)
  fonts = {
    fontconfig = {
      enable = true;
      antialias = true;
      hinting = {
        enable = true;
        style = "slight"; # Light hinting for HiDPI displays
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };
    };
  };

  # Input device configuration for 2-in-1 convertible
  # Touchpad: Imagis IMG4100 (I2C HID)
  # Touchscreen: Goodix GXTP7936 (I2C HID, 10-point multi-touch)
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true; # Two-finger scroll direction (macOS-style)
      tapping = true; # Tap to click
      disableWhileTyping = true; # Prevent accidental touches while typing
      accelProfile = "adaptive"; # Adaptive acceleration curve
      scrollMethod = "twofinger"; # Two-finger scrolling
      clickMethod = "clickfinger"; # Click behavior based on finger count
      middleEmulation = false; # Disable middle button emulation
      tappingDragLock = false; # Disable drag lock
    };
  };

  # Wacom stylus support (Wacom EMR digitizer)
  # Model: WCOM016A:00 2D1F:0185 (I2C HID)
  # Features: Pressure sensitivity, tilt detection, hover detection, button support
  services.xserver.wacom.enable = true; # Works for both X11 and Wayland

  # Audio configuration
  # Hardware: Realtek ALC298 codec via Intel Alder Lake-P PCH HDA
  # Driver: SOF (Sound Open Firmware) - sof-hda-dsp
  sound.enable = true;

  # PipeWire: Modern audio server (replaces PulseAudio)
  # Provides low-latency audio, Bluetooth audio, and professional audio support
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true; # 32-bit application support
    };
    pulse.enable = true; # PulseAudio compatibility layer
    jack.enable = true; # JACK audio compatibility (optional, for pro audio)
  };

  # Disable PulseAudio (conflicts with PipeWire)
  hardware.pulseaudio.enable = false;

  # Bluetooth configuration
  # Hardware: Intel WiFi 6E AX211 (integrated Bluetooth)
  # Driver: btusb, btintel
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true; # Power on Bluetooth adapter on boot
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket"; # Enable all audio profiles
        Experimental = true; # Enable experimental features (better codec support)
      };
    };
  };

  # Blueman: Bluetooth manager GUI
  services.blueman.enable = true;

  # 2-in-1 convertible features
  # Sensor hub: Intel ISH with accelerometer, gyroscope, ALS, hinge sensor
  # Enables automatic screen rotation and mode detection
  hardware.sensor.iio.enable = true;

  # Thunderbolt 4 support
  # Hardware: Intel Thunderbolt 4 controller (Alder Lake-P)
  # Features: PCIe tunneling, DisplayPort, USB, 40 Gbps bandwidth
  services.hardware.bolt.enable = true;

  # ACPI daemon for power button and lid switch events
  services.acpid.enable = true;

  # Firmware updates via fwupd (BIOS, Thunderbolt, etc.)
  services.fwupd.enable = true;

  # User configuration
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video"];
  };

  # Configure ephemeral root filesystem (tmpfs) for impermanence
  # Root is wiped on every boot - only /tundra/permafrost persists
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  # Mark persistent storage as needed early in boot
  fileSystems."/tundra/permafrost".neededForBoot = true;

  # Local impermanence configuration for asana (following zao's pattern)
  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/nix" # Nix store must persist (large, contains all packages)
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/var/log"
      {
        directory = "/home/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0700";
      }
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

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };

    # SSH host keys in persistent storage
    # Keys will need to exist in /tundra/permafrost/etc/ssh/ before first boot
    hostKeys = [
      {
        path = "/tundra/permafrost/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  # Suspend-then-hibernate after 30 minutes
  # This provides MacBook-like experience:
  # - Fast wake for short breaks (suspend)
  # - Zero battery drain for long periods (hibernate after 30m)
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m
  '';

  # Lid close behavior
  services.logind = {
    lidSwitch = "suspend-then-hibernate";
    lidSwitchExternalPower = "suspend-then-hibernate";
    extraConfig = ''
      HandlePowerKey=suspend-then-hibernate
    '';
  };

  # TLP for comprehensive power management
  # Note: Do NOT enable auto-cpufreq alongside TLP - they conflict
  services.tlp = {
    enable = true;
    settings = {
      # CPU scaling governors
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # Battery care - charge between 40-80% for longevity
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;

      # Intel CPU energy/performance policies
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Intel GPU frequency management
      INTEL_GPU_MIN_FREQ_ON_AC = 300;
      INTEL_GPU_MIN_FREQ_ON_BAT = 300;
      INTEL_GPU_BOOST_FREQ_ON_AC = 1500;
      INTEL_GPU_BOOST_FREQ_ON_BAT = 1000;

      # Runtime power management for devices
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # USB autosuspend
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_PHONE = 1;

      # PCIe Active State Power Management
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # WiFi power saving
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";
    };
  };

  # Thermald: Intel Dynamic Platform and Thermal Framework daemon
  # Automatically manages CPU/GPU temperatures and prevents thermal throttling
  services.thermald.enable = true;

  # System packages: power monitoring, hardware tools, utilities
  environment.systemPackages = with pkgs; [
    # Basic tools
    neovim
    git

    # Power management
    powertop # Power consumption monitoring
    tlp # TLP CLI tools
    acpi # Battery and AC adapter info

    # Display & input
    brightnessctl # Modern backlight control (user in video group can use without sudo)
    libwacom # Wacom device support library
    xf86-input-wacom # Wacom driver (X11 and Wayland compatible)
    onboard # On-screen keyboard for tablet mode

    # Audio
    pavucontrol # PulseAudio/PipeWire volume control GUI
    alsa-utils # ALSA utilities (alsamixer, aplay, arecord, etc.)

    # Hardware monitoring
    lm_sensors # Temperature monitoring (sensors command)
    htop # Process monitor
    btop # Beautiful process monitor
    nvme-cli # NVMe health monitoring
    smartmontools # Drive health (smartctl)
    usbutils # lsusb
    pciutils # lspci
    dmidecode # Hardware info
    inxi # System information tool
  ];

  # Enable fstrim for SSD maintenance (weekly TRIM)
  services.fstrim.enable = true;

  # Enable flakes
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
  };

  system.stateVersion = "24.05";
}
