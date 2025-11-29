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

  # Boot configuration for Intel NUC8i3BEK (Coffee Lake i3-8109U)
  # RAID1 USB boot with GRUB for redundancy
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "thunderbolt" "ahci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];

    # Enable software RAID for:
    # - RAID1 USB boot (dual USB drives for redundancy)
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
          "/dev/disk/by-id/usb-SanDisk_Ultra_Fit_4C530000230426119230-0:0"
          "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0322119070015232-0:0"
        ];
        efiSupport = true;
        efiInstallAsRemovable = true; # USB boot reliability
        copyKernels = true; # Kernel redundancy
        fsIdentifier = "uuid"; # UUID-based mounting
      };
    };
  };

  # Hardware configuration
  # Intel Iris Plus Graphics 655 (integrated only)
  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    bluetooth.enable = true;

    # Graphics configuration for Intel Iris Plus 655
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but sometimes works better)
        libvdpau-va-gl
      ];
      extraPackages32 = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
      ];
    };
  };

  # Networking
  networking.hostName = "kita";
  networking.useDHCP = lib.mkDefault true;

  # Enable profiles for desktop system
  mountainous = {
    profiles = {
      base.enable = true;
      workspace.enable = true;
      gaming.enable = true;
    };

    # Override base profile's impermanence - configure locally
    impermanence.enable = lib.mkForce false;
  };

  # Use mkForce to override defaults from mountainous.agenix module
  age.identityPaths = lib.mkForce [
    "/tundra/permafrost/etc/ssh/ssh_host_rsa_key"
  ];

  # Configure ephemeral root filesystem (tmpfs) for impermanence
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  # Persistent storage on main SSD
  # Override disko-generated config to use stable device path
  fileSystems."/tundra/permafrost" = lib.mkForce {
    device = "/dev/disk/by-id/ata-KINGSTON_SUV500M8240G_50026B7683B6CE9D-part1";
    fsType = "xfs";
    neededForBoot = true;
  };

  # Local impermanence configuration for kita
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

  # NUC power management
  # Always-on desktop system optimized for consistent performance
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  system.stateVersion = "25.05";
}
