{ config, pkgs, ... }:

{
  # X11
  services.xserver = {
    enable = true;
    layout = "us";

    displayManager = {
      autoLogin = {
        enable = true;
        user = "simonwjackson";
      };
    };

    desktopManager = {
      session = [{
        name = "home-manager";
        start = ''
          ${pkgs.runtimeShell} $HOME/.hm-xsession &
          waitPID=$!
        '';
      }];
    };
  };

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  nixpkgs.config.pulseaudio = true;

  environment.systemPackages = with pkgs; [
    #firefox
    bluez
    bluez-tools
  ];
}
