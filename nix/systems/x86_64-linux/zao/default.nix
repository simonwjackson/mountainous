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
  # Dual USB boot with GRUB for redundancy, btrfs RAID for storage
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "uas" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];

    loader = {
      efi.canTouchEfiVariables = false;
      systemd-boot = {
        enable = true;
        # Install as removable for SD card boot reliability
        # This places the bootloader at /EFI/BOOT/BOOTX64.EFI
      };
      # Use removable installation for SD card portability
      efi.efiSysMountPoint = "/boot";
      grub.enable = false;
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
        intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but sometimes works better)
        libva-vdpau-driver
        libvdpau-va-gl
      ];
      extraPackages32 = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
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
  # Note: /nix and /var/log are separate btrfs subvolumes (not bind mounts)
  # This avoids tmpfs issues during installation
  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
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
