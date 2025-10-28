{
  pkgs,
  inputs,
  ...
}: {
  # Gaming handheld optimized home configuration

  # Hyprland for gaming handheld with touch gesture support
  mountainous.hyprland = {
    enable = true;

    # Note: Using libinput-gestures instead of hyprgrass due to version compatibility
    # plugins = [];

    extraSettings = {
      monitor = [
        "eDP-1,1920x1080@60,0x0,1.5,transform,1"
      ];

      exec-once = [
        "systemctl --user start hyprland-session.target"
        # Launch libinput-gestures for touch gesture support
        "libinput-gestures"
        # Auto-launch Steam Big Picture on workspace 1 (main workspace)
        "[workspace 1 silent] steam"
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

      # gestures = {
      #   workspace_swipe = true;
      #   workspace_swipe_fingers = 3;
      #   workspace_swipe_distance = 300;
      #   workspace_swipe_forever = false;
      #   workspace_swipe_cancel_ratio = 0.5;
      # };

      # Gaming-friendly binds
      bind = [
        "SUPER, F1, exec, steam" # Quick Steam access
        "SUPER, F2, exec, gamemode" # Toggle gamemode
      ];

      # Window rules for gaming
      windowrulev2 = [
        # Steam should be on workspace 1, not special workspace
        "workspace 1, class:^(steam)$"
        # Steam should be fullscreen by default
        "fullscreen, class:^(steam)$, title:^(Steam Big Picture Mode)$"
      ];
    };
  };

  # Git configuration
  programs.git.extraConfig = {
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

    # Touch gesture support
    libinput-gestures
    wmctrl # Required by libinput-gestures
    xdotool # Required by libinput-gestures

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

  # libinput-gestures configuration for touch gestures
  xdg.configFile."libinput-gestures.conf".source = ./libinput-gestures.conf;

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
