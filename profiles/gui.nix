{ pkgs, ... }:

{
  services.udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];
  services.dbus.packages = [ pkgs.dconf ];

  # X11
  services.xserver = {
    enable = true;
    layout = "us";

    # INFO: Needed for gtk light/dark mode switch
    desktopManager.gnome3.enable = true;

    displayManager = {
      lightdm.enable = true;
      gdm.enable = false;
      defaultSession = "home-manager";
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

  # Required when building a custom desktop env
  programs.dconf.enable = true;
}

