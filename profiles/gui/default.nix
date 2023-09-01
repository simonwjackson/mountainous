{ pkgs, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
    ./desktop
    ./xserver.nix
    ../../modules/theme.nix
  ];

  # services.udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];
  services.dbus.packages = [ pkgs.dconf ];

  # Required when building a custom desktop env
  programs.dconf.enable = true;

  # home-manager.users.simonwjackson = { config, pkgs, ... }: {
  #   systemd.user = {
  #     services.xsettingsd = {
  #       Unit = {
  #         Description = "xsettingsd";
  #       };
  #       Service = {
  #         Type = "simple";
  #         ExecStart = "${pkgs.xsettingsd}/bin/xsettingsd";
  #         ExecStop = "pkill xsettingsd";
  #       };
  #       Install = {
  #         WantedBy = [ "multi-user.target" ];
  #       };
  #     };

  #     services.xsettingsd-watcher = {
  #       Unit = {
  #         Description = "xsettingsd restarter";
  #       };
  #       Service = {
  #         Type = "oneshot";
  #         ExecStart = "${pkgs.systemd}/bin/systemctl --user restart xsettingsd.service";
  #       };
  #       Install = {
  #         WantedBy = [ "multi-user.target" ];
  #       };
  #     };

  #     paths.xsettingsd-watcher = {
  #       Path = {
  #         PathModified = "/home/simonwjackson/.xsettingsd";
  #       };
  #       Install = {
  #         WantedBy = [ "multi-user.target" ];
  #       };
  #     };
  #   };
  # };
}
