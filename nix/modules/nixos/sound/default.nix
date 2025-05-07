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
    # Disable PulseAudio
    services.pulseaudio.enable = false;

    # Enable PipeWire
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    # Bluetooth audio
    services.pulseaudio.package = pkgs.pulseaudioFull;
  };
}
