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
    extraConfig = {
      dpi = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then 192 else 96;
    };
    configPath = "${config.xdg.configHome}/rofi/config.base.rasi";
  };

  xsession.windowManager.bspwm = {
    enable = true;

    extraConfig = builtins.readFile (./bspwmrc);
  };
}
