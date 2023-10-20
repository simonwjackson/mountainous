{ config, lib, pkgs, ... }:

{
  # Read the changelog before changing this value
  home.stateVersion = "22.11";

  home = {
    username = "nix-on-droid";
    homeDirectory = "/data/data/com.termux.nix/files/home";
    packages = with pkgs; [
      jq
    ];
  };
}
