{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge mkDefault types;
  cfg = config.mountainous.media.jellyfin;
  mediaCfg = config.mountainous.media;

  # Module-internal path requirements
  requiredPaths = ["movies" "series"];

  # Plugin repository URLs for third-party plugins
  pluginRepos = {
    introSkipper = "https://raw.githubusercontent.com/intro-skipper/intro-skipper/master/manifest.json";
  };
in {
  options.mountainous.media.jellyfin = {
    enable = mkEnableOption "Jellyfin media server";

    user = mkOption {
      type = types.str;
      default = "jellyfin";
      description = "User to run Jellyfin as";
    };

    group = mkOption {
      type = types.str;
      default = "jellyfin";
      description = "Group to run Jellyfin as";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/jellyfin";
      description = "Directory for Jellyfin data, config, and cache";
    };

    cacheDir = mkOption {
      type = types.path;
      default = "/var/lib/jellyfin/cache";
      description = "Directory for Jellyfin cache (default within dataDir to avoid storage issues)";
    };

    port = mkOption {
      type = types.port;
      default = 8096;
      description = "HTTP port for Jellyfin web interface";
    };

    httpsPort = mkOption {
      type = types.port;
      default = 8920;
      description = "HTTPS port for Jellyfin web interface";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall ports for Jellyfin";
    };

    proxy = {
      enable = mkEnableOption "Tailscale proxy for Jellyfin web UI";

      name = mkOption {
        type = types.str;
        default = "jellyfin";
        description = "Tailscale hostname";
      };
    };

    hardware = {
      vaapi = {
        enable = mkEnableOption "Intel VAAPI hardware acceleration";
        device = mkOption {
          type = types.str;
          default = "/dev/dri/renderD128";
          description = "VAAPI render device";
        };
        enableGuC = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Intel GuC for better QuickSync performance";
        };
      };

      nvidia = {
        enable = mkEnableOption "NVIDIA hardware acceleration";
      };
    };

    performance = {
      transcodeTmpfs = {
        enable = mkEnableOption "Use tmpfs for transcoding temp files (reduces SSD writes)";
        size = mkOption {
          type = types.str;
          default = "4G";
          description = "Size of tmpfs for transcoding (e.g., 4G, 8G)";
        };
      };

      ffmpegProbe = {
        probeSize = mkOption {
          type = types.str;
          default = "100M";
          description = "FFmpeg probe size for better codec detection";
        };
        analyzeDuration = mkOption {
          type = types.str;
          default = "200M";
          description = "FFmpeg analyze duration for better stream analysis";
        };
      };

      serviceHardening = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable service resource limits and hardening";
        };
        memoryMax = mkOption {
          type = types.str;
          default = "8G";
          description = "Maximum memory for Jellyfin service";
        };
        memoryHigh = mkOption {
          type = types.str;
          default = "6G";
          description = "Memory high watermark for Jellyfin service";
        };
      };
    };

    plugins = {
      introSkipper = {
        enable = mkEnableOption "Intro Skipper plugin for auto-skipping TV intros";
        autoSkip = mkOption {
          type = types.bool;
          default = true;
          description = "Automatically skip intros without prompting";
        };
      };

      trakt = {
        enable = mkEnableOption "Trakt.tv sync plugin";
        syncMode = mkOption {
          type = types.enum ["two-way" "to-trakt" "from-trakt"];
          default = "two-way";
          description = "Sync direction: two-way, to-trakt only, or from-trakt only";
        };
      };

      openSubtitles = {
        enable = mkEnableOption "OpenSubtitles plugin for auto-downloading subtitles";
        languages = mkOption {
          type = types.listOf types.str;
          default = ["eng"];
          description = "Subtitle languages to download (ISO 639-2 codes)";
          example = ["eng" "fre"];
        };
      };

      mergeVersions = {
        enable = mkEnableOption "Merge Versions plugin for multi-version content";
      };

      fanartTv = {
        enable = mkEnableOption "Fanart.tv metadata provider for enhanced artwork";
      };

      omdb = {
        enable = mkEnableOption "OMDb metadata provider for additional details";
        apiKeyFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to file containing OMDb API key";
        };
      };
    };

    libraries = {
      movies = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Create Movies library from media paths";
        };
        name = mkOption {
          type = types.str;
          default = "Movies";
          description = "Display name for the movies library";
        };
      };

      series = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Create TV Shows library from media paths";
        };
        name = mkOption {
          type = types.str;
          default = "TV Shows";
          description = "Display name for the TV shows library";
        };
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Validation: error if required paths not defined
      assertions =
        map (path: {
          assertion = mediaCfg.paths ? ${path};
          message = "mountainous.media.jellyfin requires mountainous.media.paths.${path} to be defined";
        })
        requiredPaths;

      # Declaratively create Jellyfin directories
      mountainous.directories.paths = {
        "${cfg.dataDir}" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
        "${cfg.dataDir}/config" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
        "${cfg.dataDir}/data" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
        "${cfg.cacheDir}" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
        "${cfg.dataDir}/log" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
      };

      # Enable Jellyfin service
      services.jellyfin = {
        enable = true;
        inherit (cfg) user group dataDir cacheDir openFirewall;
      };

      # Allow Jellyfin user to access media paths
      users.users.${cfg.user}.extraGroups =
        lib.optional (mediaCfg.group != cfg.group) mediaCfg.group;

      # Firewall configuration
      networking.firewall = mkIf cfg.openFirewall {
        allowedTCPPorts = [cfg.port cfg.httpsPort];
        # Jellyfin discovery
        allowedUDPPorts = [1900 7359];
      };

      # Impermanence integration - persist Jellyfin data
      environment.persistence."${config.mountainous.impermanence.persistPath}" =
        mkIf (config.mountainous.impermanence.enable or false)
        {
          directories = [
            {
              inherit (cfg) user group;
              directory = cfg.dataDir;
              mode = "0750";
            }
          ];
        };
    }

    # Intel VAAPI hardware acceleration
    (mkIf cfg.hardware.vaapi.enable {
      # Ensure jellyfin user can access render device
      users.users.${cfg.user}.extraGroups = ["render" "video"];

      # Add VAAPI drivers and FFmpeg probe settings to Jellyfin environment
      systemd.services.jellyfin.environment = {
        LIBVA_DRIVER_NAME = "iHD"; # Intel Media Driver
        # FFmpeg probe settings for large media files
        JELLYFIN_FFmpeg__probesize = cfg.performance.ffmpegProbe.probeSize;
        JELLYFIN_FFmpeg__analyzeduration = cfg.performance.ffmpegProbe.analyzeDuration;
      };

      # Ensure graphics packages are available
      hardware.graphics.enable = true;
      hardware.graphics.extraPackages = with pkgs; [
        intel-media-driver # VAAPI driver
        intel-compute-runtime # OpenCL for HDR tone mapping
        vpl-gpu-rt # Intel Video Processing Library (modern replacement for intel-media-sdk)
      ];

      # Enable GuC for better QuickSync performance
      boot.kernelParams = lib.mkIf cfg.hardware.vaapi.enableGuC [
        "i915.enable_guc=3"
      ];
    })

    # NVIDIA hardware acceleration
    (mkIf cfg.hardware.nvidia.enable {
      # Ensure jellyfin user can access NVIDIA devices
      users.users.${cfg.user}.extraGroups = ["video"];

      # Enable NVIDIA container support for hardware encoding
      hardware.nvidia-container-toolkit.enable = true;

      # Add NVIDIA libraries to Jellyfin environment
      systemd.services.jellyfin = {
        environment = {
          NVIDIA_VISIBLE_DEVICES = "all";
          NVIDIA_DRIVER_CAPABILITIES = "compute,video,utility";
        };
        # Ensure NVIDIA modules are loaded
        after = ["nvidia-persistenced.service"];
      };
    })

    # Tailscale proxy for remote access
    (mkIf cfg.proxy.enable {
      mountainous.tsnet-proxy.services.jellyfin = {
        hostname = cfg.proxy.name;
        protocol = "http";
        port = cfg.port;
      };
    })

    # Generate plugin repositories configuration
    (mkIf (cfg.plugins.introSkipper.enable) {
      # Create plugin repositories file via a separate oneshot service
      # This runs as the jellyfin user to avoid permission issues
      systemd.services.jellyfin-intro-skipper-repo = {
        description = "Configure Intro Skipper plugin repository for Jellyfin";
        wantedBy = ["jellyfin.service"];
        before = ["jellyfin.service"];
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.group;
          RemainAfterExit = true;
        };
        script = ''
          # Ensure config directory exists
          mkdir -p ${cfg.dataDir}/config

          # Add Intro Skipper repository if not already present
          REPOS_FILE="${cfg.dataDir}/config/repositories.json"
          if [ ! -f "$REPOS_FILE" ]; then
            echo '[]' > "$REPOS_FILE"
          fi

          # Check if intro-skipper repo already exists
          if ! ${pkgs.jq}/bin/jq -e '.[] | select(.Url == "${pluginRepos.introSkipper}")' "$REPOS_FILE" > /dev/null 2>&1; then
            ${pkgs.jq}/bin/jq '. + [{"Name": "Intro Skipper", "Url": "${pluginRepos.introSkipper}"}]' "$REPOS_FILE" > "$REPOS_FILE.tmp"
            mv "$REPOS_FILE.tmp" "$REPOS_FILE"
          fi
        '';
      };
    })

    # Tmpfs for transcoding temp files (reduces SSD writes)
    (mkIf cfg.performance.transcodeTmpfs.enable {
      fileSystems."${cfg.dataDir}/transcodes" = {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [
          "size=${cfg.performance.transcodeTmpfs.size}"
          "mode=0750"
          "uid=${cfg.user}"
          "gid=${cfg.group}"
        ];
      };
    })

    # Service hardening and resource limits
    (mkIf cfg.performance.serviceHardening.enable {
      systemd.services.jellyfin.serviceConfig = {
        # Memory limits
        MemoryMax = cfg.performance.serviceHardening.memoryMax;
        MemoryHigh = cfg.performance.serviceHardening.memoryHigh;

        # Nice level for media server (slightly lower priority than system tasks)
        Nice = 5;

        # IO priority (best-effort, mid-priority)
        IOSchedulingClass = "best-effort";
        IOSchedulingPriority = 4;

        # Watchdog and restart behavior
        WatchdogSec = "60s";
        Restart = mkDefault "on-failure";
        RestartSec = mkDefault "10s";
      };
    })
  ]);
}
