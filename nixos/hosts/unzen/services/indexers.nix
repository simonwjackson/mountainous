{
  age,
  config,
  pkgs,
  ...
}: {
  age.secrets.tailscale_env.file = ../../../../secrets/tailscale_env.age;

  systemd.services.ensureIndexerRoots = {
    script = ''
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/prowlarr/config
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/ts-indexers
    '';
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  virtualisation.oci-containers.containers = {
    prowlarr = {
      image = "lscr.io/linuxserver/prowlarr:latest";
      volumes = [
        "/glacier/snowscape/services/prowlarr:/config"
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

    ts-indexers = {
      image = "tailscale/tailscale:latest";
      hostname = "indexers";
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--cap-add=SYS_MODULE"
        "--device=/dev/net/tun:/dev/net/tun"
        "--network=container:gluetun"
      ];
      volumes = let
        configPath = pkgs.writeTextFile {
          name = "ts-usenet-proxy";
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
                      "Proxy": "http://127.0.0.1:9696"
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
        "/glacier/snowscape/services/ts-indexers:/var/lib/tailscale"
        "${configPath}:/config"
      ];
      environmentFiles = [
        config.age.secrets."tailscale_env".path
      ];
      environment = {
        TS_STATE_DIR = "/var/lib/tailscale";
        TS_SERVE_CONFIG = "/config/tailscale.json";
      };
      dependsOn = ["sonarr"];
    };
  };
}
