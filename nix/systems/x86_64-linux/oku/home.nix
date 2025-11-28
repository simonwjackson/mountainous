{
  pkgs,
  inputs,
  ...
}: {
  # Huawei MateBook E tablet home configuration

  mountainous.hyprland = {
    enable = true;

    # Touch gesture, workspace overview, and title bar plugins
    plugins = [
      inputs.hyprgrass.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprexpo
      # inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
    ];

    extraSettings = {
      # 12.6" OLED 2560x1600 DSI display
      monitor = [
        "DSI-1,2560x1600@60,auto,1.333,transform,0"
      ];

      exec-once = [
        "systemctl --user start hyprland-session.target"
        "iio-hyprland" # Auto-rotate display based on accelerometer
        "waybar"
      ];

      input = {
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
          tap-and-drag = true;
          disable_while_typing = false;
        };

        # Stylus configuration
        tablet = {
          # Map tablet input to monitor
          output = "DSI-1";
        };
      };

      # Touchscreen rotation (0 = no transform for landscape default)
      "input:touchdevice:transform" = 0;

      gesture = [
        "3, horizontal, workspace"
      ];

      # hyprgrass touch gesture config
      "plugin:touch_gestures:sensitivity" = 4.0;
      "plugin:touch_gestures:workspace_swipe_fingers" = 3;
      "plugin:touch_gestures:edge_margin" = 30;

      # hyprexpo workspace overview config
      "plugin:hyprexpo:columns" = 2;
      "plugin:hyprexpo:gap_size" = 5;
      "plugin:hyprexpo:bg_col" = "rgb(000000)";
      "plugin:hyprexpo:workspace_method" = "center current";
      "plugin:touch_gestures:long_press_delay" = 200;

      # hyprbars title bar config (touch-friendly sizes)
      # "plugin:hyprbars:bar_height" = 30;
      # "plugin:hyprbars:bar_color" = "rgb(1e1e2e)";
      # "plugin:hyprbars:col.text" = "rgb(cdd6f4)";
      # "plugin:hyprbars:bar_text_size" = 12;
      # "plugin:hyprbars:bar_text_font" = "Sans";
      # "plugin:hyprbars:bar_part_of_window" = true;
      # "plugin:hyprbars:bar_precedence_over_border" = true;
      # "plugin:hyprbars:bar_padding" = 10;
      # "plugin:hyprbars:bar_button_padding" = 8;

      # Title bar buttons (right to left: close, maximize, minimize)
      # "plugin:hyprbars:hyprbars-button" = [
      #   "rgb(f38ba8), 18, 󰖭, hyprctl dispatch killactive"
      #   "rgb(a6e3a1), 18, 󰁌, hyprctl dispatch fullscreen 1"
      #   "rgb(fab387), 18, 󰖰, hyprctl dispatch movetoworkspacesilent special:minimized"
      # ];

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

        # 5-finger: move window to workspace AND follow
        ", swipe:5:l, movetoworkspace, e+1"
        ", swipe:5:r, movetoworkspace, e-1"

        # 4-finger gestures
        ", swipe:4:u, hyprexpo:expo, toggle"
        ", swipe:4:d, togglefloating"

        # Edge swipes
        ", edge:r:l, togglespecialworkspace, magic"
        ", edge:r:u, exec, brightnessctl set +10%"
        ", edge:r:d, exec, brightnessctl set 10%-"

        # Toggle title bars (top edge swipe down)
        # ", edge:l:r, exec, hyprctl keyword plugin:hyprbars:bar_height $([ $(hyprctl getoption plugin:hyprbars:bar_height -j | grep -o '\"int\": [0-9]*' | awk '{print $2}') -eq 0 ] && echo 30 || echo 0)"

        # Virtual keyboard - left edge up to toggle (full+special layers)
        ", edge:l:u, exec, pkill -SIGRTMIN wvkbd-mobintl 2>/dev/null || wvkbd-mobintl -L 300 --landscape-layers full,special"
      ];
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
        height = 30;
        modules-center = ["hyprland/workspaces"];
        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
            active = "●";
            default = "○";
          };
          on-click = "activate";
        };
      };
    };
    style = ''
      * {
        font-family: monospace;
        font-size: 14px;
      }
      window#waybar {
        background: rgba(0, 0, 0, 1);
        color: #cdd6f4;
      }
      #workspaces button {
        padding: 0 8px;
        color: #6c7086;
        background: transparent;
        border: none;
      }
      #workspaces button.active {
        color: #cdd6f4;
      }
    '';
  };

  home.packages = with pkgs; [
    # Core
    neovim
    git
    htop
    btop

    # Tablet essentials - virtual keyboards
    wvkbd # Anchored to bottom
    wtype # Keyboard input emulator
    brightnessctl
    iio-hyprland # Auto-rotate for Hyprland (uses system iio-sensor-proxy)

    # Stylus/drawing
    rnote # Note-taking with stylus
    xournalpp # PDF annotation

    # Browsers
    firefox

    # File management
    nautilus

    # Terminal
    foot

    # Power monitoring
    acpi
    powertop

    # System
    nvme-cli
    lm_sensors
  ];

  # HiDPI for 12.6" 2560x1600 display (~240 PPI)
  # home.sessionVariables = {
  #   QT_AUTO_SCREEN_SCALE_FACTOR = "1";
  #   QT_SCALE_FACTOR = "1.6";
  #   GDK_SCALE = "1";
  #   GDK_DPI_SCALE = "0.8";
  # };

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
