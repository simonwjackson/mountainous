{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    nerdfonts
  ];

  services.polybar = {
    enable = true;
    extraConfig = builtins.readFile ./polybar.ini
      + builtins.readFile ./modules/battery.ini
      + builtins.readFile ./modules/cpu.ini
      + builtins.readFile ./modules/filesystem.ini
      + builtins.readFile ./modules/memory.ini
      + builtins.readFile ./modules/pulseaudio.ini
      + builtins.readFile ./modules/time.ini
      + import ./modules/network { inherit pkgs config; }
      + import ./modules/check-reddit { inherit pkgs config; }
    ;

    script = ''
      polybar top &
    '';
  };
}
