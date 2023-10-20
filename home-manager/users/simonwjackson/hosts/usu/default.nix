{ config, lib, pkgs, ... }:

{
  imports = [
    ../../global
  ];

  # Read the changelog before changing this value
  home.stateVersion = "23.05";

  home = {
    username = lib.mkForce "nix-on-droid";
    homeDirectory = lib.mkForce "/data/data/com.termux.nix/files/home";
    packages = with pkgs; [
      jq
      ex
    ];
  };
}
