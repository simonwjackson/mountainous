{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  pkgs,
  # You also have access to your flake's inputs.
  inputs,
  # Additional metadata is provided by Snowfall Lib.
  home, # The home architecture for this host (eg. `x86_64-linux`).
  target, # The Snowfall Lib target for this home (eg. `x86_64-home`).
  format, # A normalized name for the home target (eg. `home`).
  virtual, # A boolean to determine whether this home is a virtual target using nixos-generators.
  host, # The host name for this home.
  # All other arguments come from the home home.
  config,
  ...
}: {
  # mountainous.hyprpaper-watcher.enable = true;
  # mountainous.auto-blur-image = {
  #   enable = true;
  #   input = "/home/${config.home.username}/.cache/wallpapers/album.png";
  #   output = "/home/${config.home.username}/.cache/wallpapers/watched-image.png";
  # };

  mountainous = {
    profiles.workstation.enable = true;
    desktops.hyprland = {
      extraSettings = {
        monitor = [
          ",preferred,auto,auto"
          "DP-1,2560x1440@240,auto,auto"
          "HDMI-A-2,1920x1080@60,auto,auto"
        ];
        exec-once = [
          "systemctl --user start hyprland-session.target"
        ];
        general = {
          gaps_in = 20;
          gaps_out = "20,200";
        };
      };
    };
  };

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "24.05"; # WARN: Changing this might break things. Just leave it.
  };
}
