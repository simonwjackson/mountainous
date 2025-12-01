# Library remote configuration - NFS mount for remote Steam library
{
  config,
  lib,
  pkgs,
  cfg,
}: let
  rcfg = cfg.library.remote;
in {
  config = lib.mkIf rcfg.enable {
    # NFS client utilities
    environment.systemPackages = with pkgs; [
      nfs-utils
    ];

    # Mount remote Steam library via NFS with automount
    fileSystems."${rcfg.mountPoint}" = {
      device = "${rcfg.server}:${rcfg.remotePath}";
      fsType = "nfs";
      options = rcfg.nfsOptions;
    };

    # Create local directories for machine-specific data
    systemd.tmpfiles.settings."20-gaming-library-remote" = {
      "${rcfg.localCompatdataPath}".d = {
        user = rcfg.user;
        group = "users";
        mode = "0755";
      };
      "${rcfg.localShadercachePath}".d = {
        user = rcfg.user;
        group = "users";
        mode = "0755";
      };
    };
  };
}
