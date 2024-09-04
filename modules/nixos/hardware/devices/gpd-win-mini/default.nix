{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.mountainous.hardware.devices.gpd-win-mini;
in {
  options.mountainous.hardware.devices.gpd-win-mini = {
    enable = mkEnableOption "Whether to enable GPD Win Mini adjustments";
  };

  config = mkIf cfg.enable {
    backpacker = {
      hardware = {
        bluetooth.enable = true;
        battery.enable = true;
        cpu.type = "amd";
      };
    };

    boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "uas" "sd_mod"];
    boot.kernelPackages = pkgs.linuxPackages_zen;

    # hardware.gpd-fan.enable = true;

    # *might* fix white/flashing screens
    # kernelParams = ["amdgpu.sg_display=0"];
    # WARN: promises better energy efficency but This *might* cause lower fps. kernel 6.3 or higher
    # kernelParams = [ "amd_pstate=active" ];
    boot.kernelParams = [
      "fbcon=rotate:1"
      "video=eDP-1:panel_orientation=right_side_up"
      "amd_pstate=active"
    ];

    # Required for grub to properly display the boot menu.
    boot.loader.grub.gfxmodeEfi = lib.mkDefault "1080x1920x32";

    # INFO: Jovian NixOS steam module
    # https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/steam/steam.nix

    hardware = {
      i2c.enable = true;
      sensor.iio.enable = true;
      graphics = {
        enable32Bit = true;
        extraPackages = with pkgs; [
          rocm-opencl-icd
          vaapiVdpau
          rocm-opencl-runtime
          libvdpau-va-gl
        ];
      };
      enableAllFirmware = true;
      cpu.amd = {
        updateMicrocode = true;
        ryzen-smu.enable = true;
      };
    };

    programs = {
      xwayland.enable = true;
      # gamescope = {
      #   enable = true;
      #   # args = ["--rt" "-H 1080" "-h 720" "-f" "-F fsr"];
      # };
    };
  };
}
