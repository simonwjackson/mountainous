{ config, pkgs, ... }:

{
  imports = [
    ./desktop
    ./terminal
  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "simonwjackson";
    homeDirectory = "/home/simonwjackson";
  };

  home.packages = with pkgs; [
    # git-crypt
    # pinentry-qt
  ];

  # programs.gpg.enable = true;

  # services.gpg-agent = {
  #   enable = true;
  #   pinentryFlavor = "qt";
  # };

  # services.udiskie = {
  #   enable = true;
  # };

  home.stateVersion = "22.05";
  # home.stateVersion = "21.11";
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
