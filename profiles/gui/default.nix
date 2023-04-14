{ pkgs, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
    ./desktop
    ./xserver.nix
  ];

  services.udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];
  services.dbus.packages = [ pkgs.dconf ];

  # Required when building a custom desktop env
  programs.dconf.enable = true;
}
