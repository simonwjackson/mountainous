# Hyprlock and hypridle configuration
{
  lib,
  pkgs,
}: {
  hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        grace = 0;
        hide_cursor = true;
        no_fade_in = false;
      };

      background = [
        {
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
        }
      ];

      input-field = [
        {
          size = "200, 50";
          position = "0, -80";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(202, 211, 245)";
          inner_color = "rgb(91, 96, 120)";
          outer_color = "rgb(24, 25, 38)";
          outline_thickness = 5;
          placeholder_text = ''<span foreground="##cad3f5">Password...</span>'';
          shadow_passes = 2;
        }
      ];
    };
  };

  hypridle = {
    enable = true;
    settings = {
      general = {
        # CRITICAL: Turn off display BEFORE suspend (fixes screen staying on during s2idle)
        before_sleep_cmd = "hyprctl dispatch dpms off";
        # Restore display after resume
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        lock_cmd = "pidof hyprlock || hyprlock";
      };

      listener = [
        # Turn off display after 2 minutes of inactivity
        {
          timeout = 120;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        # Suspend after 5 minutes idle (only on battery)
        {
          timeout = 300;
          on-timeout = "cat /sys/class/power_supply/*/online 2>/dev/null | grep -q 1 || systemctl suspend";
        }
      ];
    };
  };
}
