{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled;

  codeDir = "/snowscape/code";
in {
  imports = [
    ./x1-fold.nix  # X1 Fold hardware-specific configuration
  ];

  boot = {
    # Generic kernel modules for system functionality
    kernelModules = [
      "nvme"
      "thunderbolt"
      "tun"
      "igc"
      "nvme_core"
    ];

    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
      };
    };

    # Performance and graphics optimizations (not hardware-specific)
    kernelParams = [
      "fbcon=nodefer"
      "i915.fastboot=1"
      "i915.enable_fbc=1"
      "i915.enable_psr=2"
      # Hibernation resume parameters
      "resume=UUID=92b1c48f-0905-41cb-92ee-8b164252b01f"
      "resume_offset=533760"
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

    # Resume device for hibernation
    resumeDevice = "/dev/disk/by-uuid/92b1c48f-0905-41cb-92ee-8b164252b01f";
  };

  # System packages
  environment.systemPackages = with pkgs; [
    git
    ex
    obsidian
    xdg-desktop-portal-gtk
    yazi
    powertop # For power analysis
  ];

  # Power management optimizations (compatible with auto-cpufreq)
  powerManagement = {
    enable = true;
    powertop.enable = true; # Auto-tune (non-CPU settings only)
  };

  # Intel thermal daemon for better thermal management
  services.thermald.enable = true;

  # Systemd service to disable unnecessary wake sources
  systemd.services.optimize-wake-sources = {
    description = "Disable unnecessary wake sources for better s2idle";
    wantedBy = [ "multi-user.target" ];
    script = ''
      # Disable wake sources that interrupt s2idle
      # Keep only: XHCI (USB), LID, SLPB (power button)
      for source in PEG0 TXHC TDM0 TRP0 TRP1; do
        if [ -f /proc/acpi/wakeup ] && grep -q "^$source" /proc/acpi/wakeup; then
          echo "$source" > /proc/acpi/wakeup 2>/dev/null || true
        fi
      done
    '';
  };

  # Sysctl settings for better power management
  boot.kernel.sysctl = {
    "vm.laptop_mode" = 5; # Better disk power management
  };

  # System services
  security.rtkit.enable = true;

  # Mountainous configuration
  mountainous = {
    agenix.enable = true;
    sound.enable = true;

    # Syncthing disabled as requested
    syncthing = {
      enable = false;
      key = "/run/agenix/fuji-syncthing-key";
      cert = "/run/agenix/fuji-syncthing-cert";
      systemsDir = ../../../../nix/systems;
    };

    # System profiles
    profiles = {
      base.enable = true;
      laptop.enable = true;
      workspace.enable = true;
      gaming.enable = true;
    };

    # Disk configuration
    disks = {
      frostbite = {
        enable = true;
        device = "/dev/nvme0n1";
        swapSize = "16G";
        encrypt = false;
      };
    };
  };

  # Bind mount for development workspace
  fileSystems."/snowscape" = {
    device = "/tundra/frostbite/snowscape";
    fsType = "none";
    options = ["bind"];
    neededForBoot = false;
  };

  system.stateVersion = "24.11";
}