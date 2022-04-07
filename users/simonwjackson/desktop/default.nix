{ config, pkgs, ... }:

{
  imports = [
    #./polybar
    ./bspwm
  ];

  home = {
    sessionVariables = {
      # Scaling
      GDK_SCALE = "2";
      GDK_DPI_SCALE = "0.5";
      QT_AUTO_SCREEN_SET_FACTOR = "0";
      QT_SCALE_FACTOR = "2";
      QT_FONT_DPI = "96";

      # Other
      MPV_SOCKET = "/tmp/mpv.socket";
    };

    shellAliases = {
      cat = "bat";
      sl = "exa";
      ls = "exa";
      l = "exa -l";
      la = "exa -la";
      ip = "ip --color=auto";
    };

    packages = with pkgs; [
      # Misc
      firefox
    ];
  };

  #xsession = {
  #  enable = true;
  #  scriptPath = ".hm-xsession";
  #};
 
  xresources = {
    properties = {
      "Xft.dpi" = "192";
    };
  };
  
  gtk = {
    enable = true;
  
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };
  
  programs.mpv = {
    enable = true;
  
    config = {
      input-ipc-server = "/tmp/mpv.socket";
      panscan = "1.0";
    };
  };
  
  programs.kitty = {
    enable = true;
    extraConfig = builtins.readFile (./kitty/kitty.conf);
  };
  
  # services.picom = {
  #   enable = true;
  #
  #   extraOptions = builtins.readFile (./picom/picom.conf);
  # };
 
  services.sxhkd = {
    enable = true;
  
    extraConfig = builtins.readFile (./sxhkd/sxhkdrc);
  };
}
