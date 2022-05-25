{ config, pkgs, modulesPath, lib, ... }:

{
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [ terminus_font ]; 
  };

  # high-resolution display
  hardware.video.hidpi.enable = lib.mkDefault true;

  # xresources = {
  #   properties = {
  #     "Xft.dpi" = 192;
  #   };
  # };

  # home = {
  #   sessionVariables = {
  #     GDK_SCALE = 2;
  #     GDK_DPI_SCALE = 0.5;
  #     QT_AUTO_SCREEN_SET_FACTOR = 0;
  #     QT_SCALE_FACTOR = 2;
  #     QT_FONT_DPI = 96;
  #   };
  # };
}
