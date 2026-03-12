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
      enabled = false;
      special = true;
      size = 1;
      passes = 2;
      vibrancy = 0.1696;
      new_optimizations = true;
    };

    shadow = {
      enabled = false;
      range = 4;
      render_power = 3;
      color = "rgba(1a1a1aee)";
    };
  };

  animations = {
    enabled = false;
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
      disable_while_typing = true;
    };

    touchdevice = {
    };
  };

  device = {
    name = "epic-mouse-v1";
    sensitivity = -0.5;
  };
}
