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

  mountainous.presets = {
    core = {
      enable = true;
      passwordHash = "$6$2Kj4v9kellv./s7d$NkKiUruNiNPDtFJSwsTCIaTGLZ9hf1Yak64FXzFL2ZBMTiQDFW3RcEzOwCCezYOXC7b3UrxmEGbAw/TPehWKv1";
    };
    server.enable = true;
  };

  users.users.simonwjackson.extraGroups = [
    "media"
  ];

  # ── SSH (Tailscale-only) ─────────────────────────────────────────────

  # Do not bind sshd to a specific Tailscale address at boot. tailscale0 can
  # come up after sshd starts, which leaves the daemon failed after a reboot.
  # The firewall still restricts remote SSH access to trusted Tailscale traffic.

  # ── Security ─────────────────────────────────────────────────────────

  # ── Media Layout ─────────────────────────────────────────────────────

  # Yari is currently a single-disk system, so keep the service-facing paths
  # stable on /srv for now. If dedicated media disks or a mergerfs pool are
  # added later, /srv/storage can become the mountpoint without changing the
  # downloader or library paths used by services.
  mountainous.features.media = {
    enable = true;
    root = "/srv/storage";
  };

  mountainous.features.nzbget = {
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

  mountainous.features.transmission = {
    enable = true;
    openFirewall = false;
  };

  mountainous.features.jellyfin = {
    enable = true;
    openFirewall = false;
    bootstrap = {
      enable = true;
      admin = {
        username = "simonwjackson";
        passwordFile = config.age.secrets.jellyfin-pass.path;
      };
      serverName = "yari";
      remoteAccess = false;
      libraries = {
        tv = {
          name = "TV";
          path = "/srv/storage/media/tv";
        };
        movies = {
          name = "Movies";
          path = "/srv/storage/media/movies";
        };
      };
    };
    proxy = {
      enable = true;
      hostname = "watch";
      openFirewall = false;
    };
    watchedCleaner = {
      enable = true;
    };
  };

  mountainous.features.prowlarr = {
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
    applications.sonarr.enable = true;
    applications.radarr.enable = true;
    vpn.enable = true;
    proxy = {
      enable = true;
      hostname = "indexers";
      openFirewall = false;
    };
  };

  mountainous.features.sonarr = {
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

    # ARR/UI endpoint conventions on yari:
    # - Sonarr: tv.*
    # - Jellyfin: watch.*
    # - Prowlarr: indexers.*
    # - Radarr: movies.*
    # - NZBGet UI/client: usenet.*
    # - Transmission UI/client: torrents.*
    #
    # Import path/category conventions:
    # - TV via NZBGet category: Series
    # - TV via Transmission category: tv-sonarr
    # - TV library root: /srv/storage/media/tv
    tvLibraryDir = config.mountainous.features.media.tvDir;
    usenetCompletedDir = config.mountainous.features.media.usenetCompletedDir;
    torrentsCompletedDir = config.mountainous.features.media.torrentsCompletedDir;

    # Selection intent:
    # - Usenet releases go to NZBGet
    # - Torrent releases go to Transmission
    # - Priority mainly matters once we have multiple clients of the same protocol
    downloadClients = {
      nzbget = {
        enable = true;
        name = "NZBGet (usenet)";
        priority = 10;
        category = "Series";
        passwordFile = config.age.secrets.nzbget-pass.path;
      };
      transmission = {
        enable = true;
        name = "Transmission (torrent)";
        priority = 20;
        category = "tv-sonarr";
      };
    };
  };

  mountainous.features.radarr = {
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

    # Movie import path/category conventions:
    # - Movies via NZBGet category: Movies
    # - Movies via Transmission category: movies-radarr
    # - Movie library root: /srv/storage/media/movies
    moviesLibraryDir = config.mountainous.features.media.moviesDir;
    usenetCompletedDir = config.mountainous.features.media.usenetCompletedDir;
    torrentsCompletedDir = config.mountainous.features.media.torrentsCompletedDir;

    downloadClients = {
      nzbget = {
        enable = true;
        name = "NZBGet (usenet)";
        priority = 10;
        category = "Movies";
        passwordFile = config.age.secrets.nzbget-pass.path;
      };
      transmission = {
        enable = true;
        name = "Transmission (torrent)";
        priority = 20;
        category = "movies-radarr";
      };
    };
  };

  # ── Packages ─────────────────────────────────────────────────────────

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

  # ── Tailscale ────────────────────────────────────────────────────────

  mountainous.features.tsnet-proxy = {
    enable = true;
    package = pkgs.tsnet-proxy;
    authKeyFile = config.age.secrets.tailscale-authkey.path;
  };

  # ── VPN Namespace ────────────────────────────────────────────────────

  # Current policy caveat: downloader daemons and VPN-routed apps such as
  # NZBGet, Transmission, Prowlarr, and Sonarr run inside the FastestVPN
  # namespace, but
  # the Tailscale-facing tsnet-proxy services remain host-side and forward to
  # the namespace over the veth link. That keeps downloader/app egress
  # VPN-isolated, but it is not the stricter "all traffic through VPN" design
  # for Tailscale UI/admin access.
  mountainous.features.vpn-ns = {
    enable = true;
    configFile = config.age.secrets."fastest-vpn".path;
    localNetworks = ["100.64.0.0/10"];
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

  # ── OpenClaw Node ────────────────────────────────────────────────────

  systemd.services.openclaw-node = {
    description = "OpenClaw Node Host";
    after = [
      "network-online.target"
      "tailscale.service"
    ];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    path = [
      pkgs.nodejs
      pkgs.git
      pkgs.curl
      pkgs.chromium
      pkgs.coreutils
      pkgs.bash
      pkgs.cmake
      pkgs.gnumake
      pkgs.gcc
    ];
    environment = {
      HOME = "/home/simonwjackson";
      OPENCLAW_STATE_DIR = "/home/simonwjackson/.openclaw";
      LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
    };
    serviceConfig = {
      Type = "simple";
      User = "simonwjackson";
      Group = "users";
      TimeoutStartSec = "30min";
      EnvironmentFile = config.age.secrets.openclaw-env.path;
      ExecStartPre = let
        setupScript = pkgs.writeShellScript "openclaw-node-setup" ''
          export HOME=/home/simonwjackson
          mkdir -p "$HOME/.openclaw"
          cd "$HOME/.openclaw"
          ${pkgs.nodejs}/bin/npm install openclaw@latest
        '';
      in "${setupScript}";
      ExecStart = let
        startScript = pkgs.writeShellScript "openclaw-node-start" ''
          export HOME=/home/simonwjackson
          exec ${pkgs.nodejs}/bin/node "$HOME/.openclaw/node_modules/openclaw/dist/index.js" node run \
            --host openclaw.hummingbird-lake.ts.net \
            --port 443 \
            --tls \
            --display-name yari
        '';
      in "${startScript}";
      Restart = "always";
      RestartSec = 10;
      KillMode = "process";
    };
  };

  # Trust fuji's signing key for remote deployments
  nix.settings.trusted-public-keys = [
    "fuji-1:0mnvKZa4ZzMJgSgFfQLdQzwcdUtiGqZxxcImE/i9wDo="
  ];

  system.stateVersion = "24.11";
}
