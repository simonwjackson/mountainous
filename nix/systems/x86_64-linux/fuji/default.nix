{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled;

  codeDir = "/snowscape/code";
in {
  boot = {
    # kernelPatches = [
    #   { name = "fix-1";
    #     patch =  builtins.fetchurl {
    #       url = "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/patch/sound/soc/soc-topology.c?id=e0e7bc2cbee93778c4ad7d9a792d425ffb5af6f7";
    #       sha256 = "sha256:1y5nv1vgk73aa9hkjjd94wyd4akf07jv2znhw8jw29rj25dbab0q";
    #     };
    #   }
    #   { name = "fix-2";
    #     patch = builtins.fetchurl {
    #       url = "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/patch/sound/soc/soc-topology.c?id=0298f51652be47b79780833e0b63194e1231fa34";
    #       sha256 = "sha256:14xb6nmsyxap899mg9ck65zlbkvhyi8xkq7h8bfrv4052vi414yb";
    #     };
    #   }
    # ];



    kernelModules = [
      "nvme"
      "thunderbolt"
      "tun"
      "igc"
      "nvme_core" # Added for more complete NVMe support
      "hid_sensor_hub" # Added for orientation sensing on foldable device
    ];
    # Add extraModprobeConfig for X1 Fold audio quirks
    extraModprobeConfig = ''
      options snd-hda-intel model=thinkpad-x1fold
    '';

    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
      };
    };
    kernelPackages = pkgs.linuxPackages_latest;  # Upgrade to 6.16 for best X1 Fold support
    kernelParams = [
      "video=efifb:2024x2560" # Match your native resolution
      "video=efifb:scale" # HiDPI scaling
      "fbcon=nodefer"
      "i915.fastboot=1"
      "i915.force_probe=all" # Force early i915 initialization
      "i915.enable_fbc=1"
      "i915.enable_psr=2"
      "acpi_osi=!\"Windows 2020\"" # Added for better Lenovo compatibility
      "snd-hda-intel.model=thinkpad-x1fold" # X1 Fold specific audio quirk
    ];
    initrd = {
      kernelModules = ["i915"];
      availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "usb_storage"
        "sd_mod"
      ];
    };
  };

  # Basic packages
  environment.systemPackages = with pkgs; [
    git
    ex
    ryzenadj
    obsidian
    xdg-desktop-portal-gtk
    yazi
  ];

  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  # Enable Thunderbolt support
  services.hardware.bolt.enable = true;

  # Enable mountainous Syncthing module with auto-discovery
  mountainous.syncthing = {
    enable = false;
    key = "/run/agenix/fuji-syncthing-key";
    cert = "/run/agenix/fuji-syncthing-cert";
    systemsDir = ../../../../nix/systems;
    # Configuration automatically discovered from ./syncthing.nix
  };

  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
  '';

  hardware = {
    # i2c is for sensors and other hardware that is connected to the motherboard
    i2c.enable = true;

    sensor.iio.enable = true;

    # Enable Bluetooth support
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;

    # Add SOF firmware for Intel audio
    firmware = [ pkgs.sof-firmware ];
  };

  security.rtkit.enable = true;

  mountainous = {
    agenix.enable = true;
    sound.enable = true;
    auto-rotate = {
      enable = true;
      accelerometerDevice = "/sys/bus/iio/devices/iio:device0";
      hingeDevice = "/sys/bus/iio/devices/iio:device4";
      enableHingeDetection = true; # Re-enabled with proper initialization
      hingeThreshold = 90; # Lower threshold for easier testing
      rotationThreshold = 100000; # Lowered for better sensitivity
      debounceTime = 2;
      pollInterval = 0.5;
    };
    profiles = {
      base.enable = true;
      laptop.enable = true;
      workspace.enable = true;
      gaming.enable = true;
    };
    disks = {
      frostbite = {
        enable = true;
        device = "/dev/nvme0n1";
        swapSize = "16G";
        encrypt = false;
      };
    };
    # impermanence = {
    #   enable = true;
    # };
    # networking.core.names = [
    #   {
    #     name = "wifi";
    #     mac = "d4:d8:53:90:2b:6c";
    #   }
    # ];
  };

  fileSystems."/snowscape" = {
    device = "/tundra/frostbite/snowscape";
    fsType = "none";
    options = ["bind"];
    neededForBoot = false;
  };

  system.stateVersion = "24.11";
}
