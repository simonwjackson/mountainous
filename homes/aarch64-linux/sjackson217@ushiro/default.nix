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
  home.packages = [
  ];

  # HACK: This is needed on mac. Atuin has issues wit the file existing elsewhere
  # TODO: Create an activation script to create this folder
  age.secretsDir = "${config.home.homeDirectory}/.keys";

  home = {
    homeDirectory = "/Users/sjackson217";
    stateVersion = "23.11"; # WARN: Changing this might break things. Just leave it.
  };
}
