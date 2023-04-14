{ pkgs, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  users.users.simonwjackson = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Simon W. Jackson";
    extraGroups = [
      "adbusers"
      "docker"
      "networkmanager"
      "wheel"
    ];
  };

  home-manager.users.simonwjackson = { config, pkgs, ... }: {
    home.stateVersion = "23.05";

    home = {
      username = "simonwjackson";
      homeDirectory = "/home/simonwjackson";
    };
  };
}
