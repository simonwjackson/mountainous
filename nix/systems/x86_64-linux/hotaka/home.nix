{
  pkgs,
  inputs,
  ...
}: {
  # Gaming handheld optimized home configuration

  # Hyprland for gaming handheld with touch gesture support
  mountainous.hyprland = {
    enable = true;

    # Enable hyprgrass plugin for native touch gesture support
    plugins = [
      inputs.hyprgrass.packages.${pkgs.system}.default
    ];

    extraSettings = {
      monitor = [
        "eDP-1,preferred,auto,1.5,transform,1"
      ];

      exec-once = [
        "systemctl --user start hyprland-session.target"
        # Auto-launch Steam Big Picture on workspace 1 (main workspace)
        "[workspace 1 silent] steam"
        # Auto-launch Moonlight on workspace 2 for game streaming
        "[workspace 2 silent] moonlight"
      ];

      # Touch and gesture configuration
      input = {
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
          tap-and-drag = true;
          disable_while_typing = false; # Handheld - no traditional keyboard
        };
      };

      # Touchscreen rotation to match monitor transform (1 = 90 degrees)
      "input:touchdevice:transform" = 1;

      # Hyprland native gesture (for trackpad - uses gesture keyword, not gestures block)
      gesture = [
        "3, horizontal, workspace"
      ];

      # hyprgrass plugin configuration (note: plugin: prefix required)
      "plugin:touch_gestures:sensitivity" = 4.0; # Increase for tablet (default 1.0 too low)
      "plugin:touch_gestures:workspace_swipe_fingers" = 3;
      "plugin:touch_gestures:edge_margin" = 30; # Larger margin for easier edge swipe triggering
      "plugin:touch_gestures:debug:visualize_touch" = 1; # Show visual feedback for touch points

      # Gaming-friendly binds
      bind = [
        "SUPER, F1, exec, steam" # Quick Steam access
        "SUPER, F2, exec, gamemode" # Toggle gamemode
        "SUPER, F3, exec, moonlight" # Quick Moonlight access
      ];

      # hyprgrass touch gesture bindings
      "hyprgrass-bind" = [
        # 3-finger workspace switching (left/right swipes)
        ", swipe:3:l, workspace, e+1"
        ", swipe:3:r, workspace, e-1"

        # 4-finger gestures for window management
        ", swipe:4:u, fullscreen, 1"
        ", swipe:4:d, exec, sh -c 'hyprctl clients | grep -iq \"class: steam\" && hyprctl dispatch focuswindow \"class:^(steam)$\" || steam'"

        # Edge swipes for special workspace (replaces pinch gestures)
        ", edge:r:l, togglespecialworkspace, magic"

        # Edge swipes for brightness control (left edge up/down)
        # ", edge:l:u, exec, brightnessctl set +5%"
        # ", edge:l:d, exec, brightnessctl set 5%-"

        # Virtual keyboard toggle gestures
        # ", edge:b:u, exec, pkill wvkbd-mobintl || wvkbd-mobintl -L 400" # Bottom edge swipe up
        ", swipe:3:u, exec, pkill wvkbd-mobintl || wvkbd-mobintl -L 400" # 3-finger swipe up
      ];

      # Window rules for gaming
      windowrule = [
        # Steam should be on workspace 1, not special workspace
        "workspace 1, match:class ^(steam)$"
        # Steam should be fullscreen by default
        "fullscreen true, match:class ^(steam)$, match:title ^(Steam Big Picture Mode)$"
        # Moonlight should be on workspace 2
        "workspace 2, match:class ^(moonlight)$"
        # Moonlight should be fullscreen by default
        "fullscreen true, match:class ^(moonlight)$"
      ];
    };
  };

  # Git configuration
  programs.git.settings = {
    init.defaultBranch = "main";
  };

  # Development tools
  programs.direnv.enable = true;

  # Gaming and handheld-specific packages
  home.packages = with pkgs; [
    # Core tools
    neovim
    git
    htop
    btop

    # Game streaming
    moonlight-qt # Game streaming client

    # Gaming utilities (mangohud, gamemode provided by mountainous.steam)
    goverlay # MangoHud GUI configuration

    # Controller testing
    jstest-gtk # Gamepad testing GUI
    evtest # Input event testing

    # System monitoring
    nvme-cli # NVMe health monitoring
    lm_sensors # Temperature monitoring

    # Battery and power monitoring
    acpi # Battery status and info
    powertop # Power consumption analysis

    # Handheld utilities
    brightnessctl # Screen brightness control
    wtype # Wayland keyboard input emulator (for touch gestures)
    wvkbd # Lightweight Wayland virtual keyboard for touch input

    # Gaming launchers (besides Steam)
    # lutris      # Multi-platform game launcher
    # heroic      # Epic Games launcher

    # Optional: Emulators
    # retroarch   # Multi-system emulator
  ];

  # HiDPI configuration for 7" 314 PPI display
  home.sessionVariables = {
    # Scale factor for Qt applications
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_SCALE_FACTOR = "1.5";

    # Scale factor for GTK applications
    GDK_SCALE = "2";
    GDK_DPI_SCALE = "0.75"; # 2 * 0.75 = 1.5x effective
  };

  # XDG user directories for gaming saves, etc.
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    documents = "$HOME/Documents";
    download = "$HOME/Downloads";
    pictures = "$HOME/Pictures";
    videos = "$HOME/Videos";
    music = "$HOME/Music";
  };

  # Enable persistence for gaming data
  # Note: Main persistence config is in default.nix
  # Steam data: ~/.local/share/Steam
  # Save games: ~/.local/share/<game-name>
  # These are automatically persisted via /home/simonwjackson persistence
}
