{
  config,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkIf mkMerge optionals;

  # Get gaming config from NixOS (source of truth)
  gamingEnabled = osConfig.mountainous.gaming.enable or false;
  gamingCfg = osConfig.mountainous.gaming or {};

  # Check if Hyprland is enabled
  hyprlandEnabled = osConfig.mountainous.hyprland.enable or false;

  # Determine device type
  isHandheld = gamingCfg.deviceType or "desktop" == "handheld";

  # Check if overlay is enabled
  overlayEnabled = gamingCfg.home.overlay.enable or true;
in {
  config = mkIf gamingEnabled (mkMerge [
    # Base gaming configuration (applies to all device types)
    {
      # Core gaming packages
      home.packages = with pkgs;
        [
          moonlight-qt # Game streaming client
          goverlay # MangoHUD configuration GUI
        ]
        ++ optionals isHandheld [
          # Handheld-specific packages
          jstest-gtk # Gamepad testing GUI
          wvkbd # Wayland virtual keyboard for touch input
        ];

      # MangoHUD configuration (if overlay enabled)
      programs.mangohud = mkIf overlayEnabled {
        enable = true;
        settings = {
          # Performance metrics
          fps = true;
          frametime = true;
          cpu_stats = true;
          gpu_stats = true;

          # Temperature monitoring
          cpu_temp = true;
          gpu_temp = true;

          # Resource usage
          cpu_power = true;
          gpu_power = true;
          ram = true;
          vram = true;

          # Display settings
          position = "top-left";
          font_size = 24;

          # Performance limit warnings
          fps_limit_method = "late";
          toggle_fps_limit = "Shift_R+F1";
        };
      };
    }

    # Hyprland integration (only if Hyprland is enabled)
    (mkIf hyprlandEnabled {
      mountainous.hyprland.extraSettings = mkMerge [
        # Add gaming keybinds
        (mkIf (gamingCfg.home.keybinds != {}) {
          bind = lib.mapAttrsToList (key: cmd: "${key}, ${cmd}") gamingCfg.home.keybinds;
        })

        # Add auto-launch applications
        (mkIf (gamingCfg.home.autoLaunch != []) {
          exec-once = gamingCfg.home.autoLaunch;
        })
      ];
    })

    # Handheld-specific configuration
    (mkIf isHandheld {
      # HiDPI scaling for handheld displays
      home.sessionVariables = {
        # Qt applications scaling
        QT_AUTO_SCREEN_SCALE_FACTOR = "1";
        QT_SCALE_FACTOR = "1.5";

        # GTK applications scaling
        GDK_SCALE = "2";
        GDK_DPI_SCALE = "0.75"; # 2 * 0.75 = 1.5x effective
      };
    })
  ]);
}
