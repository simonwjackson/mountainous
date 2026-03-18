{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.borgbackup = {
    enable = mkEnableOption "Borg backup jobs with offsite and cloud sync";

    user = mkOption {
      type = types.str;
      default = "simonwjackson";
      description = "User to run backup jobs as.";
    };

    passphraseFile = mkOption {
      type = types.path;
      description = "Path to file containing the borg repo passphrase (agenix secret).";
    };

    repoBase = mkOption {
      type = types.str;
      default = "/var/lib/borg";
      description = "Base directory for local borg repositories.";
    };

    offsiteSync = {
      enable = mkEnableOption "rsync borg repos to remote hosts";

      schedule = mkOption {
        type = types.str;
        default = "*-*-* 04:00:00";
        description = "Systemd OnCalendar expression for offsite sync.";
      };

      targets = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [
          "aka:/tundra/merged/iceberg/backups"
          "yari:/var/lib/borg-mirror"
        ];
        description = ''
          Remote rsync targets. Each entry is <host>:<base-path>.
          Repos are synced to <base-path>/<hostname>/<repo-name>/.
        '';
      };
    };

    cloudSync = {
      enable = mkEnableOption "rclone borg repos to cloud storage";

      schedule = mkOption {
        type = types.str;
        default = "*-*-* 04:30:00";
        description = "Systemd OnCalendar expression for cloud sync.";
      };

      remotes = mkOption {
        type = types.listOf types.str;
        default = ["dropbox" "gdrive"];
        description = "rclone remote names to sync to. Repos go to <remote>:backups/<hostname>/<repo>/.";
      };
    };
  };
}
