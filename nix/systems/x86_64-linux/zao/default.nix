{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  # Boot configuration for 11th Gen Intel Core i9-11900H (Tiger Lake)
  # Dual USB boot with GRUB for redundancy, btrfs RAID for storage
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "uas" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];

    # Zen kernel for low-latency game streaming (Sunshine) and media server (Jellyfin)
    # Matches aka and hotaka gaming systems for fleet consistency
    kernelPackages = pkgs.linuxPackages_zen;

    # Kernel parameters for server performance and stability
    kernelParams = [
      "nvme_core.default_ps_max_latency_us=0" # Prevent NVMe power state issues
      "intel_pstate=active" # Use Intel P-state driver
    ];

    loader = {
      efi.canTouchEfiVariables = false;
      efi.efiSysMountPoint = "/boot";
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true; # Install to /EFI/BOOT/BOOTX64.EFI for SD card
        device = "nodev"; # EFI only, no MBR
      };
    };
  };

  # Hardware configuration
  # Hybrid graphics: Intel integrated (i915) + NVIDIA RTX 3060 Mobile
  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    bluetooth.enable = true;

    # NVIDIA proprietary drivers with Prime offload
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = lib.mkDefault true;
      powerManagement.finegrained = false;
      open = false; # Use proprietary driver, not open source kernel modules
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      # Prime configuration for hybrid graphics
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # Bus IDs detected from system
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };

    # Graphics configuration for hybrid GPU setup
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but sometimes works better)
        libva-vdpau-driver
        libvdpau-va-gl
      ];
      extraPackages32 = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
      ];
    };
  };

  # Load NVIDIA driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  # Hardware monitoring and maintenance tools
  environment.systemPackages = with pkgs; [
    # Storage health
    smartmontools # SMART monitoring (smartctl)
    nvme-cli # NVMe health and management
    btrfs-progs # Btrfs utilities (scrub, balance, etc.)

    # System monitoring
    lm_sensors # Temperature monitoring
    htop # Process monitor
    btop # Beautiful system monitor

    # Hardware info
    pciutils # lspci
    usbutils # lsusb
    dmidecode # Hardware info
  ];

  # Networking
  networking.hostName = "zao";
  networking.useDHCP = lib.mkDefault true;

  # Thunderbolt networking to Mac Mini (via WD19TB dock)
  # Provides high-speed direct connection (~20-40 Gbps) for file transfers
  # Uses udev rule + networkmanager to configure when device appears (won't block boot)
  services.udev.extraRules = ''
    # Configure thunderbolt0 with static IP when it appears
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="thunderbolt0", RUN+="${pkgs.networkmanager}/bin/nmcli connection add type ethernet con-name thunderbolt0 ifname thunderbolt0 ipv4.method manual ipv4.addresses 192.168.2.1/24 connection.autoconnect yes 2>/dev/null || true"
  '';

  # Enable profiles for desktop/gaming server
  mountainous = {
    iceberg-array.enable = true;

    directories.paths = {
      "/tundra/merged/iceberg/knowledge" = {
        owner = "simonwjackson";
        group = "users";
        mode = "0755";
      };
      # movies and series directories now managed by mountainous.media.paths
    };

    profiles = {
      base.enable = true;
      workspace.enable = true;
    };

    # Device configuration: laptop chassis used as headless server
    device = {
      role = "server"; # Usage: runs 24/7, serves game streams
      capabilities = {
        battery = true; # Has battery (graceful shutdown on power loss)
        formFactor = "laptop"; # Thermal profile of a laptop
        touchscreen = false;
      };
    };

    # Unified gaming feature (reads from device.role/traits)
    gaming = {
      enable = true;

      # Enable game streaming with Sunshine
      streaming = {
        enable = true;
        monitors.primary = "DP-1"; # Virtual display for streaming
      };
    };

    # Unified impermanence configuration
    # Subvolumes (@nix, @permafrost, @log) generated by impermanence feature
    impermanence = {
      enable = true;
      persistFsType = "btrfs";

      # zao-specific persistence: /tundra/igloo directory
      extraDirectories = [
        {
          directory = "/tundra/igloo";
          user = "simonwjackson";
          group = "users";
          mode = "0700";
        }
      ];
    };

    # NFS client - mount Steam library from aka
    gaming.library.remote = {
      enable = true;
      server = "aka"; # Tailscale DNS name
      remotePath = "/home/simonwjackson/.local/share/Steam";
      mountPoint = "/tundra/avalanche/steam";
    };
  };

  # Media namespace configuration
  mountainous.media = {
    # Shared paths for media content
    paths = {
      movies = "/tundra/merged/iceberg/movies";
      series = "/tundra/merged/iceberg/series";
    };

    # FlexGet media automation
    flexget = {
      enable = true;
      user = "media";
      group = "media";
      dataDir = "/var/lib/flexget";
      interval = "15m";

      webUI = {
        enable = true;
        port = 5050;
        passwordFile = config.age.secrets.flexget-password.path;
      };

      config = {
        variables = "/var/lib/flexget/variables.yml";

        templates = {
          "nzbget-series".nzbget = {
            url = "https://nzbget:{? nzbget_pass ?}@usenet.hummingbird-lake.ts.net/xmlrpc";
            category = "Series";
          };
          "nzbget-movies".nzbget = {
            url = "https://nzbget:{? nzbget_pass ?}@usenet.hummingbird-lake.ts.net/xmlrpc";
            category = "Movies";
          };
          # Transmission templates for torrent downloads via Bitmagnet
          "transmission-series".transmission = {
            host = "transmission.hummingbird-lake.ts.net";
            port = 443;
            path = "/tundra/merged/iceberg/series";
          };
          "transmission-movies".transmission = {
            host = "transmission.hummingbird-lake.ts.net";
            port = 443;
            path = "/tundra/merged/iceberg/movies";
          };
        };

        tasks = {
          "sync-trakt-shows" = {
            priority = 1;
            trakt_list = {
              account = "my-trakt";
              list = "watchlist";
              type = "shows";
            };
            accept_all = true;
            list_add = [{entry_list = "trakt-shows";}];
          };

          "sync-trakt-movies" = {
            priority = 2;
            trakt_list = {
              account = "my-trakt";
              list = "watchlist";
              type = "movies";
            };
            accept_all = true;
            list_add = [{movie_list = "trakt-movies";}];
          };

          "download-shows" = {
            priority = 10;
            template = "nzbget-series";
            rss = "https://api.nzbgeek.info/api?t=search&cat=5000&apikey={? nzbgeek_api ?}";
            configure_series = {
              from.entry_list = "trakt-shows";
              settings = {
                quality = "720p-2160p hdtv+ webdl webrip";
                target = "2160p webdl+"; # Upgrade target: 4K
                upgrade = true;
                propers = "12 hours";
                identified_by = "ep";
              };
            };
          };

          "download-movies" = {
            priority = 20;
            template = "nzbget-movies";
            discover = {
              what = [{movie_list = "trakt-movies";}];
              from = [
                {
                  newznab = {
                    website = "https://api.nzbgeek.info";
                    apikey = "{? nzbgeek_api ?}";
                    category = "movie";
                  };
                }
              ];
              release_estimations = "ignore";
            };
            quality = "1080p-2160p bluray webdl webrip";
            proper_movies = {
              interval = "30 days"; # Keep looking for 4K upgrades for 30 days
            };
            list_match.from = [{movie_list = "trakt-movies";}];
          };

          # Torrent tasks using Bitmagnet DHT indexer
          "download-shows-torrent" = {
            priority = 15;
            template = "transmission-series";
            discover = {
              what = [{entry_list = "trakt-shows";}];
              from = [
                {
                  torznab = {
                    website = "https://bitmagnet.hummingbird-lake.ts.net/torznab";
                    apikey = ""; # Bitmagnet doesn't require an API key
                    searcher = "tv";
                    categories = [5040 5045 5050]; # HD TV, WEB-DL TV, UHD TV
                  };
                }
              ];
              release_estimations = "ignore";
            };
            configure_series = {
              from.entry_list = "trakt-shows";
              settings = {
                quality = "720p-2160p hdtv+ webdl webrip";
                target = "2160p webdl+"; # Upgrade target: 4K
                upgrade = true;
                propers = "12 hours";
                identified_by = "ep";
              };
            };
          };

          "download-movies-torrent" = {
            priority = 25;
            template = "transmission-movies";
            discover = {
              what = [{movie_list = "trakt-movies";}];
              from = [
                {
                  torznab = {
                    website = "https://bitmagnet.hummingbird-lake.ts.net/torznab";
                    apikey = ""; # Bitmagnet doesn't require an API key
                    searcher = "movie";
                    categories = [2040 2045 2050]; # HD Movies, WEB-DL Movies, UHD Movies
                  };
                }
              ];
              release_estimations = "ignore";
            };
            quality = "1080p-2160p bluray webdl webrip";
            proper_movies = {
              interval = "30 days"; # Keep looking for 4K upgrades for 30 days
            };
            list_match.from = [{movie_list = "trakt-movies";}];
          };

          "sort-series" = {
            priority = 50;
            seen = "local";
            filesystem = {
              path = "/tundra/merged/iceberg/series";
              recursive = true;
              retrieve = "files";
              regexp = ''.*\.(mkv|mp4|avi)$'';
            };
            accept_all = true;
            metainfo_series = true;
            thetvdb_lookup = true;
            move = {
              to = ''/tundra/merged/iceberg/series/{{tvdb_series_name|default(series_name)|replace(" ", ".")|replace(":", "")}}/'';
              rename = ''{{tvdb_series_name|default(series_name)|replace(" ", ".")|replace(":", "")}}.{{series_id|upper}}{{location|pathext}}'';
              clean_source = 50;
            };
          };

          "sort-movies" = {
            priority = 51;
            seen = "local";
            filesystem = {
              path = "/tundra/merged/iceberg/movies";
              recursive = true;
              retrieve = "files";
              regexp = ''.*\.(mkv|mp4|avi)$'';
            };
            accept_all = true;
            imdb_lookup = true;
            move = {
              to = ''/tundra/merged/iceberg/movies/{{imdb_name|default(movie_name)|replace(' ', '.')}}.{{imdb_year|default(movie_year)}}/'';
              rename = ''{{imdb_name|default(movie_name)|replace(" ", ".")}}.{{imdb_year|default(movie_year)}}{{location|pathext}}'';
              clean_source = 50;
            };
          };
        };

        schedules = [
          {
            tasks = ["sync-trakt-shows" "sync-trakt-movies"];
            interval.hours = 1;
          }
          {
            tasks = ["download-shows" "download-movies"];
            interval.minutes = 30;
          }
          {
            tasks = ["download-shows-torrent" "download-movies-torrent"];
            interval.hours = 1;
          }
          {
            tasks = ["sort-series" "sort-movies"];
            interval.minutes = 15;
          }
        ];
      };
    };

    # Usenet binary downloader (NZBGet) with VPN isolation
    usenet = {
      enable = true;
      vpn.enable = true;
      proxy = {
        enable = true;
        name = "usenet";
      };

      servers.newsdemon = {
        host = "news.newsdemon.com";
        port = 563;
        username = "bzenujnaz5";
        passwordFile = config.age.secrets."newsdemon-pass".path;
        connections = 50;
      };

      # Category destinations auto-configured from paths above
      settings = {
        UMask = "0022"; # Standard permissions, both services run as media
      };
    };

    # Transmission BitTorrent client with VPN isolation
    transmission = {
      enable = true;
      vpn.enable = true;
      proxy = {
        enable = true;
        name = "transmission";
      };
    };

    # Bitmagnet DHT crawler and metadata indexer with VPN isolation
    bitmagnet = {
      enable = true;
      vpn.enable = true;
      proxy = {
        enable = true;
        name = "bitmagnet";
      };
      tmdb.apiKeyFile = config.age.secrets."tmdb-api".path;
    };
  };

  # tsnet-proxy for FlexGet webUI (accessible via Tailscale)
  mountainous.tsnet-proxy = {
    enable = true;
    authKeyFile = config.age.secrets."tailscale-ephemeral".path;

    services.flexget = {
      hostname = "flexget";
      protocol = "http";
      port = 5050;
    };
  };

  # Grant tsnet-proxy access to tailscale secret
  age.secrets."tailscale-ephemeral" = {
    owner = "tsnet-proxy";
    group = "tsnet-proxy";
  };

  # FlexGet password secret
  age.secrets.flexget-password = {
    owner = "media";
    group = "media";
  };

  # VPN namespace for isolated services (usenet, etc.)
  mountainous.vpn-ns = {
    enable = true;
    configFile = config.age.secrets."fastest-vpn".path;
    tailscaleDomain = "hummingbird-lake.ts.net";
  };

  # Grant media user read access to secrets
  age.secrets."newsdemon-pass" = {
    owner = "media";
    group = "media";
  };

  age.secrets."nzbgeek-api".owner = "media";
  age.secrets."nzbget-pass".owner = "media";

  # Bitmagnet TMDB API key (auto-discovered from secrets/system/bitmagnet/)
  age.secrets."tmdb-api".owner = "media";

  # Generate FlexGet variables.yml from secrets before starting
  systemd.services.flexget.serviceConfig.ExecStartPre = lib.mkBefore [
    (pkgs.writeShellScript "generate-flexget-variables" ''
      set -e
      NZBGEEK_API=$(cat ${config.age.secrets."nzbgeek-api".path} | cut -d= -f2)
      NZBGET_PASS=$(cat ${config.age.secrets."nzbget-pass".path} | cut -d= -f2)
      cat > /var/lib/flexget/variables.yml << EOF
      nzbgeek_api: "$NZBGEEK_API"
      nzbget_pass: "$NZBGET_PASS"
      EOF
    '')
  ];

  # Fix ownership for zao-specific persistent directory
  # The base impermanence feature handles home and nix profiles,
  # but we need to add our custom /tundra/igloo directory
  systemd.tmpfiles.settings."10-persistent-ownership" = {
    "/tundra/permafrost/tundra/igloo".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0700";
    };
  };

  # Storage and disk health maintenance
  # Btrfs maintenance - critical for RAID0 data integrity
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = ["/tundra/permafrost"];
  };

  # SSD TRIM maintenance (weekly)
  services.fstrim.enable = true;

  # SMART monitoring for NVMe health
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications = {
      wall.enable = true;
      x11.enable = false;
    };
  };

  # Server-specific optimizations for always-plugged-in laptop
  # Intel thermal management - prevents throttling and manages temps
  services.thermald.enable = true;

  # Disable battery-saving features since this runs as a server
  services.auto-cpufreq.enable = lib.mkForce false;

  # Prevent sleep/suspend - keep server running 24/7
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore"; # Don't suspend when lid closes
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "ignore";
    IdleAction = "ignore";
  };

  # CPU governor for consistent performance (not battery optimization)
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  system.stateVersion = "25.05";
}
