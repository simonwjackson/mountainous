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

    boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "uas" "sd_mod"];
    boot.kernelPackages = pkgs.linuxPackages_zen;

    # *might* fix white/flashing screens
    # kernelParams = ["amdgpu.sg_display=0"];
    # WARN: promises better energy efficency but This *might* cause lower fps. kernel 6.3 or higher
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

    # TODO: Add extra wayland support
    # systemd.user = {
    #   sessionVariables = {
    #     CLUTTER_BACKEND = "wayland";
    #     GDK_BACKEND = "wayland,x11";
    #     QT_QPA_PLATFORM = "wayland;xcb";
    #     MOZ_ENABLE_WAYLAND = "1";
    #     _JAVA_AWT_WM_NONREPARENTING = "1";
    #     STEAM_EXTRA_COMPAT_TOOL_PATHS = "/home/eddie/.local/share/Steam/compatibilitytools.d/SteamTinkerLaunch/";
    #   };
    # };

    # INFO: Jovian NixOS steam module
    # https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/steam/steam.nix

    hardware = {
      sensor.iio.enable = true;
      # WARN: opengl or steam-hardware might be causing issues with fsr
      opengl = {
        driSupport = true;
        driSupport32Bit = true;
        extraPackages = with pkgs; [
          rocm-opencl-icd
          vaapiVdpau
          rocm-opencl-runtime
          libvdpau-va-gl
        ];
      };
      enableAllFirmware = true;
      steam-hardware.enable = true;
    };
  };
}
