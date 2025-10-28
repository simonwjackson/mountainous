{pkgs, ...}: {
  # Gaming handheld optimized home configuration

  # Option: Hyprland for gaming (lightweight Wayland compositor)
  # Uncomment to enable:
  # mountainous.hyprland = {
  #   enable = true;
  #   extraSettings = {
  #     monitor = [
  #       # 7" 1920x1080 display at native resolution
  #       "eDP-1,1920x1080@60,0x0,1.5" # 1.5x scale for HiDPI (314 PPI)
  #     ];
  #     exec-once = [
  #       "systemctl --user start hyprland-session.target"
  #       # Optional: Auto-launch Steam Big Picture
  #       # "steam -bigpicture"
  #     ];
  #     # Gaming-friendly binds
  #     bind = [
  #       "SUPER, F1, exec, steam -bigpicture" # Quick Steam access
  #       "SUPER, F2, exec, gamemode"          # Toggle gamemode
  #     ];
  #   };
  # };

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

    # Gaming utilities
    mangohud    # FPS overlay and performance monitoring
    goverlay    # MangoHud GUI configuration
    gamemode    # Performance optimization for games

    # Controller testing
    jstest-gtk  # Gamepad testing GUI
    evtest      # Input event testing

    # System monitoring
    nvme-cli    # NVMe health monitoring
    lm_sensors  # Temperature monitoring

    # Handheld utilities
    brightnessctl # Screen brightness control

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
