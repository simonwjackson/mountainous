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
    # Disable PulseAudio (using PipeWire instead)
    hardware.pulseaudio.enable = false;

    # Enable PipeWire with gaming optimizations
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true; # Critical for 32-bit games
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;

      # Low-latency gaming configuration
      wireplumber.configPackages = [
        (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/10-gaming.conf" ''
          monitor.alsa.rules = [
            {
              matches = [ { node.name = "~alsa_output.*" } ]
              actions = {
                update-props = {
                  api.alsa.period-size = 256
                  api.alsa.headroom = 1024
                }
              }
            }
          ]
        '')
      ];
    };

    # Enable rtkit for real-time audio priority
    security.rtkit.enable = true;

    # Audio packages
    environment.systemPackages = with pkgs; [
      pavucontrol   # GUI volume control
      alsa-utils    # CLI audio tools (alsamixer, aplay, etc.)
      pulseaudio    # For pactl compatibility
    ];
  };
}
