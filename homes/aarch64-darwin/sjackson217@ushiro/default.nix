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

  # HACK: This is needed with hom manager on mac. Atuin has issues with
  # the file(s) existing elsewhere
  # https://github.com/ryantm/agenix/issues/50
  # TODO: Create an activation script to create these folders
  age = {
    secretsDir = "${config.home.homeDirectory}/.agenix/agenix";
    secretsMountPoint = "${config.home.homeDirectory}/.agenix/agenix.d";
  };

  home = {
    homeDirectory = "/Users/sjackson217";
    stateVersion = "23.11"; # WARN: Changing this might break things. Just leave it.
  };
}
