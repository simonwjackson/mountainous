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
      # 7" IPS 1920x1200 display (portrait-native, rotate 90° for landscape)
      monitor = [
        "eDP-1, 1920x1200@60, 0x0, 1, transform, 1"
      ];

      exec-once = [
        "systemctl --user start hyprland-session.target"
        "waybar"
      ];

      input = {
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
          tap-and-drag = true;
          disable_while_typing = false; # Important for small keyboard
        };

        # Sensitivity for small trackpoint
        sensitivity = 0.3;
      };

      # Touchscreen rotation (90° to match display transform)
      "input:touchdevice:transform" = 1;

      # Touch gestures for small screen
      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
        workspace_swipe_distance = 200;
        workspace_swipe_min_speed_to_force = 20;
      };

      # hyprgrass touch gesture config
      "plugin:touch_gestures:sensitivity" = 4.0;
      "plugin:touch_gestures:workspace_swipe_fingers" = 3;
      "plugin:touch_gestures:edge_margin" = 30;
      "plugin:touch_gestures:long_press_delay" = 200;

      # Touch gesture bindings (mouse-like actions)
      "hyprgrass-bindm" = [
        ", longpress:2, movewindow"
        ", longpress:3, resizewindow"
      ];

      # Touch gesture bindings
      "hyprgrass-bind" = [
        # 3-finger workspace switching
        ", swipe:3:l, workspace, e+1"
        ", swipe:3:r, workspace, e-1"

        # 4-finger gestures
        ", swipe:4:u, fullscreen, 1"
        ", swipe:4:d, togglefloating"

        # Edge swipes - left edge: special workspace
        ", edge:l:r, togglespecialworkspace, magic"

        # Edge swipes - right edge: brightness
        ", edge:r:u, exec, brightnessctl set +10%"
        ", edge:r:d, exec, brightnessctl set 10%-"
      ];

      # Misc settings for small display
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        no_direct_scanout = true; # Better touchscreen experience
      };

      # Decorations optimized for small screen
      decoration = {
        rounding = 5;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
        };
      };

      # Smaller gaps for more screen real estate
      general = {
        gaps_in = 2;
        gaps_out = 4;
        border_size = 1;
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
        height = 24; # Smaller for 7" screen
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

  # Terminal with appropriate font size for small screen
  programs.kitty.settings = {
    font_size = 10;
  };

  home.packages = with pkgs; [
    # Core development
    neovim
    git
    lazygit

    # System monitoring (important for Atom CPU)
    htop
    btop

    # Network tools
    mtr

    # File management
    yazi
    fzf
    ripgrep
    fd

    # Touchscreen utilities
    brightnessctl
    wvkbd # On-screen keyboard
    wtype # Keyboard input emulator

    # Terminal
    foot

    # Power monitoring
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
