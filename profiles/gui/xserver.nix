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
        # GDK_SCALE = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then 2 else 1;
        # GDK_DPI_SCALE = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then 0.5 else 1;
        # QT_SCALE_FACTOR = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then 2 else 1;
        GDK_SCALE = 1;
        GDK_DPI_SCALE = 1;
        QT_AUTO_SCREEN_SET_FACTOR = 1;
        # QT_QPA_PLATFORMTHEME = "qt5ct";
        QT_SCALE_FACTOR = 1;
        QT_FONT_DPI = 96;
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
        "Xft.dpi" = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then "120" else "96";
        "*.dpi" = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then "120" else "96";
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
