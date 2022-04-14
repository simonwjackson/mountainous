{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    nerdfonts
  ];

  services.polybar = {
    enable = true;
    extraConfig = builtins.readFile ./polybar.ini
      + import ./modules/network { inherit pkgs config; }
      + import ./modules/check-reddit { inherit pkgs config; }
    ;

    script = ''
      polybar top &
    '';

    settings = {
      "bar/top" = {
        monitor = "\${env:MONITOR:eDP-1}";
        width = "100%";
        height = "3%";
        radius = 0;
        modules-left = "";
        modules-center = "";
        modules-right = "battery check-reddit network time";
        font-0 = "NotoSansMono Nerd Font:pixelsize=20;5";
        font-1 = "NotoSansMono Nerd Font:pixelsize=18;4";
        font-2 = "NotoSansMono Nerd Font:pixelsize=15;4";
      };
    };
  };
}
