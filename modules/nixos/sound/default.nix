{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.mountainous.networking.zerotierone;
in {
  options.mountainous.networking.zerotierone = {
    enable = mkEnableOption "Toggle zerotierone daemon";
  };

  config = mkIf cfg.enable {
    sound.enable = true;
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
