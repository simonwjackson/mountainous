{
  age,
  config,
  pkgs,
  ...
}: {
  age.secrets.tailscale_env.file = ../../../../secrets/tailscale_env.age;

  systemd.services.ensureQbitorrentRoot = {
    script = ''
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/radarr/config
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/ts-films/state
    '';
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  virtualisation.oci-containers.containers = {
    ts-films = {
      image = "tailscale/tailscale:latest";
      hostname = "films";
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--cap-add=SYS_MODULE"
        "--device=/dev/net/tun:/dev/net/tun"
        "--network=container:gluetun"
      ];
      volumes = let
        configPath = pkgs.writeTextFile {
          name = "ts-films";
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
                      "Proxy": "http://127.0.0.1:7878"
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
        "/glacier/snowscape/services/ts-films/state:/var/lib/tailscale"
        "${configPath}:/config"
      ];
      environmentFiles = [
        config.age.secrets."tailscale_env".path
      ];
      environment = {
        TS_STATE_DIR = "/var/lib/tailscale";
        TS_SERVE_CONFIG = "/config/tailscale.json";
      };
      # dependsOn = ["gluetun" "radarr"];
      # dependsOn = ["radarr"];
    };

    radarr = {
      image = "lscr.io/linuxserver/radarr:latest";
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Etc/UTC";
      };
      volumes = [
        "/glacier/snowscape/services/radarr/config:/config"
        "/glacier/snowscape/films:/movies"
        "/glacier/snowscape/downloads/sabnzbd/complete:/downloads"
      ];
      extraOptions = [
        "--network=container:gluetun"
      ];
    };
  };
}
