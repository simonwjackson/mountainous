{ config, pkgs, lib, ... }:

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
      xfce.xfwm4
    ];
  };

  xsession = {
    enable = true;
    scriptPath = ".hm-xsession";
    # windowManager.command = lib.mkForce ''
    #   # TESTING
    #   # ${pkgs.bspwm} -c /home/simonwjackson/.config/bspwm/bspwmrc
    #   exec kitty
    # '';
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

