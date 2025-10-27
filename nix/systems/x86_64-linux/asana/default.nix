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

  # Kernel parameters for better power management and sleep
  boot.kernelParams = [
    # Try deep sleep if BIOS supports (fallback to s2idle)
    "mem_sleep_default=deep"

    # Intel graphics optimizations
    "i915.fastboot=1"
    "i915.enable_fbc=1"
    "i915.enable_psr=2"
  ];

  # Resume from hibernate
  boot.resumeDevice = "/dev/disk/by-label/swap";

  # Enable base profile
  mountainous = {
    profiles.base.enable = true;
  };

  # Networking
  networking.hostName = "asana";
  networking.networkmanager.enable = true;

  # Timezone
  time.timeZone = "UTC";

  # User configuration
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video"];
  };

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
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
    powertop # For monitoring power consumption
    tlp # TLP CLI tools
  ];

  # Enable flakes
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
  };

  system.stateVersion = "24.05";
}
