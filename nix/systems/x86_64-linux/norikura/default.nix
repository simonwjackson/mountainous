# GPD Pocket 1 - "norikura"
#
# Hardware:
#   CPU: Intel Atom x7-Z8750 @ 1.60GHz (4 cores)
#   GPU: Intel HD Graphics (Cherry Trail, device 0x22b0)
#   RAM: 8GB LPDDR3
#   Storage: 116.5GB eMMC (DJNB4R)
#   Display: 7" IPS 1920x1200 (portrait-native, requires 90° rotation)
#   Touchscreen: Goodix Capacitive (I2C)
#   WiFi: Broadcom BCM4356 (brcmfmac driver)
#   Audio: Realtek RT5645
#   Battery: 7000mAh (max170xx fuel gauge)
#
# Known Issues:
#   - Display is portrait-native, requires fbcon=rotate:1 and Hyprland transform
#   - Touchscreen needs calibration matrix for rotated display
#   - No deep sleep (S3) - only s2idle available
#   - Goodix touchscreen may need module reload after suspend
#   - Broadcom WiFi may need firmware file for full channel support
#
# References:
#   - https://wiki.nixos.org/wiki/Hardware/GPD/GPD_Pocket
#   - https://wiki.archlinux.org/title/GPD_Pocket
#
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

  boot = {
    # Kernel 6.6 LTS - most stable for suspend/hibernate on Atom
    # Alternative: linuxPackages_latest for newer features
    kernelPackages = pkgs.linuxPackages_6_6;

    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "nvme"
        "uas"
        "usbhid"
        "sd_mod"
        "sdhci_acpi"
        "sdhci_pci"
        "mmc_block"
        "rtsx_pci_sdmmc"
      ];
      kernelModules = [
        "i915" # Early KMS for Intel graphics
        "pwm-lpss" # Brightness control
        "pwm-lpss-platform"
      ];
    };

    kernelModules = [
      "kvm-intel"
      "i915"
      "btusb"
      "hid_multitouch"
      "goodix" # Touchscreen
      "bq24190_charger" # Battery charger
      "fusb302" # USB-C controller
    ];

    extraModulePackages = [];

    kernelParams = [
      # Resume device for hibernation
      "resume=/dev/disk/by-partlabel/disk-main-swap"

      # Display rotation (portrait to landscape)
      "fbcon=rotate:1"

      # GPD Pocket fan control (disable on AC for quiet operation)
      "gpd-pocket-fan.speed_on_ac=0"

      # Intel graphics optimizations
      "i915.fastboot=1"
      "i915.enable_fbc=1" # Frame buffer compression
      "i915.enable_psr=1" # Panel self-refresh

      # Power management - s2idle is the only available sleep state
      "mem_sleep_default=s2idle"

      # Quiet boot
      "loglevel=4"
      "quiet"
      "splash"
    ];

    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        editor = false;
      };
    };

    resumeDevice = "/dev/disk/by-partlabel/disk-main-swap";
  };

  # Hardware configuration for Intel Atom x7-Z8750 (Cherry Trail)
  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;

    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };

    # Intel HD Graphics (Cherry Trail)
    graphics = {
      enable = true;
      enable32Bit = false; # Atom doesn't benefit from 32-bit libs
      extraPackages = with pkgs; [
        intel-vaapi-driver # VAAPI for Cherry Trail (i965 driver)
        libvdpau-va-gl
      ];
    };
  };

  # VA-API driver selection for Cherry Trail
  # i965 is required (not iHD which is for newer Intel)
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "i965";
    VDPAU_DRIVER = "va_gl";
  };

  # Networking
  networking.hostName = "norikura";
  networking.useDHCP = lib.mkDefault true;
  networking.networkmanager.enable = true;

  # Broadcom WiFi firmware
  hardware.firmware = [
    (pkgs.runCommand "gpd-pocket-wifi-firmware" {} ''
            mkdir -p $out/lib/firmware/brcm
            # BCM4356 firmware configuration for GPD Pocket
            cat > $out/lib/firmware/brcm/brcmfmac4356-pcie.txt << 'EOF'
      # GPD Pocket BCM4356 WiFi configuration
      # Enables full channel range (not just 1-11)
      ccode=XV
      regrev=0
      EOF
    '')
  ];

  # Greeter
  services.greetd = {
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

  # Enable profiles
  mountainous = {
    profiles = {
      base.enable = true;
      laptop.enable = true;
      workspace.enable = true;
    };

    sound.enable = true;

    # Disable impermanence for initial setup
    impermanence.enable = lib.mkForce false;

    # Use persistent SSH key for agenix
    agenix.identityPaths = ["/tundra/permafrost/etc/ssh/ssh_host_rsa_key"];
  };

  # Use persistent SSH key for agenix (set directly to override defaults)
  age.identityPaths = lib.mkForce ["/tundra/permafrost/etc/ssh/ssh_host_rsa_key"];

  # Touchscreen calibration for rotated display
  # Goodix touchscreen needs transformation matrix when display is rotated
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="event[0-9]*", ATTRS{name}=="Goodix Capacitive TouchScreen", ENV{LIBINPUT_CALIBRATION_MATRIX}="0 1 0 -1 0 1"
  '';

  # Goodix touchscreen fix for suspend/resume
  # The touchscreen can act erratically after waking from sleep
  powerManagement.resumeCommands = ''
    ${pkgs.kmod}/bin/modprobe -r goodix
    ${pkgs.kmod}/bin/modprobe goodix
  '';

  # RT5645 audio configuration
  # The Cherry Trail audio requires specific UCM configuration
  services.pulseaudio.enable = false; # Use PipeWire instead

  # Ephemeral root filesystem
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  fileSystems."/tundra/permafrost".neededForBoot = true;

  # Impermanence configuration
  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/var/lib/bluetooth"
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

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };

    hostKeys = [
      {
        path = "/tundra/permafrost/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  # GPD Pocket specific services
  services = {
    # Power management - TLP for laptops
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

        # Atom benefits from conservative scaling
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;

        # WiFi power saving on battery
        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "on";

        # eMMC optimization
        DISK_DEVICES = "mmcblk0";
        DISK_IOSCHED = "mq-deadline";
      };
    };

    acpid.enable = true;
    fwupd.enable = true;
    blueman.enable = true;

    # Touchscreen/touchpad input
    libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;
        tapping = true;
        accelProfile = "adaptive";
      };
    };
  };

  # Disable auto-cpufreq from base profile (conflicts with TLP)
  services.auto-cpufreq.enable = lib.mkForce false;

  # XDG portal paths for home-manager integration
  environment.pathsToLink = ["/share/applications" "/share/xdg-desktop-portal"];

  # Useful packages for GPD Pocket
  environment.systemPackages = with pkgs; [
    brightnessctl
  ];

  # Suspend-then-hibernate for battery life
  # Note: Only s2idle is available, no deep sleep
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m
    SuspendState=freeze
  '';

  # Lid and power button behavior
  services.logind.settings.Login = {
    HandleLidSwitch = lib.mkForce "suspend-then-hibernate";
    HandleLidSwitchExternalPower = lib.mkForce "suspend";
    HandlePowerKey = lib.mkForce "hibernate";
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # User configuration
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video" "input"];
    openssh.authorizedKeys.keyFiles = [
      ../../../modules/nixos/user/id_rsa.pub
    ];
  };

  system.stateVersion = "25.05";
}
