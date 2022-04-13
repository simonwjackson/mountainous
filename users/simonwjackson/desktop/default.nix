{ config, pkgs, ... }:

{
  imports = [
    ./polybar
    ./bspwm
  ];

  home = {
    sessionVariables = {
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
      brightnessctl
      firefox
    ];
  };

  xsession = {
    enable = true;
    scriptPath = ".hm-xsession";
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

  services.picom = {
    enable = true;

    extraOptions = builtins.readFile (./picom/picom.conf);
  };

  services.sxhkd = {
    enable = true;

    extraConfig = builtins.readFile (./sxhkd/sxhkdrc);
  };
}
