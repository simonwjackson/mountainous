{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  mountainous = {
    profiles.base.enable = true;
  };

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "24.11"; # WARN: Changing this might break things. Just leave it.
  };
}
