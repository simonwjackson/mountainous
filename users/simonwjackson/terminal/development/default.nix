{ pkgs, ... }:

{
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
}
