{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.presets.core;
  home = config.user.home;
in {
  config = lib.mkIf cfg.enable {
    mountainous.features.syncthing.shares = {
      pi-config = {
        path = lib.mkDefault "${home}/.pi";
        ignorePatterns = lib.mkDefault [
          "**/.git"
          "**/.git/**"
          "**/node_modules"
          "**/node_modules/**"
          "**/.direnv"
          "**/.direnv/**"
          "**/.venv"
          "**/.venv/**"
          "**/venv"
          "**/venv/**"
          "**/__pycache__"
          "**/__pycache__/**"
          "**/.mypy_cache"
          "**/.mypy_cache/**"
          "**/.pytest_cache"
          "**/.pytest_cache/**"
          "**/.ruff_cache"
          "**/.ruff_cache/**"
          "**/.cache"
          "**/.cache/**"
          "**/dist"
          "**/dist/**"
          "**/build"
          "**/build/**"
          "**/result"
          "**/result/**"
          "**/tmp"
          "**/tmp/**"
          "**/.tmp"
          "**/.tmp/**"
        ];
      };
      biometrics.path = lib.mkDefault "${home}/biometrics";
      fitness.path = lib.mkDefault "${home}/fitness";
      flakey.path = lib.mkDefault "${home}/flakey";
      omi.path = lib.mkDefault "${home}/omi";
      research.path = lib.mkDefault "${home}/research";
      therapy.path = lib.mkDefault "${home}/therapy";
      transcripts.path = lib.mkDefault "${home}/transcripts";
      nutrition.path = lib.mkDefault "${home}/.local/share/nutrition";
      tasks.path = lib.mkDefault "${home}/.local/share/tasks";
    };
    mountainous.features.atuin.enable = lib.mkDefault true;
    mountainous.features.pi.enable = lib.mkDefault true;
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
