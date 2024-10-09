{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.mountainous.sound;
in {
  options.mountainous.sound = {
    enable = mkEnableOption "Whether to enable the zerotierone daemon";
  };

  config = mkIf cfg.enable {
    hardware.pulseaudio.enable = false;

    # Bluetooth audio
    hardware.pulseaudio.package = pkgs.pulseaudioFull;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
      # lowLatency.enable = true;
    };
  };
}
