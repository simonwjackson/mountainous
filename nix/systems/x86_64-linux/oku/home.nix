{
  pkgs,
  inputs,
  ...
}: {
  # Huawei MateBook E tablet home configuration

  mountainous.hyprland = {
    enable = true;

    # Touch gesture support
    plugins = [
      inputs.hyprgrass.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    extraSettings = {
      # 12.6" OLED 2560x1600 display
      # Native orientation is portrait, transform,1 for landscape
      monitor = [
        "eDP-1,2560x1600@60,auto,1.6,transform,0"
      ];

      exec-once = [
        "systemctl --user start hyprland-session.target"
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
          output = "eDP-1";
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

      bind = [
        # Quick launchers
        "SUPER, T, exec, foot" # Terminal
        "SUPER, F, exec, firefox" # Browser
        "SUPER, E, exec, nautilus" # Files

        # Virtual keyboard toggle
        "SUPER, K, exec, pkill wvkbd-mobintl || wvkbd-mobintl -L 400"
      ];

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

        # Edge swipes
        ", edge:r:l, togglespecialworkspace, magic"

        # Virtual keyboard
        ", swipe:3:u, exec, pkill wvkbd-mobintl || wvkbd-mobintl -L 400"
      ];
    };
  };

  programs.git.settings = {
    init.defaultBranch = "main";
  };

  programs.direnv.enable = true;

  home.packages = with pkgs; [
    # Core
    neovim
    git
    htop
    btop

    # Tablet essentials
    wvkbd # Virtual keyboard
    wtype # Keyboard input emulator
    brightnessctl
    iio-sensor-proxy # Rotation sensor

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
  home.sessionVariables = {
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_SCALE_FACTOR = "1.6";
    GDK_SCALE = "2";
    GDK_DPI_SCALE = "0.8";
  };

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
