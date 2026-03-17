{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.presets.core;
in {
  config = lib.mkIf cfg.enable {
    mountainous.features.dnshack.enable = true;

    environment.packages = with pkgs; [
      vim
      curl
      rsync
      which
      git
      mosh
      gnused
    ];

    environment.etcBackupExtension = ".bak";

    system.stateVersion = "24.05";

    nix.extraOptions = ''
      experimental-features = nix-command flakes
    '';

    home-manager = {
      backupFileExtension = "hm-bak";
      useGlobalPkgs = true;
      config = {
        home.stateVersion = lib.mkDefault "24.05";
        programs.bash.enable = true;
      };
    };
  };
}
