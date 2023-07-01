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

    home = {
      sessionVariables = {
        GDK_SCALE =
          if (builtins.getEnv ("GDK_SCALE") == "")
          then "1"
          else builtins.getEnv ("GDK_SCALE");
        GDK_DPI_SCALE =
          if (builtins.getEnv ("GDK_DPI_SCALE") == "")
          then "1"
          else builtins.getEnv ("GDK_DPI_SCALE");
        QT_SCALE_FACTOR =
          if (builtins.getEnv ("QT_SCALE_FACTOR") == "")
          then "1"
          else builtins.getEnv ("QT_SCALE_FACTOR");
        QT_FONT_DPI =
          if (builtins.getEnv ("QT_FONT_DPI") == "")
          then "96"
          else builtins.getEnv ("QT_FONT_DPI");
        # honor screen DPI
        QT_AUTO_SCREEN_SET_FACTOR = 1;
        # QT_QPA_PLATFORMTHEME = "qt5ct";
      };
    };

    xresources = {
      properties = {
        "Xcursor.size" = 46;
        "Xft.autohint" = 0;
        "Xft.lcdfilter" = "lcddefault";
        "Xft.hintstyle" = "hintfull";
        "Xft.hinting" = 1;
        "Xft.antialias" = 1;
        "Xft.rgba" = "r=b";
        "Xft.dpi" = builtins.getEnv ("DPI");
        "*.dpi" = builtins.getEnv ("DPI");
      };
    };

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

    services.unclutter = {
      enable = true;
      extraOptions = [
        "exclude-root"
        "ignore-scrolling"
      ];
    };
  };
}
