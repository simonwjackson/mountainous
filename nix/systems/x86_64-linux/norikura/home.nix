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

      # Faster animations (or disable with enabled = false)
      animations = {
        enabled = true;
        # Quick, simple animations
        animation = [
          "global, 1, 2, default"
          "windows, 1, 2, default"
          "fade, 1, 2, default"
          "workspaces, 1, 2, default, slide"
        ];
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
