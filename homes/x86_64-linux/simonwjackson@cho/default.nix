{
  config,
  lib,
  pkgs,
  ...
}: {
  mountainous = {
    profiles.workstation.enable = true;
    desktops.hyprland = {
      extraSettings = {
        monitor = [
          "eDP-1,preferred,auto,1.5"
        ];
        exec-once = [
          "systemctl --user start hyprland-session.target"
        ];
      };
    };
  };

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "24.05"; # WARN: Changing this might break things. Just leave it.
  };
}
