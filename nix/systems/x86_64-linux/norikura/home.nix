# GPD Pocket 1 - Home Manager configuration
#
# Workstation-focused setup for portable development
# Display: 1920x1200 rotated to landscape (portrait panel)
#
{
  pkgs,
  inputs,
  ...
}: {
  # === MPV overrides for weak Atom CPU ===
  # Hardware decoding is essential - software decode can't keep up
  programs.mpv = {
    config = {
      # Hardware decoding (VA-API for Intel Cherry Trail)
      hwdec = "vaapi";
      vo = "gpu";
      gpu-context = "wayland";

      # yt-dlp format - Cherry Trail has NO AV1/VP9 hw decode
      ytdl-format = "bestvideo[height<=1080][vcodec^=avc1]+bestaudio/best[height<=1080]";

      # Performance optimizations for weak GPU
      profile = "fast";
      scale = "bilinear";
      cscale = "bilinear";
      dscale = "bilinear";
      dither-depth = "no";

      # Reduce frame drops
      framedrop = "vo";
      video-sync = "audio";

      # Lower cache for limited RAM
      demuxer-max-bytes = "50M";
      demuxer-max-back-bytes = "25M";

      # Disable expensive features
      deband = "no";
      interpolation = "no";
    };

    scripts = with pkgs.mpvScripts; [
      quality-menu
    ];
  };

  # === yt-dlp Configuration ===
  # Prefer formats the Atom can actually decode
  programs.yt-dlp = {
    enable = true;
    settings = {
      # Prefer h264 (better hw decode support) over VP9/AV1
      format = "bestvideo[height<=1080][vcodec^=avc1]+bestaudio/best[height<=1080]";

      # Merge to mkv for compatibility
      merge-output-format = "mkv";

      # Use cookies from browser for age-restricted content
      cookies-from-browser = "firefox";
    };
  };
  # Remote dictation via aka (Atom CPU too slow for local whisper)
  mountainous.dictation = {
    enable = true;
    remoteHost = "aka";
  };

  # GPD Pocket 1 Hyprland configuration
  mountainous.hyprland = {
    enable = true;

    # Touch gesture plugin for touchscreen
    plugins = [
      inputs.hyprgrass.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    extraSettings = {
      # 7" DSI display 1200x1920 native (portrait), rotate 90° for landscape
      # Transform 1 = 90° clockwise rotation
      monitor = [
        "DSI-1, 1200x1920@60, 0x0, 1.5, transform, 3"
      ];

      exec-once = [
        "systemctl --user start hyprland-session.target"
        "waybar"
      ];

      # Touchscreen rotation (270° to match display transform 3)
      "input:touchdevice:transform" = 3;

      # Smaller gaps for 7" display
      general = {
        gaps_in = 2;
        gaps_out = 4;
      };

      # === PERFORMANCE OPTIMIZATIONS for Atom CPU ===

      # Disable blur (very GPU intensive)
      decoration = {
        blur = {
          enabled = false;
        };
        shadow = {
          enabled = false;
        };
        rounding = 0; # Square corners are faster
      };

      # Disable all animations for performance
      animations = {
        enabled = false;
      };

      # Misc performance settings
      misc = {
        vfr = true; # Variable frame rate - reduces GPU work when idle
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      # Render performance
      render = {
        direct_scanout = 2; # Auto - enables for fullscreen apps
      };
    };
  };

  programs.git.settings = {
    init.defaultBranch = "main";
  };

  programs.direnv.enable = true;

  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 24;
        modules-center = ["hyprland/workspaces"];
        modules-right = ["battery" "clock"];
        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
            active = "●";
            default = "○";
          };
          on-click = "activate";
        };
        battery = {
          format = "{capacity}%";
        };
        clock = {
          format = "{:%H:%M}";
        };
      };
    };
    style = ''
      * {
        font-family: monospace;
        font-size: 12px;
      }
      window#waybar {
        background: rgba(0, 0, 0, 1);
        color: #cdd6f4;
      }
      #workspaces button {
        padding: 0 6px;
        color: #6c7086;
        background: transparent;
        border: none;
      }
      #workspaces button.active {
        color: #cdd6f4;
      }
      #battery, #clock {
        padding: 0 8px;
      }
    '';
  };

  programs.kitty.settings = {
    font_size = 10;
  };

  home.packages = with pkgs; [
    neovim
    git
    lazygit
    htop
    btop
    mtr
    yazi
    fzf
    ripgrep
    fd
    brightnessctl
    wvkbd
    wtype
    foot
    acpi
    powertop
  ];

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    documents = "$HOME/Documents";
    download = "$HOME/Downloads";
    pictures = "$HOME/Pictures";
    videos = "$HOME/Videos";
    music = "$HOME/Music";
  };
}
