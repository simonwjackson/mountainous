{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.mountainous.hardware.devices.gpd-win-mini;
in {
  options.mountainous.hardware.devices.gpd-win-mini = {
    enable = mkEnableOption "Enable GPD Win Mini (2025) hardware";
  };

  config = mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    # mountainous = {
    #   hardware = {
    #     bluetooth.enable = true;
    #     battery.enable = true;
    #     cpu.type = "amd";
    #   };
    # };
    
    nix.settings.trusted-users = [ "root" "simonwjackson" ];

    boot = {
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
      kernelModules = ["kvm-amd" "tun"];
      kernelPackages = pkgs.linuxPackages_zen;
      kernelParams = [
        # "fbcon=rotate:1"
        # "video=eDP-1:panel_orientation=right_side_up"
        "amd_pstate=active"

        # Set resolution at EFI level
        # "video=efifb:1080x1920" # Match your native resolution
        "video=efifb:scale" # HiDPI scaling

        # AMD-specific parameters
        "amdgpu.dc=1" # Enable Display Core
        "amdgpu.runpm=0" # Disable runtime power management for stability
        "amdgpu.fastboot=1" # Enable fast boot
      ];
    };

    hardware = {
      i2c.enable = true;
      sensor.iio.enable = true;
      enableAllFirmware = true;
      cpu.amd = {
        updateMicrocode = true;
        ryzen-smu.enable = true;
      };
    };
  };
}
