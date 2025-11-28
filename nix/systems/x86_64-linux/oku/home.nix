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
      # 12.6" OLED 2560x1600 DSI display
      monitor = [
        "DSI-1,2560x1600@60,auto,1.25,transform,0"
      ];

      exec-once = [
        "systemctl --user start hyprland-session.target"
        "iio-hyprland" # Auto-rotate display based on accelerometer
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

        # Edge swipes
        ", edge:r:l, togglespecialworkspace, magic"

        # Virtual keyboard (height: -L landscape, -H portrait)
        ", swipe:3:u, exec, pkill wvkbd-mobintl || wvkbd-mobintl -L 250"
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
