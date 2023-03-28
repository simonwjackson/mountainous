{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    sessionVariables = { };
  };

  home.packages = with pkgs; [
    python3
    nodePackages.node2nix
    entr
    stdenv
    yarn2nix
    node2nix
    docker
    docker-compose
  ];

  programs.lazygit = {
    enable = true;

    settings = import ./lazygit.nix;
  };
}
