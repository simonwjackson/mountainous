{ pkgs, ... }:

{
  imports = [
    ../modules/syncthing.nix
    ../modules/tailscale.nix
    ../modules/networking.nix
    ../profiles/gui
    ../profiles/audio.nix
    ../profiles/workstation.nix
    ../profiles/_common.nix
    ../users/simonwjackson
  ];

  services.udisks2.enable = true;

  security.rtkit.enable = true; # rtkit is optional but recommended
  environment.variables.BROWSER = "firefox";

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

