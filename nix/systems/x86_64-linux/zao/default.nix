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
  # RAID1 USB boot with GRUB for redundancy
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "uas" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];

    # Enable software RAID for:
    # - RAID1 USB boot (dual Lexar drives)
    # - RAID1 USB backup (dual Lexar drives)
    # - RAID0 system (dual WD Blue SN570 NVMe drives)
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
        # RAID1 boot: Install to both USB drives for redundancy
        devices = [
          "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0374119080022027-0:0"
          "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0330119070016269-0:0"
        ];
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

  # Configure ephemeral root filesystem (tmpfs) for impermanence
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  # Mark persistent storage as needed early in boot
  fileSystems."/tundra/permafrost".neededForBoot = true;

  # Local impermanence configuration for zao
  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/nix" # Nix store must persist (large, contains all packages)
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/var/log"
      "/root"
      {
        directory = "/home/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0700";
      }
      {
        directory = "/tundra/igloo";
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
    "/tundra/permafrost/tundra/igloo".d = {
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

  # SSH host keys in persistent storage
  # Keys are deployed via deploy.sh using --extra-files during initial installation
  services.openssh.hostKeys = [
    {
      path = "/tundra/permafrost/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

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
