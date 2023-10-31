{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    ../../global
    ./aria2.nix
    ./beets.nix
    ./firefox
    ./kitty
  ];

  gtk = {
    enable = true;
    # iconTheme = {
    #   name = "xfce4-icon-theme";
    #   package = pkgs.xfce.xfce4-icon-theme;
    # };
    theme = {
      name = "matcha-dark-sea";
      package = pkgs.matcha-gtk-theme;
    };
    gtk3.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
    gtk4.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
  };

  # INFO: https://github.com/nix-community/home-manager/issues/1011#issuecomment-1452920285
  xdg.configFile."plasma-workspace/env/hm-session-vars.sh".text = ''
    . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
  '';

  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "/glacier/snowscape/desktop";
      documents = "/glacier/snowscape/documents";
      download = "/glacier/snowscape/downloads";
      music = "/glacier/snowscape/music";
      pictures = "/glacier/snowscape/photos";
    };
  };

  programs.vinyl-vault = {
    enable = true;
    rootDownloadPath = config.xdg.userDirs.music;
  };

  services.mpvd.enable = true;
  services.udiskie.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";

  xsession = {
    enable = true;
    scriptPath = ".hm-xsession";
    # initExtra = ''
    #   # xrdb -merge ~/.Xresources
    #   # /home/simonwjackson/layout.sh &
    #   # virtual-term start &
    #   # /home/simonwjackson/.nix-profile/bin/virtual-term
    # '';
    windowManager.command = lib.mkForce ''
      exec ${pkgs.herbstluftwm}/bin/herbstluftwm --locked
      # exec $(while true; do sleep 1; done)
      # exec ${pkgs.kitty}/bin/kitty
      # ${pkgs.openbox}/bin/openbox &
      # exec ${pkgs.xfce.xfwm4}/bin/xfwm4
      # exec ${pkgs.bspwm}/bin/bspwm -c /home/simonwjackson/bspwmrc
      # exec /home/simonwjackson/toggle-wm
    '';
  };


  xresources = {
    properties = {
      "Xft.dpi" = "128";
      "Xcursor.size" = "32";
    };
  };

  xsession.windowManager.herbstluftwm = {
    enable = true;
    settings = {
      focus_follows_mouse = 1;
      gapless_grid = false;
      always_show_frame = false;
      frame_gap = 0;
      window_border_width = 0;
      frame_border_width = 0;
      window_border_active_color = "#FF0000";
      default_frame_layout = "max";
    };
    rules = [
      "windowtype~'_NET_WM_WINDOW_TYPE_(DIALOG|UTILITY|SPLASH)' focus=on pseudotile=on"
      "windowtype~'_NET_WM_WINDOW_TYPE_(NOTIFICATION|DOCK|DESKTOP)' manage=off"
    ];
    tags = ["main" "other"];
    # focus padding mode
    # herbstclient pad 0 200 500 200 500
    extraConfig = let
      padding = 25;
    in ''
      herbstclient set_layout max
      herbstclient detect_monitors
      herbstclient set window_gap ${padding}
      herbstclient pad 0 40 0 -${padding} 0
    '';
  };

  services.sxhkd = {
    enable = true;
    keybindings = let
      popup = "${pkgs.herbstluftwm-popup}/bin/herbstluftwm-popup";
      kitty = "${pkgs.kitty}/bin/kitty";
      term-popup = "${pkgs.herbstluftwm-popup}/bin/herbstluftwm-popup ${kitty} --";
      hc = "${pkgs.herbstluftwm}/bin/herbstclient";
      brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
    in {
      "super + space" = ''
        ${term-popup} nmtui
      '';
      "super + ctrl + space" = ''
        ${hc} cycle_layout 1 horizontal max
      '';
      "super + {_, shift} + Tab" = ''
        ${hc} cycle_all {+,-}1
      '';
      "super + Return" = ''
        ${kitty}
      '';
      "XF86Audio{Raise,Lower}Volume" = ''
        ${pkgs.pamixer}/bin/pamixer --{increase,decrease} 5
      '';
      "super + w" = ''
        ${pkgs.wmctrl}/bin/wmctrl -xa $BROWSER || $BROWSER
      '';
      "{XF86MonBrightnessDown,XF86MonBrightnessUp}" = ''
        ${brightnessctl} --device='*' --exponent set 5%{-,+}
      '';
      "super + {XF86MonBrightnessDown,XF86MonBrightnessUp}" = ''
        ${brightnessctl} --device='*' set {1,100}%
      '';
      "super + {h,j,k,l}" = ''
        ${hc} focus {left,down,up,right}
      '';
    };
  };












}
