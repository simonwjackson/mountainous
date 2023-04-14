{ pkgs, lib, config, ... }:

with lib;
let
  cfg = config.services.slskd;
  audioDownloads = /tank/downloads/soulseek/downloads;
in
{
  options.services.slskd = {
    enable = mkEnableOption "slskd server";
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers = {
      slskd = {
        autoStart = true;
        image = "slskd/slskd";
        user = "1000:1000";
        ports = [
          "0.0.0.0:5030:5030"
          "0.0.0.0:5031:5031"
          "0.0.0.0:50300:50300"
        ];
        environment = {
          SLSKD_REMOTE_CONFIGURATION = "true";
        };
        volumes = [
          "/tank/downloads/soulseek:/app"
        ];
      };
    };

    systemd.services.slskd-beets-import = {
      description = "When a slskd download completes, run `beet import`";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = "simonwjackson";
        Group = "users";
        Restart = "on-failure";
        ExecStart = "${pkgs.writeScript "slskd-beets-import.sh" ''
          #!/bin/sh

          EVENTS="create,moved_to"

          ${pkgs.inotify-tools}/bin/inotifywait -m -r -e $EVENTS "${toString audioDownloads}" | while read -r watched_path event file; do
            echo "[$(date)] Event: $event, File: $watched_path$file"
            ${pkgs.beets}/bin/beet import -m -q ${toString audioDownloads} && ${pkgs.beets}/bin/beet duplicates --delete
          done
        ''}";
      };
    };
  };
}
