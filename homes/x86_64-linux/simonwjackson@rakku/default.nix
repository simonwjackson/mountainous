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
  };

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "23.11"; # WARN: Changing this might break things. Just leave it.
  };
}
