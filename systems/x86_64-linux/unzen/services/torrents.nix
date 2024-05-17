{
  age,
  config,
  pkgs,
  ...
}: {
  # age.secrets.tailscale_env.file = ../../../../secrets/tailscale_env.age;

  systemd.services.ensureQbitorrentRoot = {
    script = ''
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/rtorrent/state
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/rtorrent/config
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/rtorrent/data
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/rtorrent/passwd

      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/flood/state
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/flood/config

      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/downloads/rtorrent

      install -d -o simonwjackson -g users -m 770 /glacier/snowscape/services/ts-torrents/state
    '';
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  virtualisation.oci-containers.containers = {
    # rtorrent = {
    #   image = "rtorrent:latest";
    #   imageFile = pkgs.dockerTools.buildImage {
    #     name = "rtorrent";
    #     tag = "latest";
    #     copyToRoot = [pkgs.rtorrent pkgs.curl pkgs.bash];
    #     config = {
    #       Cmd = ["${pkgs.rtorrent}/bin/rtorrent" "-o" "network.port_range.set=6881-6881,system.daemon.set=true,scgi_port=127.0.0.1:5050"];
    #     };
    #   };
    #
    #   extraOptions = [
    #     "--network=container:gluetun"
    #   ];
    #
    #   dependsOn = ["gluetun"];
    # };

    rtorrent = {
      image = "crazymax/rtorrent-rutorrent:latest";
      extraOptions = [
        "--network=container:gluetun"
        # "--ulimit nproc=65535"
        # "--ulimit nofile=32000:40000"
      ];
      environment = {
        XMLRPC_PORT = "8800";
        RUTORRENT_PORT = "8810";
      };
      volumes = [
        "/glacier/snowscape/downloads/rtorrent:/downloads"
        "/glacier/snowscape/services/rtorrent/data:/data"
        "/glacier/snowscape/services/rtorrent/passwd:/passwd"
      ];
      # dependsOn = ["gluetun"];
    };

    flood = {
      autoStart = true;
      cmd = ["--port=3000" "--allowedpath=/data"];
      image = "jesec/flood:master";
      user = "1000:1001";
      extraOptions = [
        "--network=container:gluetun"
      ];
      environment = {
        HOME = "/config";
      };
      volumes = [
        "/glacier/snowscape/services/flood/config:/config"
        "/glacier/snowscape/services/flood/state:/data"
      ];
      # dependsOn = ["rtorrent" "gluetun"];
      # dependsOn = ["rtorrent"];
    };

    ts-torrents = {
      image = "tailscale/tailscale:latest";
      hostname = "torrents";
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--cap-add=SYS_MODULE"
        "--device=/dev/net/tun:/dev/net/tun"
        "--network=container:gluetun"
      ];
      volumes = let
        configPath = pkgs.writeTextFile {
          name = "xavarr";
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
                      "Proxy": "http://127.0.0.1:8810"
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
        "/glacier/snowscape/services/ts-torrents/state:/var/lib/tailscale"
        "${configPath}:/config"
      ];
      environmentFiles = [
        config.age.secrets."tailscale_env".path
      ];

      environment = {
        TS_STATE_DIR = "/var/lib/tailscale";
        TS_SERVE_CONFIG = "/config/tailscale.json";
      };
      # dependsOn = ["gluetun" "flood"];
      # dependsOn = ["flood"];
    };
  };
}
