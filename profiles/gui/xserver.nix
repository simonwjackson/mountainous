{ pkgs, ... }: {
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

  home-manager.users.simonwjackson = { config, pkgs, ... }: {
    # home.file.".config/awesome/rc.lua".source = config.lib.file.mkOutOfStoreSymlink ./awesome/rc.lua;
    # home.file.".config/awesome/scratch.lua".source = config.lib.file.mkOutOfStoreSymlink ./awesome/scratch.lua;

    xsession.windowManager.awesome = {
      enable = true;
    };

    xsession = {
      enable = true;
      scriptPath = ".hm-xsession";
      initExtra = ''
        xrdb -merge ~/.Xresources
        # /home/simonwjackson/layout.sh &
        # virtual-term start &
        # /home/simonwjackson/.nix-profile/bin/virtual-term
      '';
      # windowManager.command = lib.mkForce ''
      #       # TESTING
      #       ${pkgs.bspwm} -c /home/simonwjackson/.config/bspwm/bspwmrc
      #       exec kitty
      # '';
    };
  };
}
