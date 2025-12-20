{lib}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  enable = mkEnableOption "Gaming support with Steam and optimized audio";

  citron = {
    enable = mkEnableOption "Citron Nintendo Switch emulator";

    keys = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to Switch prod keys directory (containing prod.keys and title.keys).
        When set, keys are automatically copied to ~/.local/share/citron/keys/
        on home-manager activation. Keys are re-copied when the input changes.
        Typically passed as a flake input: inputs.switch-prod-keys
      '';
      example = "inputs.switch-prod-keys";
    };

    savePath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Path to shared Nintendo Switch NAND directory (containing system/ and user/ subdirectories).
        When set, ~/.local/share/citron/nand is symlinked to this path.
        This allows saves and user profile (UUID) to be shared across multiple machines.
        Per-machine settings (graphics, controller, etc.) remain in ~/.config/citron/qt-config.ini.
        (null = don't manage, use Citron's default location)
      '';
      example = "/snowscape/gaming/profiles/simonwjackson/progress/saves/nintendo-switch";
    };

    # Game directories - appended to existing config
    gameDirectories = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Directories containing Switch game files (.nsp, .xci). Appended to existing game directories.";
      example = ["/snowscape/gaming/games/nintendo-switch"];
    };

    # Graphics settings
    graphics = {
      backend = mkOption {
        type = types.nullOr (types.enum ["opengl" "vulkan"]);
        default = null;
        description = "Graphics backend (null = don't manage)";
      };

      resolution = mkOption {
        type = types.nullOr types.number;
        default = null;
        description = ''
          Resolution multiplier. Native Switch is 720p/1080p.
          Valid values: 0.5, 0.75, 1, 1.5, 2, 3, 4, 5, 6, 7, 8
          (null = don't manage)
        '';
        example = 2;
      };

      vsync = mkOption {
        type = types.nullOr (types.enum ["off" "fifo" "mailbox"]);
        default = null;
        description = "VSync mode: off, fifo (tear-free), mailbox (low latency). (null = don't manage)";
      };

      fullscreenMode = mkOption {
        type = types.nullOr (types.enum ["borderless" "exclusive"]);
        default = null;
        description = "Fullscreen mode when fullscreen is enabled. (null = don't manage)";
      };

      scalingFilter = mkOption {
        type = types.nullOr (types.enum ["nearest" "bilinear" "bicubic" "lanczos" "gaussian" "scaleforce" "scalefx" "fsr" "fsr2"]);
        default = null;
        description = "Scaling filter for upscaling. (null = don't manage)";
      };

      gpuAccuracy = mkOption {
        type = types.nullOr (types.enum ["normal" "high" "extreme"]);
        default = null;
        description = "GPU emulation accuracy. Higher = more accurate but slower. (null = don't manage)";
      };

      asyncShaders = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Compile shaders asynchronously. May cause stutter while building cache. (null = don't manage)";
      };

      diskShaderCache = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Cache compiled shaders to disk. (null = don't manage)";
      };

      antiAliasing = mkOption {
        type = types.nullOr (types.enum ["none" "fxaa" "smaa" "taa"]);
        default = null;
        description = "Anti-aliasing method. (null = don't manage)";
      };

      fsrSharpness = mkOption {
        type = types.nullOr (types.ints.between 0 100);
        default = null;
        description = "FSR sharpening slider 0-100. Higher = sharper. (null = don't manage)";
      };
    };

    # System settings
    system = {
      dockedMode = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Docked mode (1080p) vs handheld mode (720p). (null = don't manage)";
      };

      language = mkOption {
        type = types.nullOr (types.enum [
          "japanese"
          "english"
          "french"
          "german"
          "italian"
          "spanish"
          "chinese"
          "korean"
          "dutch"
          "portuguese"
          "russian"
          "taiwanese"
          "british-english"
        ]);
        default = null;
        description = "System language. (null = don't manage)";
      };

      region = mkOption {
        type = types.nullOr (types.enum ["japan" "usa" "europe" "australia" "china" "korea" "taiwan"]);
        default = null;
        description = "System region. (null = don't manage)";
      };
    };

    # Performance settings
    performance = {
      multicore = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Enable multi-core CPU emulation. (null = don't manage)";
      };

      speedLimit = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Speed limit percentage (0 = unlimited, 100 = normal). (null = don't manage)";
        example = 100;
      };
    };

    # Audio settings
    audio = {
      volume = mkOption {
        type = types.nullOr (types.ints.between 0 100);
        default = null;
        description = "Audio volume percentage 0-100. (null = don't manage)";
      };

      muteInBackground = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Mute audio when Citron is in background. (null = don't manage)";
      };
    };

    # UI settings
    ui = {
      fullscreen = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Start in fullscreen mode. (null = don't manage)";
      };

      confirmStop = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Ask for confirmation when stopping emulation. (null = don't manage)";
      };

      pauseInBackground = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Pause emulation when Citron is in background. (null = don't manage)";
      };

      theme = mkOption {
        type = types.nullOr (types.enum [
          "default"
          "colorful"
          "colorful_dark"
          "colorful_midnight_blue"
          "qdarkstyle"
          "qdarkstyle_midnight_blue"
        ]);
        default = null;
        description = "UI theme. (null = don't manage)";
      };
    };

    # Controller settings
    controls = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = ''
        Controller mappings for player inputs.
        Keys are the INI keys (e.g., "player_0_button_a", "player_0_lstick").
        Values are the binding strings (e.g., "pad:0,button:1,port:0,guid:...,engine:sdl").
        These are written directly to the [Controls] section of qt-config.ini.
      '';
      example = {
        "player_0_type" = "0";
        "player_0_connected" = "true";
        "player_0_button_a" = "pad:0,button:1,port:0,guid:030000005e040000ea02000008040000,engine:sdl";
      };
    };
  };

  # NOTE: Device type is now defined at mountainous.device.role and mountainous.device.traits
  # This feature reads from config.mountainous.device instead of having its own deviceType

  rpcs3 = {
    enable = mkEnableOption "RPCS3 PS3 emulator";
  };

  streaming = {
    enable = mkEnableOption "Sunshine game streaming server";

    encoder = mkOption {
      type = types.enum ["auto" "nvenc" "vaapi" "software"];
      default = "auto";
      description = ''
        Video encoder to use for streaming.
        - auto: Let Sunshine auto-detect the best encoder
        - nvenc: Force NVIDIA NVENC (requires NVIDIA GPU)
        - vaapi: Force VA-API (Intel/AMD)
        - software: Force CPU encoding (libx264)
      '';
    };

    capture = mkOption {
      type = types.enum ["auto" "kms" "wlr" "x11"];
      default = "auto";
      description = ''
        Screen capture method.
        - auto: Let Sunshine auto-detect
        - kms: DRM/KMS capture (requires cap_sys_admin)
        - wlr: Wayland wlroots protocol
        - x11: X11 capture
      '';
    };

    monitor = mkOption {
      type = types.str;
      description = "Monitor name for hyprctl commands (e.g., 'HDMI-A-2')";
      example = "HDMI-A-2";
    };

    monitorIndex = mkOption {
      type = types.int;
      description = "Monitor index for Sunshine output_name (check Sunshine logs for 'Monitor N is ...')";
      example = 1;
    };

    adapter = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        GPU adapter name for Sunshine. Forces encoding on specific GPU.
        Use "ls /dev/dri/" to list available render devices.
        Common values: "/dev/dri/renderD128" (usually dGPU), "/dev/dri/renderD129" (usually iGPU).
        null = auto-detect (may pick wrong GPU on multi-GPU systems).
      '';
      example = "/dev/dri/renderD128";
    };

    disableOtherMonitors = mkEnableOption "Turn off (DPMS) non-streaming monitors during session";

    profiles = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Display name for this profile in Sunshine UI";
            example = "4K 60";
          };
          resolution = mkOption {
            type = types.str;
            description = "Resolution (e.g., '3840x2160')";
            example = "3840x2160";
          };
          refresh = mkOption {
            type = types.int;
            default = 60;
            description = "Refresh rate in Hz";
          };
          scaling = mkOption {
            type = types.number;
            default = 1;
            description = "Display scaling factor";
          };
        };
      });
      default = [];
      description = "Display profiles for different streaming devices";
      example = [
        {
          name = "4K 60";
          resolution = "3840x2160";
          refresh = 60;
          scaling = 1;
        }
        {
          name = "FHD 120";
          resolution = "1920x1080";
          refresh = 120;
          scaling = 1;
        }
      ];
    };

    applications = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "Additional Sunshine applications";
    };

    # Advanced encoder settings
    nvenc = {
      preset = mkOption {
        type = types.enum ["default" "hp" "hq" "ll" "llhp" "llhq" "lossless" "losslesshp"];
        default = "default";
        description = ''
          NVENC encoding preset:
          - default: Balanced quality/performance
          - hp: High performance (fastest)
          - hq: High quality
          - ll: Low latency
          - llhp: Low latency high performance
          - llhq: Low latency high quality
          - lossless/losslesshp: Lossless encoding
        '';
      };

      rateControl = mkOption {
        type = types.enum ["auto" "cqp" "vbr" "cbr"];
        default = "auto";
        description = "Rate control mode for NVENC";
      };

      twoPass = mkOption {
        type = types.bool;
        default = false;
        description = "Enable two-pass encoding for better quality (higher latency)";
      };
    };
  };

  gamepadProxy = {
    enable = mkEnableOption "Virtual gamepad proxy service";
  };

  steamButton = {
    enable = mkEnableOption "Steam button handler for quick Steam/gaming access";

    keybind = mkOption {
      type = types.str;
      default = "SUPER, G";
      description = "Hyprland keybind to trigger Steam button (e.g., 'SUPER, G' or ', XF86Launch6')";
    };

    workspace = mkOption {
      type = types.int;
      default = 10;
      description = "Workspace number for games";
    };

    useSpecialWorkspace = mkOption {
      type = types.bool;
      default = true;
      description = "Put Steam in a special workspace overlay (true) or regular workspace (false)";
    };

    specialWorkspace = mkOption {
      type = types.str;
      default = "gaming";
      description = "Name of the special workspace for Steam overlay (only used when useSpecialWorkspace = true)";
    };
  };

  steamPrefs = {
    enable = mkEnableOption "Declarative Steam preferences management";

    steamId = mkOption {
      type = types.str;
      default = "";
      description = "Steam user ID (numeric, found in ~/.steam/steam/userdata/<ID>)";
      example = "12345678";
    };

    friends = {
      autoSignIn = mkOption {
        type = types.enum ["online" "offline"];
        default = "offline";
        description = "Auto sign-in behavior for Steam Friends";
      };

      notifications = {
        showIngame = mkOption {
          type = types.bool;
          default = false;
          description = "Show friend notifications while in-game";
        };
        showOnline = mkOption {
          type = types.bool;
          default = false;
          description = "Show notifications when friends come online";
        };
        showMessage = mkOption {
          type = types.bool;
          default = false;
          description = "Show notifications for new messages";
        };
      };

      sounds = {
        playIngame = mkOption {
          type = types.bool;
          default = false;
          description = "Play sounds for events while in-game";
        };
        playOnline = mkOption {
          type = types.bool;
          default = false;
          description = "Play sounds when friends come online";
        };
        playMessage = mkOption {
          type = types.bool;
          default = false;
          description = "Play sounds for new messages";
        };
      };
    };

    reapplyOnSteamExit = mkOption {
      type = types.bool;
      default = true;
      description = "Watch for Steam exit and re-apply preferences";
    };

    remotePlay = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Steam Remote Play (game streaming to other devices)";
      };
    };

    compatibility = {
      defaultTool = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Default Proton/compatibility tool for all games.
          Common values: "proton_37" (Proton 9), "GE-Proton", "proton_experimental"
          Set to null to not manage this setting.
        '';
        example = "GE-Proton";
      };
    };

    shaderCache = {
      enablePreCaching = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Enable shader pre-caching (downloads pre-compiled shaders from Valve).
          With Mesa 23.1+ and GPL support, this is often unnecessary for AMD/Intel GPUs.
          Set to null to not manage this setting.
        '';
      };

      enableBackgroundProcessing = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Allow background processing of Vulkan shaders.
          When enabled, Steam compiles downloaded shaders in the background.
          Set to null to not manage this setting.
        '';
      };
    };

    controller = {
      guideButtonFocusesSteam = mkOption {
        type = types.bool;
        default = false;
        description = "Whether pressing the controller guide/Xbox button focuses Steam";
      };
    };
  };

  performance = {
    lowLatencyAudio = mkOption {
      type = types.bool;
      default = true;
      description = "Enable low-latency audio for gaming";
    };

    gamemode = mkOption {
      type = types.bool;
      default = true;
      description = "Enable gamemode performance optimizer";
    };
  };

  library = {
    remote = {
      enable = mkEnableOption "Mount remote Steam library via NFS";

      server = mkOption {
        type = types.str;
        default = "";
        description = "NFS server hostname (e.g., Tailscale DNS name)";
        example = "aka";
      };

      remotePath = mkOption {
        type = types.str;
        default = "/home/simonwjackson/.local/share/Steam";
        description = "Path to Steam directory on remote server";
      };

      mountPoint = mkOption {
        type = types.str;
        default = "/tundra/avalanche/steam";
        description = "Local mount point for remote Steam library";
      };

      user = mkOption {
        type = types.str;
        default = "simonwjackson";
        description = "User that owns local Steam data";
      };

      localCompatdataPath = mkOption {
        type = types.str;
        default = "/home/simonwjackson/.local/share/Steam/steamapps/compatdata";
        description = "Local path for Proton compatibility data (kept local per machine)";
      };

      localShadercachePath = mkOption {
        type = types.str;
        default = "/home/simonwjackson/.local/share/Steam/steamapps/shadercache";
        description = "Local path for shader cache (kept local per machine)";
      };

      nfsOptions = mkOption {
        type = types.listOf types.str;
        default = [
          "nofail" # Don't fail boot/switch if unavailable
          "_netdev" # This is a network mount
          "x-systemd.automount" # Only mount on access
          "noauto"
          "x-systemd.idle-timeout=600"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
          "x-systemd.requires=tailscaled.service" # Wait for Tailscale
          "soft"
          "timeo=14"
          "nfsvers=4"
          "nocto" # Skip close-to-open checks for better read performance (safe for single-client)
          "async" # Async I/O for better throughput
        ];
        description = "NFS mount options";
      };
    };

    hybrid = {
      enable = mkEnableOption "Unified Steam library with local priority via MergerFS";

      server = mkOption {
        type = types.str;
        default = "";
        description = "NFS server hostname for remote Steam library";
        example = "aka";
      };

      remotePath = mkOption {
        type = types.str;
        default = "/home/simonwjackson/.local/share/Steam";
        description = "Path to Steam directory on remote server";
      };

      nfsMountPoint = mkOption {
        type = types.str;
        default = "/tundra/avalanche/steam";
        description = "Mount point for NFS remote Steam library";
      };

      localPath = mkOption {
        type = types.str;
        default = "/tundra/glacier/steam";
        description = "Local Steam storage (priority over network)";
      };

      mergedPath = mkOption {
        type = types.str;
        default = "/tundra/merged/steam";
        description = "Unified merged view for Steam to use";
      };

      user = mkOption {
        type = types.str;
        default = "simonwjackson";
        description = "User that owns Steam data";
      };

      uid = mkOption {
        type = types.int;
        default = 333;
        description = "UID for file ownership";
      };

      gid = mkOption {
        type = types.int;
        default = 333;
        description = "GID for file ownership";
      };

      nfsOptions = mkOption {
        type = types.listOf types.str;
        default = [
          "nofail" # Don't fail boot/switch if unavailable
          "_netdev" # This is a network mount
          "x-systemd.automount" # Only mount on access
          "noauto"
          "x-systemd.idle-timeout=600"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
          "x-systemd.requires=tailscaled.service" # Wait for Tailscale
          "soft"
          "timeo=10"
          "retrans=2"
          "nfsvers=4"
          "nocto" # Skip close-to-open checks for better read performance (safe for single-client)
          "async" # Async I/O for better throughput
        ];
        description = "NFS mount options for graceful network handling";
      };

      mergerfsOptions = mkOption {
        type = types.listOf types.str;
        default = [
          "defaults"
          "allow_other"
          "use_ino"
          "category.create=ff"
          "category.search=ff"
          "category.action=ff"
          "moveonenospc=true"
          "dropcacheonclose=true"
          "cache.files=auto-full"
          "branches-mount-timeout=5"
          "fsname=steam-merged"
        ];
        description = "MergerFS mount options for local-priority union";
      };
    };
  };

  home = {
    autoLaunch = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["steam" "moonlight"];
      description = "Applications to auto-launch on login (requires Hyprland)";
    };

    keybinds = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = {"SUPER, F1" = "exec, steam";};
      description = "Gaming-specific keybinds for Hyprland";
    };

    overlay = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable MangoHUD performance overlay";
      };
    };
  };
}
