{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "yari";
  networking.useDHCP = true;
  time.timeZone = "UTC";

  mountainous = {
    presets = {
      core = {
        enable = true;
        passwordHash = "$6$2Kj4v9kellv./s7d$NkKiUruNiNPDtFJSwsTCIaTGLZ9hf1Yak64FXzFL2ZBMTiQDFW3RcEzOwCCezYOXC7b3UrxmEGbAw/TPehWKv1";
      };
      server.enable = true;
    };

    features = {
      # ── Networking ───────────────────────────────────────────────────
      tsnet-proxy = {
        enable = true;
        package = pkgs.tsnet-proxy;
        authKeyFile = config.age.secrets.tailscale-authkey.path;
      };

      # Current policy caveat: downloader daemons and VPN-routed apps such as
      # NZBGet, Transmission, Prowlarr, and Sonarr run inside the FastestVPN
      # namespace, but the Tailscale-facing tsnet-proxy services remain
      # host-side and forward to the namespace over the veth link. That keeps
      # downloader/app egress VPN-isolated, but it is not the stricter "all
      # traffic through VPN" design for Tailscale UI/admin access.
      vpn-ns = {
        enable = true;
        configFile = config.age.secrets."fastest-vpn".path;
        localNetworks = ["100.64.0.0/10"];
        tailscaleHosts = [
          "tv.hummingbird-lake.ts.net"
          "movies.hummingbird-lake.ts.net"
        ];
        services.nzbget = {
          enable = true;
          unit = "nzbget.service";
          port = config.mountainous.features.nzbget.port;
          tailscale = {
            enable = true;
            hostname = "usenet";
            protocol = "http";
          };
        };
      };

      # ── Storage ──────────────────────────────────────────────────────
      # Yari is currently a single-disk system. Physical media and downloads
      # live under /srv/basin. The media-tiering module mounts mergerfs at
      # /srv/range/media/{movies,tv} so ARR services see a unified view of
      # local and remote (zao) content.
      media = {
        enable = true;
        root = "/srv/basin";
      };

      media-tiering = {
        enable = true;
        role = "source";
        peerHost = "zao";
        mover = {
          enable = true;
          jellyfin.passwordFile = config.age.secrets.jellyfin-pass.path;
        };
      };

      # ── Services ─────────────────────────────────────────────────────

      nzbget = {
        enable = true;
        openFirewall = false;
        settings = {
          "Server1.Name" = "newsdemon";
          "Server1.Host" = "news.newsdemon.com";
          "Server1.Port" = 563;
          "Server1.Encryption" = true;
          "Server1.Connections" = 50;
          # Buffer articles in RAM so 50 connections don't stall on HDD I/O.
          # 500 MB cache lets NZBGet absorb bursts and flush to disk smoothly.
          ArticleCache = 500;
          WriteBuffer = 1024; # 1024 KB per connection write buffer
          DirectUnpack = "yes";
          UMask = "0002";
        };
        secretSettings = {
          ControlPassword = config.age.secrets.nzbget-pass.path;
          "Server1.Username" = config.age.secrets.newsdemon-user.path;
          "Server1.Password" = config.age.secrets.newsdemon-pass.path;
        };
      };

      prowlarr = {
        enable = true;
        openFirewall = false;
        auth = {
          enable = true;
          username = "simonwjackson";
          passwordFile = config.age.secrets.prowlarr-pass.path;
        };
        indexers.nzbgeek = {
          enable = true;
          apiKeyFile = config.age.secrets.nzbgeek-api.path;
        };
        applications.sonarr = {
          enable = true;
          prowlarrUrl = "https://indexers.hummingbird-lake.ts.net";
          baseUrl = "https://tv.hummingbird-lake.ts.net";
        };
        applications.radarr = {
          enable = true;
          prowlarrUrl = "https://indexers.hummingbird-lake.ts.net";
          baseUrl = "https://movies.hummingbird-lake.ts.net";
        };
        vpn.enable = true;
        proxy = {
          enable = true;
          hostname = "indexers";
          openFirewall = false;
        };
      };

      radarr = {
        enable = true;
        openFirewall = false;
        auth = {
          enable = true;
          username = "simonwjackson";
          passwordFile = config.age.secrets.radarr-pass.path;
        };
        vpn.enable = false;
        proxy = {
          enable = true;
          hostname = "movies";
          openFirewall = false;
        };
        notifications.webhookRelay = {
          enable = true;
          url = "http://127.0.0.1:9100/hook/radarr";
          actionUrl = "https://movies.hummingbird-lake.ts.net";
        };
        notifications.jellyfin = {
          enable = true;
          host = "zao";
          username = "simonwjackson";
          passwordFile = config.age.secrets.jellyfin-pass.path;
        };

        # Movie import path/category conventions:
        # - Movies via NZBGet category: Movies
        # - Movies via Transmission category: movies-radarr
        # - Movie library root: /srv/range/media/movies (mergerfs union)
        moviesLibraryDir = config.mountainous.features.media.moviesDir;
        usenetCompletedDir = config.mountainous.features.media.usenetCompletedDir;
        torrentsCompletedDir = config.mountainous.features.media.torrentsCompletedDir;

        downloadClients = {
          nzbget = {
            enable = true;
            name = "NZBGet (usenet)";
            priority = 10;
            category = "Movies";
            host = "usenet.hummingbird-lake.ts.net";
            port = 443;
            useSsl = true;
            passwordFile = config.age.secrets.nzbget-pass.path;
          };
          transmission = {
            enable = true;
            name = "Transmission (torrent)";
            priority = 20;
            category = "movies-radarr";
            host = "torrents.hummingbird-lake.ts.net";
            port = 443;
            useSsl = true;
          };
        };
      };

      sonarr = {
        enable = true;
        openFirewall = false;
        auth = {
          enable = true;
          username = "simonwjackson";
          passwordFile = config.age.secrets.sonarr-pass.path;
        };
        vpn.enable = false;
        proxy = {
          enable = true;
          hostname = "tv";
          openFirewall = false;
        };
        notifications.webhookRelay = {
          enable = true;
          url = "http://127.0.0.1:9100/hook/sonarr";
          actionUrl = "https://tv.hummingbird-lake.ts.net";
        };
        notifications.jellyfin = {
          enable = true;
          host = "zao";
          username = "simonwjackson";
          passwordFile = config.age.secrets.jellyfin-pass.path;
        };

        # ARR/UI endpoint conventions on yari:
        # - Sonarr: tv.*    - Jellyfin: watch.*
        # - Prowlarr: indexers.*    - Radarr: movies.*
        # - NZBGet: usenet.*    - Transmission: torrents.*
        tvLibraryDir = config.mountainous.features.media.tvDir;
        usenetCompletedDir = config.mountainous.features.media.usenetCompletedDir;
        torrentsCompletedDir = config.mountainous.features.media.torrentsCompletedDir;

        downloadClients = {
          nzbget = {
            enable = true;
            name = "NZBGet (usenet)";
            priority = 10;
            category = "Series";
            host = "usenet.hummingbird-lake.ts.net";
            port = 443;
            useSsl = true;
            passwordFile = config.age.secrets.nzbget-pass.path;
          };
          transmission = {
            enable = true;
            name = "Transmission (torrent)";
            priority = 20;
            category = "tv-sonarr";
            host = "torrents.hummingbird-lake.ts.net";
            port = 443;
            useSsl = true;
          };
        };
      };

      transmission = {
        enable = true;
        openFirewall = false;
      };

      # ── Messaging ─────────────────────────────────────────────────────
      matrix = {
        enable = true;
        serverName = "yari";
        admin = {
          username = "simonwjackson";
          passwordFile = config.age.secrets.matrix-admin-pass.path;
        };
        registrationSharedSecretFile = config.age.secrets.matrix-shared-secret.path;
        backup = {
          enable = true;
          passphraseFile = config.age.secrets.borg-passphrase.path;
          cloudSync = {
            enable = true;
            rcloneConfigFile = config.age.secrets.rclone-conf.path;
          };
        };
        proxy.enable = true;
        notifications = {
          enable = true;
          bot.passwordFile = config.age.secrets.matrix-notify-bot-pass.path;
          webhookRelay.enable = true;
          systemdAlerts = {
            enable = true;
            services = [
              "matrix-synapse"
              "borgbackup-job-matrix"
              "sonarr"
              "radarr"
              "nzbget"
              "transmission"
            ];
          };
        };
        bridges = {
          signal = {
            enable = true;
            environmentFile = config.age.secrets.mautrix-signal-env.path;
          };
          whatsapp = {
            enable = true;
            environmentFile = config.age.secrets.mautrix-whatsapp-env.path;
          };
        };
      };
    };
  };

  users.users.simonwjackson.extraGroups = [
    "media"
  ];

  # Do not bind sshd to a specific Tailscale address at boot. tailscale0 can
  # come up after sshd starts, which leaves the daemon failed after a reboot.
  # The firewall still restricts remote SSH access to trusted Tailscale traffic.

  environment.systemPackages = with pkgs; [
    chromium
    stdenv.cc.cc.lib
    nodejs
    git
    curl
    cmake
    gnumake
    gcc
  ];

  # ── Secrets (overrides for auto-discovered defaults) ──────────────────

  age.secrets.mautrix-signal-env = {
    owner = "mautrix-signal";
    group = "mautrix-signal";
    mode = "0400";
  };

  age.secrets.mautrix-whatsapp-env = {
    owner = "mautrix-whatsapp";
    group = "mautrix-whatsapp";
    mode = "0400";
  };

  age.secrets.tailscale-authkey = {
    owner = "tsnet-proxy";
    group = "tsnet-proxy";
  };

  # Service-specific ownership for usenet/media secrets
  age.secrets.nzbget-pass = { owner = "nzbget"; group = "media"; mode = "0440"; };
  age.secrets.newsdemon-user = { owner = "nzbget"; group = "media"; mode = "0440"; };
  age.secrets.newsdemon-pass = { owner = "nzbget"; group = "media"; mode = "0440"; };
  age.secrets.radarr-pass = { owner = "radarr"; group = "media"; mode = "0440"; };

  # Aliases: same nzbget-pass file decrypted for different service users
  age.secrets.sonarr-pass = {
    file = config.age.secrets.nzbget-pass.file;
    owner = "sonarr";
    group = "media";
    mode = "0440";
  };

  age.secrets.prowlarr-pass = {
    file = config.age.secrets.nzbget-pass.file;
  };

  # Trust fuji's signing key for remote deployments
  nix.settings.trusted-public-keys = [
    "fuji-1:0mnvKZa4ZzMJgSgFfQLdQzwcdUtiGqZxxcImE/i9wDo="
  ];

  system.stateVersion = "24.11";
}
