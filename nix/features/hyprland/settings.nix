# Hyprland general settings (decoration, animations, misc, input, etc.)
{
  lib,
  pkgs,
}: {
  monitor = [",preferred,auto,auto"];

  exec-once = [
    "${pkgs.hyprdim}/bin/hyprdim"
  ];

  env = [
    "XCURSOR_SIZE,24"
    "HYPRCURSOR_SIZE,24"
    "XCURSOR_THEME,Adwaita"
    "XCURSOR_SIZE,24"
  ];

  general = {
    gaps_out = 0;
    gaps_in = 5;
    border_size = 0;
    allow_tearing = false;
    layout = "master";
  };

  decoration = {
    rounding = 10;
    active_opacity = 1.0;
    inactive_opacity = 1.0;
    dim_special = 0.8;

    blur = {
      enabled = true;
      special = true;
      size = 1;
      passes = 2;
      vibrancy = 0.1696;
      new_optimizations = true;
    };

    shadow = {
      enabled = true;
      range = 4;
      render_power = 3;
      color = "rgba(1a1a1aee)";
    };
  };

  animations = {
    enabled = true;

    bezier = [
      "easeOutQuint,0.23,1,0.32,1"
      "easeInOutCubic,0.65,0.05,0.36,1"
      "linear,0,0,1,1"
      "almostLinear,0.5,0.5,0.75,1.0"
      "quick,0.15,0,0.1,1"
    ];

    animation = [
      "global, 1, 10, default"
      "border, 1, 5.39, easeOutQuint"
      "windows, 1, 4.79, easeOutQuint"
      "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
      "windowsOut, 1, 1.49, linear, popin 87%"
      "fadeIn, 1, 1.73, almostLinear"
      "fadeOut, 1, 1.46, almostLinear"
      "fade, 1, 3.03, quick"
      "layers, 1, 3.81, easeOutQuint"
      "layersIn, 1, 4, easeOutQuint, fade"
      "layersOut, 1, 1.5, linear, fade"
      "fadeLayersIn, 1, 1.79, almostLinear"
      "fadeLayersOut, 1, 1.39, almostLinear"
      "workspaces, 1, 1.94, almostLinear, fade"
      "workspacesIn, 1, 1.21, almostLinear, fade"
      "workspacesOut, 1, 1.94, almostLinear, fade"
    ];
  };

  master = {
    orientation = "right";
    mfact = "0.61803";
    new_status = "slave";
  };

  misc = {
    force_default_wallpaper = 0;
    disable_hyprland_logo = true;
    disable_autoreload = false;
    disable_splash_rendering = true;
    background_color = "0x000000";
  };

  input = {
    kb_layout = "us";
    follow_mouse = 1;
    sensitivity = 0;

    touchpad = {
      natural_scroll = false;
    };

    touchdevice = {
    };
  };

  device = {
    name = "epic-mouse-v1";
    sensitivity = -0.5;
  };
}
