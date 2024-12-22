{
  modulesPath,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled disabled;
in {
  imports = [
    (import ./disko.nix {
      device = "/dev/disk/by-id/usb-PNY_USB_3.2.2_FD_070836E05B03CC22-0:0";
    })
  ];

  # Add specific kernel build configuration
  # boot.kernelPackages = pkgs.linuxPackages_latest; # Default kernel for normal boot

  # Basic system configuration
  boot = {
    extraModulePackages = [pkgs.linuxPackages_6_6.kernel]; # For other entries
    supportedFilesystems = ["btrfs" "exfat"]; # Keep your existing filesystems
    kernelPackages = pkgs.linuxPackages_6_6; # Default kernel for normal boot
    kernelModules = [
      "cryptd"
      "aesni_intel"
      "dm_mod"
      "nvme"
    ];
    loader = {
      efi.canTouchEfiVariables = lib.mkForce false;
      efi.efiSysMountPoint = "/boot";
      systemd-boot = {
        enable = true;
        # Add custom boot menu entries
        # extraEntries = {
        #   "nixos-hidpi.conf" = ''
        #     title NixOS (HiDPI Intel)
        #     version 1
        #     linux /nixos/kernel
        #     initrd /nixos/initrd
        #     options init=/nix/store/*-nixos-system-*/init ${toString config.boot.kernelParams} video=efifb:2880x1800 video=efifb:scale fbcon=nodefer i915.fastboot=1 i915.force_probe=all i915.enable_fbc=1 i915.enable_psr=2
        #   '';
        # };
        # Optional: Configure the menu timeout (in seconds)
        consoleMode = "max";
        editor = false; # Disable editing kernel parameters for security
        configurationLimit = 10;
        memtest86.enable = true;
      };
    };
    initrd = {
      availableKernelModules = [
        "ahci"
        "btrfs"
        "cryptd"
        "crypto_aes"
        "ehci_pci"
        "sd_mod"
        "uas"
        "usb_storage"
        "usbhid"
        "xhci_pci"
      ];
    };
  };
  # Auto-detect other OS installations
  # Add the 6.6 kernel as an additional kernel

  # INFO: Needed to use this system as a nixos-anywhere insatller
  system.nixos.variant_id = lib.mkDefault "installer";

  services.openssh = {
    settings = lib.mkForce {
      # HACK: Needed for nixos-anywhere
      PermitRootLogin = "yes";
    };
  };

  mountainous = {
    boot = enabled;
    gaming = {
      core = enabled;
      steam = enabled;
    };
    impermanence = {
      enable = true;
      persistPath = "/tundra/permafrost";
    };
    profiles = {
      laptop = enabled;
      workstation = enabled;
    };
    # TODO: encrypt generated syncthing keys
    syncthing = {
      # key = config.age.secrets.cho-syncthing-key.path;
      # cert = config.age.secrets.cho-syncthing-cert.path;
    };
  };

  # Basic system packages
  environment.systemPackages = with pkgs; [
    btrfs-progs
    exfat
    linuxPackages_6_6.kernel
  ];

  services.fstrim.enable = true; # Enable periodic TRIM

  # # Reduce writes to disk
  # services.journald.extraConfig = ''
  #   Storage=volatile
  #   RuntimeMaxUse=64M
  # '';
  #
  # # Better I/O scheduling for flash storage
  # services.udev.extraRules = ''
  #   # Set scheduler for USB storage
  #   ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
  # '';

  system.stateVersion = "24.11";
}
