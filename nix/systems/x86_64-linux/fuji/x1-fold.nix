{pkgs, ...}: {
  # ThinkPad X1 Fold Gen 1 hardware-specific configuration
  # This module contains all hardware quirks and optimizations for the X1 Fold

  boot = {
    # Audio quirks for X1 Fold - enables internal speakers via SoundWire
    extraModprobeConfig = ''
      options snd-hda-intel model=thinkpad-x1fold
      options snd_hda_intel power_save=30
    '';

    # Latest kernel provides best X1 Fold support (6.8+ recommended)
    kernelPackages = pkgs.linuxPackages_latest;

    # X1 Fold specific kernel modules
    kernelModules = [
      "hid_sensor_hub" # For fold/orientation sensors and hinge detection
      "nvme"
      "thunderbolt"
      "tun"
      "igc" # Intel Ethernet Controller
      "nvme_core"
      "intel_vsc" # Intel Vision Sensing Controller for IPU6 camera
    ];

    # X1 Fold specific kernel parameters
    kernelParams = [
      "video=efifb:2024x2560" # Native resolution of foldable OLED panel
      "video=efifb:scale" # HiDPI scaling for high-resolution display
      "acpi_osi=!\"Windows 2020\"" # Better Lenovo compatibility and power management
      "mem_sleep_default=s2idle" # Use s2idle instead of deep suspend (deep causes reboot on X1 Fold)
      # Power management optimizations for s2idle
      "i915.enable_guc=3" # Better GPU power management
      "intel_idle.max_cstate=9" # Deeper C-states for CPU
      "processor.max_cstate=9" # CPU deeper sleep states
      "nvme.noacpi=1" # Better NVMe power management
      # Intel graphics optimizations
      "fbcon=nodefer"
      "i915.fastboot=1"
      "i915.enable_fbc=1"
      "i915.enable_psr=2"
      # Hibernation resume parameters
      "resume=UUID=92b1c48f-0905-41cb-92ee-8b164252b01f"
      "resume_offset=533760"
    ];

    # Intel graphics module for initrd
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

    # Sysctl settings for better power management on laptops
    kernel.sysctl = {
      "vm.laptop_mode" = 5; # Better disk power management
    };
  };

  # Hardware support specific to X1 Fold
  hardware = {
    # I2C support for sensors and hardware communication
    i2c.enable = true;

    # IIO sensors for accelerometer and orientation detection
    sensor.iio.enable = true;

    # Bluetooth support for X1 Fold's Bluetooth 5.3 module
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    # Intel IPU6 camera support for ThinkPad X1 Fold Gen 2
    ipu6 = {
      enable = true;
      platform = "ipu6ep";
    };

    # SOF firmware for Intel Smart Sound Technology audio
    firmware = [pkgs.sof-firmware];
  };

  # Thunderbolt support for dock and external device connectivity
  services.hardware.bolt.enable = true;

  # Intel thermal daemon for better thermal management
  services.thermald.enable = true;

  # Power management optimizations (compatible with auto-cpufreq)
  powerManagement = {
    enable = true;
    powertop.enable = true; # Auto-tune (non-CPU settings only)
  };

  # Auto-rotate configuration optimized for X1 Fold's foldable display
  # NOTE: auto-rotate module has been removed
  # mountainous.auto-rotate = {
  #   enable = true;
  #   accelerometerDevice = "/sys/bus/iio/devices/iio:device0"; # Primary accelerometer
  #   rotationThreshold = 100000; # Sensitivity for orientation changes
  #   debounceTime = 2; # Prevent rapid orientation switching
  #   pollInterval = 0.5; # Check sensors twice per second
  # };

  # OBS Studio with virtual camera for video conferencing on foldable display
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  # udev rules for sensor access
  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
  '';

  # Systemd service to disable unnecessary wake sources
  systemd.services.optimize-wake-sources = {
    description = "Disable unnecessary wake sources for better s2idle";
    wantedBy = ["multi-user.target"];
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

  # Hardware-specific packages
  environment.systemPackages = with pkgs; [
    powertop # For power analysis and optimization
    libcamera # Camera support library
  ];

  # # Create laptop mode toggle script for X1 Fold
  # environment.systemPackages = with pkgs; [
  #   (writeShellScriptBin "x1fold-laptop-mode-toggle" ''
  #     #!${pkgs.bash}/bin/bash
  #     export PATH="${lib.makeBinPath [pkgs.hyprland pkgs.systemd]}:$PATH"
  #
  #     # State file to track current mode
  #     STATE_FILE="/tmp/x1fold-laptop-mode"
  #
  #     # Check current mode
  #     if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "laptop" ]; then
  #       # Switch to tablet mode
  #       echo "Switching to tablet mode..."
  #
  #       # Remove reserved space (full screen available)
  #       hyprctl keyword monitor "eDP-1,addreserved,0,0,0,0"
  #
  #       # Reset master layout orientation to default
  #       hyprctl dispatch layoutmsg orientationtop
  #
  #       # Re-enable auto-rotation
  #       systemctl --user start mountainous-auto-rotate.service 2>/dev/null || true
  #
  #       # Update state
  #       echo "tablet" > "$STATE_FILE"
  #       echo "✅ Tablet mode active - full screen, auto-rotation enabled"
  #
  #     else
  #       # Switch to laptop mode
  #       echo "Switching to laptop mode..."
  #
  #       # Get current scale and calculate correct reserved pixels
  #       CURRENT_SCALE=$(hyprctl monitors -j | jq -r '.[0].scale')
  #       # Reserve bottom half of display (506 logical pixels at scale 2.0, scaled inversely)
  #       RESERVED_PIXELS=$(echo "$CURRENT_SCALE" | awk '{printf "%.0f", 506 * 2.0 / $1}')
  #
  #       echo "Detected scale: $CURRENT_SCALE, reserving $RESERVED_PIXELS logical pixels"
  #       hyprctl keyword monitor "eDP-1,addreserved,0,$RESERVED_PIXELS,0,0"
  #
  #       # Set master layout orientation to right for laptop mode
  #       hyprctl dispatch layoutmsg orientationright
  #
  #       # Disable auto-rotation
  #       systemctl --user stop mountainous-auto-rotate.service 2>/dev/null || true
  #
  #       # Update state
  #       echo "laptop" > "$STATE_FILE"
  #       echo "💻 Laptop mode active - reserved bottom space, right orientation, rotation disabled"
  #     fi
  #   '')
  # ];
  #
  # # Home-manager configuration for X1 Fold specific keybindings
  # home-manager.users.simonwjackson = {
  #   mountainous.hyprland.extraSettings = {
  #     bind = [
  #       # X1 Fold laptop mode toggle
  #       "$mainMod, T, exec, x1fold-laptop-mode-toggle"
  #     ];
  #   };
  # };
}
