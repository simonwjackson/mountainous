{ pkgs, ... }:

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

  xsession.windowManager.bspwm = {
    enable = true;

    extraConfig = builtins.readFile (./bspwmrc);
  };
}
