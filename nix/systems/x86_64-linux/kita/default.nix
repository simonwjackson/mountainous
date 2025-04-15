{
  config,
  pkgs,
  ...
}: {
  ###################
  # Mountainous
  ###################

  mountainous = {
    profiles = {
      base.enable = true;
      laptop.enable = true;
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
    hyprland = {
      enable = true;
      autoLogin = true;
    };
    gaming = {
      core.enable = true;
      emulation = {
        enable = true;
        gen-7 = true;
        gen-8 = true;
      };
      steam.enable = true;
    };
  };

  ###################
  # Misc
  ###################

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

  # Network configuration
  networking = {
    hostName = "kita"; # Define your hostname
  };

  # Basic packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    ex
    ryzenadj
  ];

  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  # Enable Thunderbolt support
  services.hardware.bolt.enable = true;

  # This is required for NixOS
  system.stateVersion = "24.11";
}
