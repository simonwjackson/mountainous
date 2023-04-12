{ config, lib, pkgs, ... }:

let
  cfg = config.programs.mpvd;

in
{
  options.programs.mpvd = {
    enable = lib.mkEnableOption "fuzzy-music";
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.mpvd = {
      Unit = {
        Description = "MPV background service";
      };
      Service = {
        ExecStart = "${pkgs.mpv}/bin/mpv --audio-display=no --idle --input-ipc-server=%t/mpv.socket";
        Restart = "always";
        PrivateTmp = true;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
