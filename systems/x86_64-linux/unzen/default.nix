{
  config,
  inputs,
  lib,
  modulesPath,
  pkgs,
  system,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./snowscape
    ./disko.nix
    ./iceberg.1.nix
  ];

  services.cuttlefish = {
    enable = false;
    # configFile = "/snowscape/podcasts/subscriptions.yaml";
  };

  networking = {
    nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      externalInterface = "eno1";
    };

    firewall = {
      enable = true;
    };
  };

  mountainous = {
    services = {
      soulseek = {
        enable = true;
        address = {
          host = "192.168.100.1"; # Your host address
          client = "192.168.100.50"; # Your client address
        };
      };
      usenet = {
        enable = true;
        address = {
          host = "192.168.100.1";
          client = "192.168.100.11";
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /snowscape 0775 media media -"
    "d /snowscape/audiobooks 0775 media media -"
    "d /snowscape/music 0775 media media -"
    "d /snowscape/podcasts 0775 media media -"
    "d /snowscape/videos 0775 media media -"
    "d /snowscape/books 0775 media media -"
    "d /snowscape/comics 0775 media media -"

    # Borg
    "d /avalanche/groups/local/snowscape/backup/gaming-profiles 0750 root root -"
    "d /avalanche/groups/local/snowscape/backup/notes 0750 root root -"
    "d /avalanche/groups/local/snowscape/backup/media-services 0750 root root -"
  ];

  containers = let
    protonAddress = "10.2.0.2/32";
    protonDns = "10.2.0.1";
    protonPort = 51820;

    tailscaleEphemeralAuthFile = config.age.secrets."tailscale-ephemeral".path;
    tailscaleMagicDns = "hummingbird-lake.ts.net";

    hostAddress = "192.168.100.1";
  in {
    downloads = let
      privateKeyFile = config.age.secrets."proton-0-downloads".path;
      aria2RpcSecretFile = config.age.secrets."aria2-rpc-secret".path;
    in {
      inherit hostAddress;

      localAddress = "192.168.100.88";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}".hostPath = tailscaleEphemeralAuthFile;
        "${privateKeyFile}".hostPath = privateKeyFile;
        "${aria2RpcSecretFile}".hostPath = aria2RpcSecretFile;
      };

      config = {pkgs, ...}: {
        system.stateVersion = "24.11";

        imports = [
          ./aria2-custom.nix
          # ./ariaNg.nix
          inputs.self.nixosModules.wg-killswitch
          inputs.self.nixosModules."networking/tailscaled"
        ];

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          # mylar3 = {
          #   enable = true;
          # };
          wg-killswitch = {
            inherit privateKeyFile;

            enable = true;
            name = "protonvpn";
            address = protonAddress;
            dns = protonDns;
            gateway = hostAddress;
            publicKey = "vsquyHHSbv76cOqCMZCREGur05Mp5XM0lbCAzrGDs2w=";
            server = "149.22.94.86";
          };
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 8000;
            };
          };
        };

        boot.kernel.sysctl = {
          "net.core.rmem_max" = 4194304;
          "net.core.wmem_max" = 1048576;
        };

        # services.ariang = {
        #   enable = true;
        #   user = "media";
        #   group = "media";
        # };

        services.aria2-custom = {
          enable = true;
          user = "media";
          group = "media";
          rpcSecretFile = aria2RpcSecretFile;
          settings = {};
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            group = "media";
            uid = lib.mkForce 333;
          };
        };
      };
    };

    torrents = let
      privateKeyFile = config.age.secrets."proton-0-torrents".path;
    in {
      inherit hostAddress;

      localAddress = "192.168.100.77";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}".hostPath = tailscaleEphemeralAuthFile;
        "${privateKeyFile}".hostPath = privateKeyFile;
      };

      config = {pkgs, ...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules.wg-killswitch
          inputs.self.nixosModules."networking/tailscaled"
        ];

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          wg-killswitch = {
            inherit privateKeyFile;

            enable = true;
            name = "protonvpn";
            address = protonAddress;
            dns = protonDns;
            gateway = hostAddress;
            publicKey = "KkUoHrIzkuQ4msZulqCFyRC1Gqcx8oMgbDFRn8wW1X8=";
            server = "95.173.221.65";
          };
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 3000;
            };
          };
        };

        services.flood.enable = true;
        systemd.services.flood = {
          serviceConfig = {
            UMask = "0002";
            DynamicUser = lib.mkForce false;
            User = "media";
            Group = "media";
            StateDirectoryMode = "770";
          };
        };

        boot.kernel.sysctl = {
          "net.core.rmem_max" = 4194304;
          "net.core.wmem_max" = 1048576;
        };

        systemd.services.transmission.serviceConfig = {
          UMask = lib.mkForce "0002";
          # INFO: Needed to start without failure
          RootDirectory = lib.mkForce "";
          RootDirectoryStartOnly = lib.mkForce false;
          StateDirectoryMode = "770";
        };

        services.transmission = {
          enable = true;
          user = "media";
          group = "media";
          settings = {
            # Basic settings
            umask = 2;
            # Upload restrictions
            "speed-limit-up" = 1; # KB/s
            "speed-limit-up-enabled" = true;
            "upload-slots-per-torrent" = 1;
            # Ratio limits
            "ratio-limit" = 0;
            "ratio-limit-enabled" = true;
            "seedRatioLimit" = 0.0;
            "seedRatioLimited" = true;
            # Peer settings
            "peer-limit-per-torrent" = 10;
            # Queue settings
            "seed-queue-enabled" = false;
          };
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            group = "media";
            uid = lib.mkForce 333;
          };
        };
      };
    };

    index = let
      proton0IndexPrivateKeyFile = config.age.secrets."proton-0-index".path;
    in {
      inherit hostAddress;

      localAddress = "192.168.100.17";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
        "${proton0IndexPrivateKeyFile}" = {
          hostPath = proton0IndexPrivateKeyFile;
          isReadOnly = true;
        };
      };

      config = {pkgs, ...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules.wg-killswitch
          inputs.self.nixosModules."networking/tailscaled"
        ];

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          wg-killswitch = {
            enable = true;
            name = "protonvpn";
            address = protonAddress;
            dns = protonDns;
            gateway = hostAddress;
            privateKeyFile = proton0IndexPrivateKeyFile;
            publicKey = "ntBhUr1CJmbVydw6cgccMFGSzEcPugiikF/l4NuDygA=";
            server = "79.127.136.65";
            port = protonPort;
          };
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 9696;
            };
          };
        };

        systemd.services.prowlarr = {
          serviceConfig = {
            UMask = "0002";
          };
        };

        services.prowlarr.enable = true;
        # services.flaresolverr.enable = true;
      };
    };

    ########
    # Apps
    ########

    search = let
      searxEnvFile = config.age.secrets."searx-env".path;
    in {
      inherit hostAddress;

      localAddress = "192.168.100.13";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${searxEnvFile}" = {
          hostPath = searxEnvFile;
          isReadOnly = true;
        };
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];
        nixpkgs.config.allowUnfree = true;

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 8888;
            };
          };
        };

        services.searx = {
          enable = true;
          redisCreateLocally = true;
          environmentFile = config.age.secrets."searx-env".path;
          settings.server = {
            bind_address = "0.0.0.0";
            port = 8888;
            secret_key = "@SEARX_SECRET_KEY@";
          };
        };
      };
    };

    series = {
      inherit hostAddress;

      localAddress = "192.168.100.15";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
        "/snowscape/videos/series" = {
          hostPath = "/snowscape/videos/series";
          isReadOnly = false;
        };
        "/var/lib/sabnzbd/Downloads/complete" = {
          hostPath = "/var/lib/nixos-containers/usenet/var/lib/sabnzbd/Downloads/complete";
          isReadOnly = false;
        };
        "/var/lib/transmission/Downloads" = {
          hostPath = "/var/lib/nixos-containers/torrents/var/lib/transmission/Downloads";
          isReadOnly = false;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];

        nixpkgs.config.allowUnfree = true;

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 8989;
            };
          };
        };

        nixpkgs.config.permittedInsecurePackages = [
          "aspnetcore-runtime-6.0.36"
          "aspnetcore-runtime-wrapped-6.0.36"
          "dotnet-sdk-wrapped-6.0.428"
          "dotnet-sdk-6.0.428"
        ];

        services.sonarr = {
          enable = true;
          user = "media";
          group = "media";
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            home = "/var/lib/sonarr";
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
            isNormalUser = false;
          };
        };
      };
    };

    watch = {
      inherit hostAddress;

      localAddress = "192.168.100.18";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
        "/snowscape/music/albums" = {
          hostPath = "/snowscape/music/albums";
          isReadOnly = false;
        };
        "/snowscape/videos" = {
          hostPath = "/snowscape/videos";
          isReadOnly = false;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        services.jellyfin = {
          enable = true;
          user = "media";
          group = "media";
        };

        systemd.services.jellyfin = {
          serviceConfig = {
            LimitNOFILE = 65536;
          };
        };

        boot.kernel.sysctl = {
          "fs.inotify.max_user_watches" = 524288;
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            home = "/var/lib/jellyfin";
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
            isNormalUser = false;
          };
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 8096;
            };
          };
        };
      };
    };

    films = {
      inherit hostAddress;

      localAddress = "192.168.100.16";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
        "/snowscape/videos/films" = {
          hostPath = "/snowscape/videos/films";
          isReadOnly = false;
        };
        "/var/lib/sabnzbd/Downloads/complete" = {
          hostPath = "/var/lib/nixos-containers/usenet/var/lib/sabnzbd/Downloads/complete";
          isReadOnly = false;
        };
        "/var/lib/transmission/Downloads" = {
          hostPath = "/var/lib/nixos-containers/torrents/var/lib/transmission/Downloads";
          isReadOnly = false;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 7878;
            };
          };
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            home = "/var/lib/radarr";
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
            isNormalUser = false;
          };
        };

        services.radarr = {
          enable = true;
          user = "media";
          group = "media";
        };
      };
    };

    music = {
      inherit hostAddress;

      localAddress = "192.168.100.14";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
          ./resonance.nix
        ];

        services.resonance = {
          enable = true;
          package = inputs.resonance.packages.${system}.resonance;

          # port = 5000;
          # dataDir = "/var/lib/resonance";
          # openFirewall = true;
        };

        networking = {
          useHostResolvConf = false; # Don't use host's resolv.conf
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 5000;
            };
          };
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
            isNormalUser = false;
          };
        };
      };
    };

    listen = {
      inherit hostAddress;

      localAddress = "192.168.100.20";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "/snowscape/podcasts" = {
          hostPath = "/snowscape/podcasts";
          isReadOnly = false;
        };
        "/snowscape/audiobooks" = {
          hostPath = "/snowscape/audiobooks";
          isReadOnly = false;
        };
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];

        services.audiobookshelf = {
          enable = true;
          user = "media";
          group = "media";
        };

        networking = {
          useHostResolvConf = false; # Don't use host's resolv.conf
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 8000;
            };
          };
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            isSystemUser = false;
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
          };
        };
      };
    };

    notify = {
      inherit hostAddress;

      localAddress = "192.168.100.10";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
      };

      config = {...}: let
        port = 8080;
      in {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];

        networking = {
          useHostResolvConf = false; # Don't use host's resolv.conf
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        services.ntfy-sh = {
          enable = true;
          settings = {
            listen-http = ":${builtins.toString port}";
            base-url = "https://notify.${tailscaleMagicDns}";
          };
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = port;
            };
          };
        };
      };
    };

    read = let
      kavitaTokenFile = config.age.secrets."kavita".path;
    in {
      inherit hostAddress;

      localAddress = "192.168.100.21";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "/snowscape/books" = {
          hostPath = "/snowscape/books";
          isReadOnly = false;
        };
        "/snowscape/comics" = {
          hostPath = "/snowscape/comics";
          isReadOnly = false;
        };
        "${kavitaTokenFile}" = {
          hostPath = kavitaTokenFile;
          isReadOnly = true;
        };
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];

        services.kavita = {
          enable = true;
          user = "media";
          tokenKeyFile = kavitaTokenFile;
        };

        networking = {
          useHostResolvConf = false; # Don't use host's resolv.conf
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 5000;
            };
          };
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
          };
        };
      };
    };
  };

  # backpacker = {
  #   performance.enable = true;
  #   profiles.laptop.enable = true;
  #   hardware.cpu.type = "intel";
  #   networking.core.names = [
  #     {
  #       name = "eth-primary";
  #       mac = "70:85:c2:c3:ff:09";
  #     }
  #     {
  #       name = "eth-secondary";
  #       mac = "00:e0:4c:68:01:39";
  #     }
  #   ];
  # };
  #
  # services.gamerack = {
  #   enable = true;
  #   database = "/glacier/snowscape/gaming/profiles/simonwjackson/games.yaml";
  #   environmentFiles = [
  #     config.age.secrets.game-collection-sync.path
  #   ];
  #   environment = {
  #     STEAM_ID = "76561198041190539";
  #     MOBY_USERNAME = "simonwjackson";
  #     MOBY_COLLECTION_ID = "333655";
  #     MOBY_COOKIE_FILE = "/tmp/mobygames-cookie.txt";
  #   };
  # };
  #

  # services.samba-wsdd.enable = true; # make shares visible for windows 10 clients
  # services.samba = {
  #   enable = true;
  #   securityType = "user";
  #   extraConfig = ''
  #     workgroup = MOUNTAINOUS
  #     server string = unzen
  #     netbios name = unzen
  #     security = user
  #     #use sendfile = yes
  #     #max protocol = smb2
  #     # note: localhost is the ipv6 localhost ::1
  #     hosts allow = 100. 192.18. 10.147.19. 127.0.0.1 localhost
  #     hosts deny = 0.0.0.0/0
  #     guest account = nobody
  #     map to guest = bad user
  #     acl allow execute always = True
  #   '';
  #   shares = {
  #     snowscape = {
  #       path = "/glacier/snowscape";
  #       browseable = "yes";
  #       "read only" = "no";
  #       "guest ok" = "yes";
  #       "create mask" = "0644";
  #       "directory mask" = "0755";
  #       "force user" = "simonwjackson";
  #       "force group" = "users";
  #     };
  #   };
  # };
  #

  services.borgbackup.jobs = {
    gaming-profiles = {
      paths = "/snowscape/gaming/profiles";
      repo = "/avalanche/groups/local/snowscape/backup/gaming-profiles";
      encryption.mode = "none";
      compression = "zstd,3";
      startAt = "*:0/5";
      exclude = [];
      prune = {
        keep = {
          within = "1d"; # Keep all within 1 day
          daily = 7; # Keep 7 daily backups
          weekly = 4; # Keep 4 weekly backups
          monthly = 6; # Keep 6 monthly backups
          yearly = 1; # Keep 1 yearly backup
        };
      };
    };

    media-services = {
      paths = [
        "/var/lib/nixos-containers/series/var/lib/sonarr"
        "/var/lib/nixos-containers/films/var/lib/radarr"
        "/var/lib/nixos-containers/index/var/lib/prowlarr"
        "/var/lib/nixos-containers/watch/var/lib/jellyfin"
      ];
      repo = "/avalanche/groups/local/snowscape/backup/media-services";
      encryption.mode = "none";
      compression = "lz4";
      startAt = "daily";
      exclude = [
        # Jellyfin excludes
        "**/jellyfin/log/*"
        "**/jellyfin/data/cache*"
        "**/jellyfin/data/transcoding-temp"
        "**/jellyfin/.aspnet"
        "**/jellyfin/plugins"
        "**/jellyfin/root"
        "**/jellyfin/Subtitle Edit"

        # Common patterns across *arr services
        "**/asp/**" # ASP.NET temporary files
        "**/logs/**" # Log directories
        "**/logs.db*" # Log database files
        "**/*.pid" # Process ID files
        "**/Sentry/**" # Sentry crash reporting
        "**/*db-shm" # SQLite shared memory files
        "**/*db-wal" # SQLite write-ahead logs
        "**/MediaCover/**" # Can be regenerated from metadata
      ];
      prune = {
        keep = {
          daily = 7;
          weekly = 4;
          monthly = 6;
          yearly = 2;
        };
      };
    };

    notes = {
      paths = "/snowscape/notes";
      repo = "/avalanche/groups/local/snowscape/backup/notes";
      encryption.mode = "none";
      compression = "zstd,3";
      startAt = "*:0/5";
      exclude = [];
      prune = {
        keep = {
          within = "1d"; # Keep all within 1 day
          daily = 7; # Keep 7 daily backups
          weekly = 4; # Keep 4 weekly backups
          monthly = 6; # Keep 6 monthly backups
          yearly = 1; # Keep 1 yearly backup
        };
      };
    };
  };

  services.syncthing = {
    enable = true;
    key = config.age.secrets.unzen-syncthing-key.path;
    cert = config.age.secrets.unzen-syncthing-cert.path;
  };

  services.printing.enable = true;
  services.printing.drivers = with pkgs; [brlaser];

  # Enable automatic discovery of the printer from other Linux systems with avahi running. services.avahi.enable = true;
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  services.printing.browsing = true;
  services.printing.listenAddresses = ["*:631"]; # Not 100% sure this is needed and you might want to restrict to the local network
  services.printing.allowFrom = ["all"]; # this gives access to anyone on the interface you might want to limit it see the official documentation
  services.printing.defaultShared = true; # If you want

  boot = {
    # EFI and bootloader configuration
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # Kernel modules configuration
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [];
    };

    # General kernel configuration
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
    supportedFilesystems = ["zfs"];
    kernelPackages = pkgs.linuxPackages_6_6;

    zfs = {
      extraPools = ["iceberg.1"];
      forceImportRoot = false;
    };
  };

  services.zfs = {
    zed.settings = {
      ZED_DEBUG_LOG = "/var/log/zed.log";
      ZED_EMAIL_ADDR = "unzen@simonwjackson.io";
      ZED_EMAIL_PROG = "mail";
      ZED_EMAIL_OPTS = "-s '@SUBJECT@' @ADDRESS@";
    };
    trim.enable = false;
    autoSnapshot = {
      enable = true;
      flags = "-k -p --utc";
      frequent = 8;
      hourly = 24;
      daily = 14;
      weekly = 8;
      monthly = 12;
    };
    autoScrub = {
      enable = true;
      interval = "weekly";
    };
  };

  systemd.services.zfs-setup = {
    description = "Configure ZFS dataset properties";
    wantedBy = ["multi-user.target"];
    after = ["zfs.target" "zfs-mount.service"];
    requires = ["zfs.target" "zfs-mount.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "zfs-setup" ''
        # Create necessary directories
        mkdir -p /avalanche/merged/photos

        # Pool-level properties
        ${pkgs.zfs}/bin/zfs set compression=zstd iceberg.1 || true
        ${pkgs.zfs}/bin/zfs set atime=off iceberg.1 || true
        ${pkgs.zfs}/bin/zfs set xattr=sa iceberg.1 || true
        ${pkgs.zfs}/bin/zfs set recordsize=1M iceberg.1 || true
        ${pkgs.zfs}/bin/zfs set "com.sun:auto-snapshot"=false iceberg.1 || true
        ${pkgs.zfs}/bin/zfs set relatime=off iceberg.1 || true
        ${pkgs.zfs}/bin/zfs set acltype=posixacl iceberg.1 || true

        # Photos dataset
        ${pkgs.zfs}/bin/zfs create -p iceberg.1/photos 2>/dev/null || true
        ${pkgs.zfs}/bin/zfs set compression=zstd iceberg.1/photos || true
        ${pkgs.zfs}/bin/zfs set atime=off iceberg.1/photos || true
        ${pkgs.zfs}/bin/zfs set recordsize=1M iceberg.1/photos || true
        ${pkgs.zfs}/bin/zfs set mountpoint=/avalanche/merged/photos iceberg.1/photos || true
        ${pkgs.zfs}/bin/zfs set xattr=sa iceberg.1/photos || true
        ${pkgs.zfs}/bin/zfs set "com.sun:auto-snapshot"=true iceberg.1/photos || true
        ${pkgs.zfs}/bin/zfs set canmount=on iceberg.1/photos || true
        ${pkgs.zfs}/bin/zfs set relatime=off iceberg.1/photos || true
        ${pkgs.zfs}/bin/zfs set acltype=posixacl iceberg.1/photos || true

        # Set permissions
        ${pkgs.coreutils}/bin/chown media:media /avalanche/merged/photos
        ${pkgs.coreutils}/bin/chmod 2775 /avalanche/merged/photos

        # Ensure datasets are mounted
        ${pkgs.zfs}/bin/zfs mount iceberg.1/photos 2>/dev/null || true
      '';
    };
  };

  networking.hostId = "174c321a";
  networking.useDHCP = lib.mkDefault true;

  # Enable SMART monitoring
  services.smartd = {
    enable = true;
    autodetect = true; # Monitor all devices that support SMART
    notifications = {
      mail.enable = true;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  system.stateVersion = "23.05"; # Did you read the comment?
}
