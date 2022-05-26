{ config, pkgs, ... }:

{
  home = {
    sessionVariables = {
      BSPWM_SOCKET = "/tmp/bspwm-socket";
    };

    packages = with pkgs; [
      hsetroot
      bsp-layout

      # TODO: Move into modules?
      brotab
      xclip
    ];
  };

  # TODO: Move into modules?
  programs.rofi = {
    enable = true;
    cycle = true;
    theme = "Arc-Dark"; 
  };

  xsession.windowManager.bspwm = {
    enable = true;

    extraConfig = builtins.readFile (./bspwmrc);
    startupPrograms = [
      "kitty"
    ];
  };
}
