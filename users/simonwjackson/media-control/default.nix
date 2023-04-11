{ config, lib, pkgs, ... }:

let
  cfg = config.programs.media-control;
in
{
  options.programs.media-control = {
    enable = lib.mkEnableOption "media control";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.home.sessionVariables
          ? MPV_SOCKET
          && config.home.sessionVariables.MPV_SOCKET != "";
        message = "MPV_SOCKET must be set in home.sessionVariables when enabling media-control.";
      }
    ];

    home.packages = with pkgs; [
      pulseaudio
      gnugrep
      mpc-cli
      socat
      xdotool
    ];

    services.sxhkd.extraConfig = lib.mkMerge [
      (builtins.readFile ./sxhkdrc)
    ];

    home.file.".local/bin/media-control" = {
      text = builtins.readFile ./media-control.sh;
      executable = true;
    };
  };
}
