# Library hybrid configuration - MergerFS union of local + remote Steam library
{
  config,
  lib,
  pkgs,
  cfg,
}: let
  hcfg = cfg.library.hybrid;

  # Build mergerfs branches string: local first (priority), then remote
  branchesStr = "${hcfg.localPath}:${hcfg.nfsMountPoint}";
in {
  config = lib.mkIf hcfg.enable {
    # Required packages
    environment.systemPackages = with pkgs; [
      nfs-utils
      mergerfs
    ];

    # Create local directories
    systemd.tmpfiles.settings."20-gaming-library-hybrid" = {
      "${hcfg.localPath}".d = {
        user = hcfg.user;
        group = "users";
        mode = "0755";
      };
      "${hcfg.localPath}/steamapps".d = {
        user = hcfg.user;
        group = "users";
        mode = "0755";
      };
      "${hcfg.localPath}/steamapps/common".d = {
        user = hcfg.user;
        group = "users";
        mode = "0755";
      };
      "${hcfg.localPath}/steamapps/compatdata".d = {
        user = hcfg.user;
        group = "users";
        mode = "0755";
      };
      "${hcfg.localPath}/steamapps/shadercache".d = {
        user = hcfg.user;
        group = "users";
        mode = "0755";
      };
      "${hcfg.nfsMountPoint}".d = {
        user = hcfg.user;
        group = "users";
        mode = "0755";
      };
      "${hcfg.mergedPath}".d = {
        user = hcfg.user;
        group = "users";
        mode = "0755";
      };
    };

    # Mount remote Steam library via NFS with soft timeouts
    fileSystems."${hcfg.nfsMountPoint}" = {
      device = "${hcfg.server}:${hcfg.remotePath}";
      fsType = "nfs";
      options = hcfg.nfsOptions;
    };

    # MergerFS union: local (priority) + remote (fallback)
    fileSystems."${hcfg.mergedPath}" = {
      device = branchesStr;
      fsType = "fuse.mergerfs";
      options = hcfg.mergerfsOptions;
      depends = [hcfg.nfsMountPoint];
    };
  };
}
