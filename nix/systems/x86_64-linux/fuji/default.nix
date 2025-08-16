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

    extraModprobeConfig = ''
      options snd-hda-intel dmic_detect=0
    '';

    kernelModules = [
      "nvme"
      "thunderbolt"
      "tun"
      "igc"
      "nvme_core" # Added for more complete NVMe support
      "hid_sensor_hub" # Added for orientation sensing on foldable device
      "snd_hda_intel"
      "snd_soc_avs"
      "snd_sof_pci_intel_tgl"
    ];
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
      };
    };
    kernelPackages = pkgs.linuxPackages_6_6;
    kernelParams = [
      "video=efifb:2024x2560" # Match your native resolution
      "video=efifb:scale" # HiDPI scaling
      "fbcon=nodefer"
      "i915.fastboot=1"
      "i915.force_probe=all" # Force early i915 initialization
      "i915.enable_fbc=1"
      "i915.enable_psr=2"
      "acpi_osi=!\"Windows 2020\"" # Added for better Lenovo compatibility
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

  # enable syncthing
  services.syncthing = {
    enable = true;
    user = "simonwjackson";
    group = "users";
    dataDir = "/home/simonwjackson/.local/share/syncthing";
    configDir = "/home/simonwjackson/.config/syncthing";
    overrideFolders = false;
    overrideDevices = false;
  };

  # Disable default folder
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

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
  };

  services.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
  };

  services.pipewire = {
    enable = lib.mkForce false;
  };

  security.rtkit.enable = true;

  mountainous = {
    sound.enable = lib.mkForce false;
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
