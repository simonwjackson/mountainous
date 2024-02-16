{
  age,
  config,
  pkgs,
  ...
}: {
  systemd.services.ensureYoutubeRoot = {
    script = ''
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/ytdl-sub
    '';
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  virtualisation.oci-containers.containers = {
    ytdl-sub = {
      image = "ghcr.io/jmbannon/ytdl-sub:latest";
      ports = [
        "8443:8443"
      ];
      volumes = [
        "/glacier/snowscape/services/ytdl-sub:/config"
        "/glacier/snowscape/series:/tv_shows" # optional
        "/glacier/snowscape/films:/movies" # optional
        "/glacier/snowscape/music:/music" # optional
      ];
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "America/Chicago";
        DOCKER_MODS = "linuxserver/mods:universal-cron";
      };
    };
  };
}
