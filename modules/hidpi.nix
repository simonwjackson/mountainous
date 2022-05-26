{ config, pkgs, modulesPath, lib, home, ... }:

{
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [ terminus_font ]; 
  };

  # high-resolution display
  hardware.video.hidpi.enable = lib.mkDefault true;
}
