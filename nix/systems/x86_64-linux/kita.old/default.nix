{pkgs, ...}: {
  ###################
  # Mountainous
  ###################

  mountainous = {
    profiles = {
      base.enable = true;
      laptop.enable = true;
      workspace.enable = true;
      gaming.enable = true;
    };

    # networking.core.names = [
    #   # TODO: Move to caldigit module
    #   {
    #     name = "eth";
    #     mac = "64:4b:f0:6a:6c:7e";
    #   }
    #   {
    #     name = "wifi";
    #     mac = "86:4f:69:77:9c:62";
    #   }
    # ];
    disks = {
      frostbite = {
        enable = true;
        encrypt = true;
        device = "/dev/nvme0n1";
        swapSize = "32G";
      };
    };
  };

  ###################
  # Misc
  ###################

  fileSystems."/tundra/sleet" = {
    device = "/dev/disk/by-id/usb-Generic_MassStorageClass_000000002958-0:0-part1";
    fsType = "f2fs";
    options = ["noatime" "nofail" "x-systemd.automount" "x-systemd.device-timeout=5"];
  };

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
    cpu.amd = {
      updateMicrocode = true;
      ryzen-smu.enable = true;
    };

    # Enable Bluetooth support
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "thunderbolt"
        "usbhid"
        "usb_storage"
        "uas"
        "sd_mod"
      ];
      kernelModules = ["amdgpu"];
    };
    kernelModules = ["kvm-amd" "tun" "igc" "thunderbolt"];
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [
      # Enable AMD power management
      "amd_pstate=active"

      # HiDPI scaling
      "video=efifb:scale"

      # Display Core: allows the GPU to control the display
      # "amdgpu.dc=1"

      # Runtime power management. disabled.
      # "amdgpu.runpm=0"

      # Fast boot will speed up boot time by skipping some initialization
      "amdgpu.fastboot=1"
    ];
  };

  # Basic packages
  environment.systemPackages = with pkgs; [
    git
    ex
    ryzenadj
    obsidian
  ];

  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  # Enable Thunderbolt support
  services.hardware.bolt.enable = true;

  fileSystems."/snowscape" = {
    device = "/tundra/frostbite/snowscape";
    fsType = "none";
    options = ["bind"];
    neededForBoot = false;
  };

  # This is required for NixOS
  system.stateVersion = "24.11";
}
