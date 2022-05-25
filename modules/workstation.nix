{ config, pkgs, ... }:

{
  # X11
  # services.xserver = {
  #   enable = true;
  #   layout = "us";

  #   displayManager = {
  #     autoLogin = {
  #       enable = true;
  #       user = "simonwjackson";
  #     };
  #   };

  #   desktopManager = {
  #     session = [{
  #       name = "home-manager";
  #       start = ''
  #         ${pkgs.runtimeShell} $HOME/.hm-xsession &
  #         waitPID=$!
  #       '';
  #     }];
  #   };
  # };

  # Required when building a custom desktop env
  programs.dconf.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  nixpkgs.config.pulseaudio = true;

  environment.systemPackages = with pkgs; [
    neovim
    wget
    firefox
    bluez
    bluez-tools
  ];
}
