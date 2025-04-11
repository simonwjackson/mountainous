{
  config,
  lib,
  ...
}: let
  cfg = config.mountainous.impermanence;
in {
  options.mountainous.impermanence = {
    enable = lib.mkEnableOption "Enable impermanence";
    persistPath = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Path to the persistent storage directory";
    };
    rootSize = lib.mkOption {
      type = lib.types.str;
      default = "2G";
      description = "Size of the root tmpfs filesystem";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.fuse.userAllowOther = true;

    fileSystems = {
      "${cfg.persistPath}".neededForBoot = true;
    };

    environment.persistence."${cfg.persistPath}" = {
      hideMounts = true;
      directories = [
        "/var/lib/systemd/coredump"
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/fprint"
      ];
      files = [
        "/etc/machine-id"
        "/etc/adjtime"
      ];
      users."simonwjackson" = {
      # users."${config.mountainous.user.name}" = {
        files = [];
        directories = [
          ".supermaven"
          ".mozilla"
          ".config"
          ".cache"
          ".local/state"
          ".local/share"
          ".local/share/Steam"
          "Downloads"
        ];
      };
    };
  };
}
