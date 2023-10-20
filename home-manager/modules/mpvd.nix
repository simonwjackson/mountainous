{ config, lib, pkgs, ... }:

let
  cfg = config.services.mpvd;
  mpv = "${pkgs.mpv}/bin/mpv";
in
{
  options.services.mpvd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable the MPV background service.
        
        Once the service is running, you can interact with it by sending commands to the socket specified by `socketLocation`.
        For example, you can use `echo '{ "command": ["play"] }' | socat - $MPVD_SOCKET_PATH` to start playback.
      '';
    };
    socketLocation = lib.mkOption {
      type = lib.types.str;
      default = "%t/mpv.socket";
      description = "The location of the mpv socket.";
    };
    additionalArgs = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Additional arguments to pass to mpv.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.sessionVariables.MPVD_SOCKET_PATH = cfg.socketLocation;

    systemd.user.services.mpvd = {
      Unit = {
        Description = "MPV background service";
      };
      Service = {
        ExecStart = "${mpv} --audio-display=no --idle --input-ipc-server=${cfg.socketLocation} ${cfg.additionalArgs}";
        Restart = "always";
        PrivateTmp = true;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
