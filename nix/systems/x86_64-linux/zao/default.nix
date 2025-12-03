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
      # Keep GPU initialized for faster NVENC startup
      nvidiaPersistenced = true;

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
      # Immich library directories (per-user photo storage on mergerfs)
      "/tundra/merged/iceberg/photos/library" = {
        owner = "media";
        group = "media";
        mode = "0750";
      };
      "/tundra/merged/iceberg/photos/library/simon" = {
        owner = "media";
        group = "media";
        mode = "0750";
      };
      "/tundra/merged/iceberg/photos/library/laure" = {
        owner = "media";
        group = "media";
        mode = "0750";
      };
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
        # Use NVIDIA NVENC encoder with KMS capture for hybrid GPU system
        encoder = "nvenc";
        capture = "kms";
        # Low-latency NVENC settings for game streaming
        nvenc = {
          preset = "llhq"; # Low latency high quality
          rateControl = "cbr"; # Constant bitrate for stable streaming
        };
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
      comics = "/tundra/merged/iceberg/comics";
      photos = "/tundra/merged/iceberg/photos";
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

        templates = let
          nzbgetUrl = "https://nzbget:{? nzbget_pass ?}@usenet.hummingbird-lake.ts.net/xmlrpc";
          host = "https://transmission.hummingbird-lake.ts.net";
        in {
          "nzbget-series".nzbget = {
            url = nzbgetUrl;
            category = "Series";
          };
          "nzbget-movies".nzbget = {
            url = nzbgetUrl;
            category = "Movies";
          };
          "nzbget-comics".nzbget = {
            url = nzbgetUrl;
            category = "Comics";
          };
          # Transmission templates for torrent downloads via Tailscale proxy
          "transmission-series".transmission = {
            host = host;
            port = 443;
            path = "/tundra/merged/iceberg/series";
          };
          "transmission-movies".transmission = {
            host = host;
            port = 443;
            path = "/tundra/merged/iceberg/movies";
          };
          "transmission-comics".transmission = {
            host = host;
            port = 443;
            path = "/tundra/merged/iceberg/comics";
          };
        };

        tasks = {
          # Series downloads - query Trakt watchlist directly
          "download-shows" = {
            priority = 10;
            template = "nzbget-series";
            rss = "https://api.nzbgeek.info/api?t=search&cat=5000&apikey={? nzbgeek_api ?}";
            configure_series = {
              from.trakt_list = {
                account = "my-trakt";
                list = "watchlist";
                type = "shows";
              };
              settings = {
                quality = "720p-2160p hdtv+ webdl webrip";
                target = "2160p webdl+";
                upgrade = true;
                propers = "12 hours";
                identified_by = "ep";
              };
            };
          };

          "download-shows-torrent" = {
            priority = 15;
            template = "transmission-series";
            discover = {
              what = [
                {
                  trakt_list = {
                    account = "my-trakt";
                    list = "watchlist";
                    type = "shows";
                  };
                }
              ];
              from = [
                {
                  torznab = {
                    website = "https://bitmagnet.hummingbird-lake.ts.net/torznab";
                    apikey = "";
                    searcher = "tv";
                    categories = [5040 5045 5050];
                  };
                }
              ];
              release_estimations = "ignore";
              limit = 3; # Get top 3 results so we have alternatives if one fails
            };
            # Skip releases that previously stalled/failed
            remember_rejected = {
              retry_time = "7 days";
            };
            configure_series = {
              from.trakt_list = {
                account = "my-trakt";
                list = "watchlist";
                type = "shows";
              };
              settings = {
                quality = "720p-2160p hdtv+ webdl webrip";
                target = "2160p webdl+";
                upgrade = true;
                propers = "12 hours";
                identified_by = "ep";
              };
            };
          };

          # Movie downloads - query Trakt watchlist directly
          # Remove from Trakt watchlist when done to stop future downloads
          "download-movies" = {
            priority = 20;
            template = "nzbget-movies";
            discover = {
              what = [
                {
                  trakt_list = {
                    account = "my-trakt";
                    list = "watchlist";
                    type = "movies";
                  };
                }
              ];
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
              limit = 1; # Only grab one result per movie
            };
            quality = "1080p-2160p bluray webdl webrip";
            proper_movies = "30 days";
            imdb_lookup = true;
            # Reject if already downloaded, accept otherwise
            list_match = {
              from = [{movie_list = "downloaded-movies";}];
              action = "reject";
            };
            accept_all = true;
            # Track downloaded movies across all tasks
            list_add = [{movie_list = "downloaded-movies";}];
          };

          "download-movies-torrent" = {
            priority = 25;
            template = "transmission-movies";
            discover = {
              what = [
                {
                  trakt_list = {
                    account = "my-trakt";
                    list = "watchlist";
                    type = "movies";
                  };
                }
              ];
              from = [
                {
                  torznab = {
                    website = "https://bitmagnet.hummingbird-lake.ts.net/torznab";
                    apikey = "";
                    searcher = "movie";
                    categories = [2040 2045 2050];
                  };
                }
              ];
              release_estimations = "ignore";
              limit = 3; # Get top 3 results so we have alternatives if one fails
            };
            quality = "1080p-2160p bluray webdl webrip";
            proper_movies = "30 days";
            imdb_lookup = true;
            # Skip releases that previously stalled/failed
            remember_rejected = {
              retry_time = "7 days";
            };
            # Reject if already downloaded (by NZB or previous torrent run)
            list_match = {
              from = [{movie_list = "downloaded-movies";}];
              action = "reject";
            };
            accept_all = true;
            # Track downloaded movies across all tasks
            list_add = [{movie_list = "downloaded-movies";}];
          };

          # Comics tasks - watchlist managed via text file
          "sync-comics-watchlist" = {
            priority = 5;
            text = {
              url = "file:///tundra/merged/iceberg/comics/watchlist.txt";
              entry = {
                url = "(.+)"; # Required field - use line content
                title = "(.+)"; # Each line becomes a title
              };
            };
            accept_all = true;
            list_add = [{entry_list = "wanted-comics";}];
          };

          "download-comics" = {
            priority = 30;
            template = "nzbget-comics";
            rss = "https://api.nzbgeek.info/api?t=search&cat=7030&apikey={? nzbgeek_api ?}";
            crossmatch = {
              from = [{entry_list = "wanted-comics";}];
              fields = ["title"];
              action = "accept";
              exact = false; # Partial match (e.g., "Batman" matches "Batman #123")
            };
          };

          "download-comics-torrent" = {
            priority = 35;
            template = "transmission-comics";
            discover = {
              what = [{entry_list = "wanted-comics";}];
              from = [
                {
                  torznab = {
                    website = "https://bitmagnet.hummingbird-lake.ts.net/torznab";
                    apikey = "";
                    searcher = "search"; # Generic search for comics
                    categories = [7030]; # Comics category
                  };
                }
              ];
              release_estimations = "ignore";
            };
            crossmatch = {
              from = [{entry_list = "wanted-comics";}];
              fields = ["title"];
              action = "accept";
              exact = false;
            };
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

          # Cleanup completed torrents (keep files, remove from Transmission)
          "clean-completed" = {
            priority = 60;
            disable = ["seen" "seen_info_hash"]; # Don't check seen database for cleanup
            from_transmission = {
              host = "https://transmission.hummingbird-lake.ts.net";
              port = 443;
              only_complete = true;
            };
            # Remove completed torrents after 1 hour (gives sort tasks time to move files)
            "if" = [
              {"transmission_date_done < now - timedelta(hours=1)" = "accept";}
            ];
            transmission = {
              host = "https://transmission.hummingbird-lake.ts.net";
              port = 443;
              action = "remove"; # Keep files, just remove torrent
            };
          };

          # Purge stalled/dead torrents (delete incomplete files)
          # Also removes from downloaded-movies list so it can be re-tried with a different release
          "clean-stalled" = {
            priority = 61;
            disable = ["seen" "seen_info_hash"]; # Don't check seen database for cleanup
            from_transmission = {
              host = "https://transmission.hummingbird-lake.ts.net";
              port = 443;
              only_complete = false;
            };
            "if" = [
              # Stalled: 0% progress after 24 hours
              {"transmission_progress == 0 and transmission_date_added < now - timedelta(hours=24)" = "accept";}
              # Dead: no seeders for 3+ days
              {"transmission_seeders == 0 and transmission_date_added < now - timedelta(days=3)" = "accept";}
            ];
            # Remember this release failed so we don't try it again
            remember_rejected = {
              retry_time = "7 days";
            };
            # Remove from downloaded list so movie can be re-discovered
            list_remove = [{movie_list = "downloaded-movies";}];
            transmission = {
              host = "https://transmission.hummingbird-lake.ts.net";
              port = 443;
              action = "purge"; # Delete torrent AND incomplete files
            };
          };
        };

        schedules = [
          {
            tasks = ["sync-comics-watchlist"];
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
            tasks = ["download-comics" "download-comics-torrent"];
            interval.hours = 2;
          }
          {
            tasks = ["sort-series" "sort-movies"];
            interval.minutes = 15;
          }
          {
            tasks = ["clean-completed" "clean-stalled"];
            interval.hours = 4;
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

    # Immich photo/video backup and management
    immich = {
      enable = true;
      user = "media";
      group = "media";
      mediaLocation = "/var/lib/immich"; # NVMe: thumbs, transcodes, uploads
      proxy = {
        enable = true;
        name = "photos";
      };

      # Store original photos on 30T mergerfs, separated by user
      environment = {
        IMMICH_LIBRARY_LOCATION = "/tundra/merged/iceberg/photos/library/{{user}}";
      };

      # Machine learning for face detection, object recognition, smart search
      machineLearning = {
        enable = true;
        # cuda.enable = true; # Use NVIDIA GPU for ML inference
      };

      # Immich settings optimized for zao hardware (i9-11900H, RTX 3060, 32GB RAM)
      settings = {
        # File organization by year/date
        storageTemplate = {
          enabled = true;
          template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
        };

        # Video transcoding with NVIDIA NVENC
        ffmpeg = {
          accel = "nvenc";
          accelDecode = true;
          targetVideoCodec = "hevc";
          preset = "quality";
          crf = 23;
        };

        # Higher concurrency for 8-core CPU
        job = {
          thumbnailGeneration.concurrency = 5;
          metadataExtraction.concurrency = 8;
          faceDetection.concurrency = 4;
          videoConversion.concurrency = 2;
        };

        # Larger previews for high-res displays
        image = {
          preview.size = 2160;
          thumbnail.quality = 90;
        };

        # Extended trash retention
        trash.days = 60;
      };

      # Hardware acceleration: NVIDIA primary, Intel VAAPI fallback
      hardware.acceleration = {
        enable = true;
        devices = [
          "/dev/nvidia0"
          "/dev/nvidiactl"
          "/dev/nvidia-modeset"
          "/dev/dri/renderD128" # Intel VAAPI fallback
        ];
      };
    };

    # Jellyfin media server (no VPN - needs direct access for streaming)
    jellyfin = {
      enable = true;
      proxy = {
        enable = true;
        name = "watch";
      };

      # Hardware acceleration for transcoding
      # Uses both Intel QuickSync (VAAPI) and NVIDIA for flexible transcoding
      hardware = {
        vaapi = {
          enable = true; # Intel QuickSync
          enableGuC = true; # Better QuickSync performance via GuC
        };
        nvidia.enable = true; # NVIDIA NVENC
      };

      # Performance optimizations
      performance = {
        # Use tmpfs for transcoding to reduce SSD writes
        transcodeTmpfs = {
          enable = true;
          size = "8G"; # Generous size for 4K transcoding
        };

        # FFmpeg probe settings for large media files
        ffmpegProbe = {
          probeSize = "100M";
          analyzeDuration = "200M";
        };

        # Service resource limits
        serviceHardening = {
          enable = true;
          memoryMax = "12G"; # Higher limit for 4K transcoding
          memoryHigh = "8G";
        };
      };

      # Plugins configuration
      plugins = {
        # Auto-skip TV show intros and credits
        introSkipper = {
          enable = true;
          autoSkip = true;
        };

        # Trakt.tv integration for watch history sync
        trakt = {
          enable = true;
          syncMode = "two-way";
        };

        # Auto-download subtitles in English and French
        openSubtitles = {
          enable = true;
          languages = ["eng" "fre"];
        };

        # Merge multiple versions (4K + 1080p) into single item
        mergeVersions.enable = true;

        # Enhanced metadata providers
        fanartTv.enable = true;
        omdb.enable = true;
      };
    };
  };

  # Kokoro TTS server (used by OpenReader for text-to-speech)
  mountainous.kokoro-tts = {
    enable = true;
    # cuda = true; # Use RTX 3060 for GPU acceleration
  };

  # OpenReader e-book reader with TTS
  mountainous.openreader = {
    enable = true;
    port = 3004; # 3003 is used by Immich ML
    ttsEndpoint = "http://localhost:8880/v1"; # Kokoro endpoint
    stateDir = "/var/lib/openreader";
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

    services.openreader = {
      hostname = "reader";
      protocol = "http";
      port = 3004;
    };

    services.kokoro-tts = {
      hostname = "tts";
      protocol = "http";
      port = 8880;
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
