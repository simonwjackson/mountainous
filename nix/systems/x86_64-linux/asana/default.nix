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
    "nvme"          # NVMe SSD support (WD SN740)
    "xhci_pci"      # USB 3.2 controllers
    "thunderbolt"   # Thunderbolt 4 support
    "usb_storage"   # USB storage devices
    "sd_mod"        # SD card reader (if present)
  ];

  # Early KMS for i915 (smooth graphical boot)
  boot.initrd.kernelModules = ["i915"];

  # Common kernel modules (loaded after boot)
  boot.kernelModules = [
    "i915"                    # Intel Iris Xe Graphics
    "snd_sof_pci_intel_tgl"   # Sound Open Firmware (Realtek ALC298)
    "iwlmvm"                  # Intel WiFi 6E AX211
    "btusb"                   # Bluetooth
    "hid_multitouch"          # Touchpad (Imagis) & Touchscreen (Goodix)
    "intel_ishtp_hid"         # Intel Sensor Hub (2-in-1 features)
  ];

  # Resume from hibernate
  boot.resumeDevice = "/dev/disk/by-label/swap";

  # Enable base profile
  mountainous = {
    profiles.base.enable = true;

    # Override base profile's impermanence - configure locally (like zao)
    impermanence.enable = lib.mkForce false;
  };

  # Networking
  networking.hostName = "asana";
  networking.networkmanager.enable = true;

  # Timezone
  time.timeZone = "UTC";

  # Graphics configuration for Intel Iris Xe (Raptor Lake-P integrated GPU)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # Support for 32-bit applications/games
    extraPackages = with pkgs; [
      intel-media-driver    # VAAPI driver for hardware video decode (LIBVA_DRIVER_NAME=iHD)
      intel-compute-runtime # OpenCL support for compute workloads
      vpl-gpu-rt           # Intel Video Processing Library (VPL) for newer hardware
    ];
  };

  # HiDPI font configuration for 3K display (2880x1800, ~226 PPI)
  fonts = {
    fontconfig = {
      enable = true;
      antialias = true;
      hinting = {
        enable = true;
        style = "slight";  # Light hinting for HiDPI displays
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };
    };
  };

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

  # Packages for power monitoring and basic tools
  environment.systemPackages = with pkgs; [
    neovim
    git
    powertop      # Power consumption monitoring
    tlp           # TLP CLI tools
    brightnessctl # Modern backlight control (user in video group can use without sudo)
  ];

  # Enable fstrim for SSD maintenance (weekly TRIM)
  services.fstrim.enable = true;

  # Enable flakes
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
  };

  system.stateVersion = "24.05";
}
