{ config, lib, pkgs, ... }:

{
  options = {
    timezone-auto.enable = lib.mkEnableOption "Automatic time zone updates based on location";
  };

  config = lib.mkIf config.timezone-auto.enable {
    services.timesyncd.enable = true;
    services.timesyncd.servers = [ "0.pool.ntp.org" "1.pool.ntp.org" "2.pool.ntp.org" "3.pool.ntp.org" ];

    environment.systemPackages = with pkgs; [
      geoclue2
      tzupdate
    ];

    services.geoclue2.enable = true;

    systemd.services.update-timezone = {
      description = "Update Time Zone Based on Location";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'lat=$(geoclue2 -f \"{{.Latitude}}\") && lon=$(geoclue2 -f \"{{.Longitude}}\") && tzupdate -a \"$lat,$lon\" -p && systemctl restart systemd-timedated.service'";
      };
      path = with pkgs; [ geoclue2 tzupdate ];
    };
  };
}
