{
  pkgs,
  inputs,
  ...
}: {
  # Gaming handheld optimized home configuration

  # Hyprland for gaming handheld with touch gesture support
  # Note: Auto-launch apps and gaming keybinds are configured in the gaming feature
  mountainous.hyprland = {
    # Enable hyprgrass plugin for native touch gesture support
    plugins = [
      inputs.hyprgrass.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    extraSettings = {
      monitor = [
        "eDP-1,preferred,auto,1.5,transform,1"
      ];

      exec-once = [
        "systemctl --user start hyprland-session.target"
      ];

      # Touch and gesture configuration
      input = {
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
          tap-and-drag = true;
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

  # Handheld-specific packages (gaming packages provided by gaming feature)
  home.packages = with pkgs; [
    # Core tools
    neovim
    git
    htop
    btop

    # Controller testing
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

    # Gaming launchers (besides Steam)
    # lutris      # Multi-platform game launcher
    # heroic      # Epic Games launcher

    # Optional: Emulators
    # retroarch   # Multi-system emulator
  ];

  # HiDPI configuration handled by gaming feature for handheld devices

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
