{ config, pkgs, lib, ... }:

{
  # ThinkPad X1 Fold Gen 1 hardware-specific configuration
  # This module contains all hardware quirks and optimizations for the X1 Fold
  
  boot = {
    # Audio quirks for X1 Fold - enables internal speakers via SoundWire
    extraModprobeConfig = ''
      options snd-hda-intel model=thinkpad-x1fold
    '';
    
    # Latest kernel provides best X1 Fold support (6.8+ recommended)
    kernelPackages = pkgs.linuxPackages_latest;
    
    # X1 Fold specific kernel modules
    kernelModules = [
      "hid_sensor_hub"  # For fold/orientation sensors and hinge detection
    ];
    
    # X1 Fold specific kernel parameters
    kernelParams = [
      "video=efifb:2024x2560"      # Native resolution of foldable OLED panel
      "video=efifb:scale"          # HiDPI scaling for high-resolution display
      "acpi_osi=!\"Windows 2020\"" # Better Lenovo compatibility and power management
    ];
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
    
    # SOF firmware for Intel Smart Sound Technology audio
    firmware = [ pkgs.sof-firmware ];
  };
  
  # Thunderbolt support for dock and external device connectivity
  services.hardware.bolt.enable = true;
  
  # Auto-rotate configuration optimized for X1 Fold's foldable display
  mountainous.auto-rotate = {
    enable = true;
    accelerometerDevice = "/sys/bus/iio/devices/iio:device0";  # Primary accelerometer
    hingeDevice = "/sys/bus/iio/devices/iio:device4";          # Hinge position sensor
    enableHingeDetection = false;
    hingeThreshold = 90;         # Degrees for laptop/tablet mode detection
    rotationThreshold = 100000;  # Sensitivity for orientation changes
    debounceTime = 2;           # Prevent rapid orientation switching
    pollInterval = 0.5;         # Check sensors twice per second
  };
  
  # OBS Studio with virtual camera for video conferencing on foldable display
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };
  
  # udev rules for sensor access
  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
  '';
}