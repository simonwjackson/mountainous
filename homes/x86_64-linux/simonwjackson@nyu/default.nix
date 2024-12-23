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
  profiles = {
    base.enable = true;
    workstation.enable = true;
  };

  # services.elevate = {
  #   enable = true;
  #   port = 8080;
  #   extraPackages = with pkgs; [
  #     ryzenadj
  #     gamescope
  #     gamemode
  #     moonlight-qt
  #     mangohud
  #     proton-ge-custom
  #   ];
  # };

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "23.11"; # WARN: Changing this might break things. Just leave it.
  };
}
