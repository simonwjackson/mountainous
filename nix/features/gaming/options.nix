{lib}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  enable = mkEnableOption "Gaming support with Steam and optimized audio";

  # NOTE: Device type is now defined at mountainous.device.role and mountainous.device.traits
  # This feature reads from config.mountainous.device instead of having its own deviceType

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

    monitors = {
      primary = mkOption {
        type = types.str;
        default = "DP-1";
        description = "Primary monitor name for gaming";
      };
      virtual = mkOption {
        type = types.str;
        default = "HDMI-A-2";
        description = "Virtual/streaming monitor name";
      };
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
          "x-systemd.automount"
          "noauto"
          "x-systemd.idle-timeout=600"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
          "soft"
          "timeo=14"
          "nfsvers=4"
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
          "x-systemd.automount"
          "noauto"
          "x-systemd.idle-timeout=600"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
          "soft"
          "timeo=10"
          "retrans=2"
          "nfsvers=4"
          "_netdev"
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
