{ ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.simonwjackson = { config, pkgs, ... }: {
    systemd.user.services.pywal-restore = {
      Unit = {
        Description = "Set pywal wallpaper at startup";
        After = "graphical-session.target";
      };
      Service = {
        Type = "oneshot";
        Environment = "DISPLAY=:0";
        ExecStart = "${pkgs.python3Packages.pywal}/bin/wal -R";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
