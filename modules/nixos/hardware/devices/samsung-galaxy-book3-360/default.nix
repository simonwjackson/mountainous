{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.mountainous.hardware.devices.samsung-galaxy-book3-360;
in {
  options.mountainous.hardware.devices.samsung-galaxy-book3-360 = {
    enable = mkEnableOption "Whether to enable bluetooth";
  };

  config = mkIf cfg.enable {
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
