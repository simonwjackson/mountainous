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
    mountainous = {
      hardware = {
        bluetooth.enable = true;
        battery.enable = true;
        cpu.type = "amd";
      };
    };

    boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "sd_mod"];
    boot.kernelPackages = pkgs.linuxPackages_zen;

    # *might* fix white/flashing screens
    # kernelParams = ["amdgpu.sg_display=0"];
    # WARNING: promises better energy efficency but This *might* cause lower fps. kernel 6.3 or higher
    # kernelParams = [ "amd_pstate=active" ];
    boot.kernelParams = [
      "fbcon=rotate:1"
      "video=eDP-1:panel_orientation=right_side_up"
    ];

    # Required for grub to properly display the boot menu.
    boot.loader.grub.gfxmodeEfi = lib.mkDefault "1080x1920x32";

    # services.xserver.deviceSection = ''
    #   Option "TearFree" "true"
    # '';
  };
}
