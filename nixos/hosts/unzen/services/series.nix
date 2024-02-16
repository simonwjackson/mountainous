{
  age,
  config,
  pkgs,
  ...
}: {
  age.secrets.tailscale_env.file = ../../../../secrets/tailscale_env.age;

  systemd.services.ensureQbitorrentRoot = {
    script = ''
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/downloads/sonarr
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/sonarr/config
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/ts-series/state
    '';
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  virtualisation.oci-containers.containers = {
    sonarr = {
      image = "lscr.io/linuxserver/sonarr:latest";
      # user = "1000:1000";
      volumes = [
        "/glacier/snowscape/services/sonarr/config:/config"
        "/glacier/snowscape/downloads/sabnzbd/complete:/downloads"
        "/glacier/snowscape/series:/tv"
      ];

      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Etc/UTC";
      };

      extraOptions = [
        "--network=container:gluetun"
      ];

      dependsOn = ["gluetun"];
    };

    ts-series = {
      image = "tailscale/tailscale:latest";
      hostname = "series";
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--cap-add=SYS_MODULE"
        "--device=/dev/net/tun:/dev/net/tun"
        "--network=container:gluetun"
      ];
      volumes = let
        configPath = pkgs.writeTextFile {
          name = "ts-series";
          destination = "/tailscale.json";
          text = ''
            {
              "TCP": {
                "443": {
                  "HTTPS": true
                }
              },
              "Web": {
                "''${TS_CERT_DOMAIN}:443": {
                  "Handlers": {
                    "/": {
                      "Proxy": "http://127.0.0.1:8989"
                    }
                  }
                }
              },
              "AllowFunnel": {
                "''${TS_CERT_DOMAIN}:443": false
              }
            }
          '';
        };
      in [
        "/glacier/snowscape/services/ts-series/state:/var/lib/tailscale"
        "${configPath}:/config"
      ];
      environmentFiles = [
        config.age.secrets."tailscale_env".path
      ];
      environment = {
        TS_STATE_DIR = "/var/lib/tailscale";
        TS_SERVE_CONFIG = "/config/tailscale.json";
      };
      dependsOn = ["gluetun" "sonarr"];
    };
  };
}
