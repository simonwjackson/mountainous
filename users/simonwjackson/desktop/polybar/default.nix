{ config, pkgs, lib, ... }:

let
  check-reddit = import ./modules/check-reddit { inherit pkgs config; };
in
{
  services.polybar = {
    enable = true;
    script = ''
      polybar top &
    '';

    settings = {
      "bar/top" = {
        monitor = "\${env:MONITOR:eDP-1}";
        width = "100%";
        height = "3%";
        radius = 0;
        modules-center = "date  check-reddit";
      };

      "module/date" = {
        type = "internal/date";
        internal = 5;
        date = "%d.%m.%y";
        time = "%H:%M";
        label = "%time%  %date%";
      };

      "module/check-reddit" = {
        type = "custom/script";
        exec = check-reddit;
      };
    };
  };
}

