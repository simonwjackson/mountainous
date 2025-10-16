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

  # Boot configuration for 11th Gen Intel Core i9-11900H (Tiger Lake)
  # Redundant USB boot with GRUB
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "uas" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];

    # Enable software RAID for redundant USB boot and backup
    swraid = {
      enable = true;
      mdadmConf = ''
        MAILADDR nobody@nowhere
      '';
    };

    loader = {
      efi = {
        canTouchEfiVariables = false; # USB boot compatibility
        efiSysMountPoint = "/boot";
      };
      grub = {
        enable = true;
        # INITIAL DEPLOY: Single USB device (no RAID)
        devices = [
          "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0374119080022027-0:0"
        ];
        # AFTER FIRST BOOT: Add second USB to enable RAID1 boot redundancy
        # devices = [
        #   "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0374119080022027-0:0"
        #   "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0322119070015232-0:0"
        # ];
        efiSupport = true;
        efiInstallAsRemovable = true; # USB boot reliability
        copyKernels = true; # Kernel redundancy
        fsIdentifier = "uuid"; # UUID-based mounting
      };
    };
  };

  # Hardware configuration
  # Hybrid graphics: Intel integrated (i915) + NVIDIA RTX 3060 Mobile
  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    bluetooth.enable = true;

    # NVIDIA proprietary drivers with Prime offload
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = lib.mkDefault true;
      powerManagement.finegrained = false;
      open = false; # Use proprietary driver, not open source kernel modules
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      # Prime configuration for hybrid graphics
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # Bus IDs detected from system
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };

    # Graphics configuration for hybrid GPU setup
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but sometimes works better)
        vaapiVdpau
        libvdpau-va-gl
      ];
      extraPackages32 = with pkgs; [
        intel-media-driver
        vaapiIntel
      ];
    };
  };

  # Load NVIDIA driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  # Networking
  networking.hostName = "zao";
  networking.useDHCP = lib.mkDefault true;

  # Enable profiles for desktop/gaming server
  mountainous = {
    profiles = {
      base.enable = true;
      workspace.enable = true;
      gaming.enable = true;
    };

    # Override base profile's impermanence - configure locally
    impermanence.enable = lib.mkForce false;
  };

  # Local impermanence configuration for zao
  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/etc/ssh"
      "/var/lib/systemd/coredump"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/home/simonwjackson"
    ];
    files = [
      "/etc/machine-id"
      "/etc/adjtime"
    ];
  };

  # Server-specific optimizations for always-plugged-in laptop
  # Disable battery-saving features since this runs as a server
  services.auto-cpufreq.enable = lib.mkForce false;

  # Prevent sleep/suspend - keep server running 24/7
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore"; # Don't suspend when lid closes
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "ignore";
    IdleAction = "ignore";
  };

  # CPU governor for consistent performance (not battery optimization)
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  system.stateVersion = "25.05";
}
