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
}: let
  user = "sjackson217";
in {
  home.packages = [];

  # HACK: This is needed with hom manager on mac. Atuin has issues with
  # the file(s) existing elsewhere
  # https://github.com/ryantm/agenix/issues/50
  # TODO: Create an activation script to create these folders
  age = {
    secretsDir = "${config.home.homeDirectory}/.agenix/agenix";
    secretsMountPoint = "${config.home.homeDirectory}/.agenix/agenix.d";
  };

  # mountainous.firefox.enable = true;
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-bin;
  };

  nixpkgs.overlays = [inputs.nixpkgs-firefox-darwin.overlay];

  programs.ssh = {
    matchBlocks = {
      "ushiro,ushiro.hummingbird-lake.ts.net,ushiro.mountaino.us" = {
        user = user;
      };
    };
  };

  home = {
    homeDirectory = "/Users/${user}";
    stateVersion = "23.11"; # WARN: Changing this might break things. Just leave it.
  };
}
