{ pkgs, ... }:

{
  imports = [
    ../modules/syncthing.nix
  ];

  security.rtkit.enable = true; # rtkit is optional but recommended
  environment.variables.BROWSER = "firefox";
  programs.mosh.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    wget
    bluez
    bluez-tools
    xsettingsd
    gsettings-desktop-schemas
    kitty # INFO: `sxhkd` can't find kitty without adding here as well
  ];
}

