{
  age,
  config,
  pkgs,
  ...
}: {
  age.secrets.tailscale_env.file = ../../../../secrets/tailscale_env.age;

  systemd.services.ensureQbitorrentRoot = {
    script = ''
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/sabnzbd/config
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/downloads/sabnzbd/complete
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/downloads/sabnzbd/incomplete
    '';
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  virtualisation.oci-containers.containers = {
    ts-usenet = {
      image = "tailscale/tailscale:latest";
      hostname = "usenet";
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--cap-add=SYS_MODULE"
        "--device=/dev/net/tun:/dev/net/tun"
        "--network=container:gluetun"
      ];
      volumes = let
        configPath = pkgs.writeTextFile {
          name = "ts-usenet";
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
                      "Proxy": "http://127.0.0.1:8080"
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
        "/glacier/snowscape/services/ts-usenet/state:/var/lib/tailscale"
        "${configPath}:/config"
      ];
      environmentFiles = [
        config.age.secrets."tailscale_env".path
      ];
      environment = {
        TS_STATE_DIR = "/var/lib/tailscale";
        TS_SERVE_CONFIG = "/config/tailscale.json";
      };
      dependsOn = ["gluetun" "sabnzbd"];
    };

    sabnzbd = {
      image = "lscr.io/linuxserver/sabnzbd:latest";
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Etc/UTC";
      };
      # user = "1000:1000";
      volumes = [
        "/glacier/snowscape/services/sabnzbd/config:/config"
        "/glacier/snowscape/downloads/sabnzbd/complete:/downloads"
        "/glacier/snowscape/downloads/sabnzbd/incomplete:/incomplete-downloads"
      ];
      extraOptions = [
        "--network=container:gluetun"
      ];

      dependsOn = ["gluetun"];
    };
  };
}
