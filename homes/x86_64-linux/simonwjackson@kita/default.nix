{
  lib,
  pkgs,
  inputs,
  home,
  target,
  format,
  virtual,
  host,
  config,
  ...
}: {
  mountainous = {
    profiles.workstation.enable = true;
    desktops.hyprland = {
      extraSettings = {
        monitor = [
          ",preferred,auto,auto"
          "eDP-1,1080x1920@120,0x0,1.5,transform,3"
          "DP-1,1920x1080@60,0x0,1.5"
        ];
      };
    };
  };

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "23.11"; # WARN: Changing this might break things. Just leave it.
  };
}
