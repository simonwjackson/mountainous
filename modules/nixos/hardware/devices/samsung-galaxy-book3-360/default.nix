{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkDefault;

  cfg = config.mountainous.hardware.devices.samsung-galaxy-book3-360;
in {
  options.mountainous.hardware.devices.samsung-galaxy-book3-360 = {
    enable = mkEnableOption "Enable Samsung Galaxy Book3 360 support";
  };

  config = mkIf cfg.enable {
    boot = {
      kernelPackages = pkgs.linuxPackages_6_6;
      kernelParams = [
        "video=efifb:2880x1800" # Match your native resolution
        "video=efifb:scale" # HiDPI scaling
        "fbcon=nodefer"
        "i915.fastboot=1"
        "i915.force_probe=all" # Force early i915 initialization
        "i915.enable_fbc=1"
        "i915.enable_psr=2"
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
    };

    hardware.opengl = {
      enable = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # This is crucial for Iris Xe
        intel-compute-runtime # OpenCL support
        vaapiIntel
        vaapiVdpau
        libvdpau-va-gl
      ];
    };

    mountainous = {
      hardware = {
        bluetooth.enable = true;
        cpu.type = "intel";
      };
    };

    systemd.services.fixSamsungGalaxyBook3Speakers = {
      path = [pkgs.alsa-tools];
      script = builtins.readFile ./fix-audio.sh;
      wantedBy = ["multi-user.target" "post-resume.target"];
      after = ["multi-user.target" "post-resume.target"];
      serviceConfig = {
        Type = "oneshot";
      };
    };
  };
}
