{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.mountainous.profiles.workspace;
in {
  options.mountainous.profiles.workspace = {
    enable = mkEnableOption "Whether to enable the workspace profile";
  };

  config = mkIf cfg.enable {
    mountainous = {
      performance.enable = true;
      hyprland = {
        enable = true;
        autoLogin = true;
      };
    };

    # Disable PulseAudio
    hardware.pulseaudio.enable = false;

    # Enable PipeWire
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };
  };
}
