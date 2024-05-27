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
    enable = mkEnableOption "Whether to enable bluetooth";
  };

  config = mkIf cfg.enable {
    backpacker = {
      hardware = {
        bluetooth.enable = true;
        cpu.type = "intel";
      };
    };

    boot.kernelPackages = mkDefault pkgs.linuxPackages_latest;

    boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod"];

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
