{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;

  cfg = config.mountainous.steam.library.hybrid;

  # Build mergerfs branches string: local first (priority), then remote
  branchesStr = "${cfg.localPath}:${cfg.nfsMountPoint}";
in {
  options.mountainous.steam.library.hybrid = {
    enable = mkEnableOption "Unified Steam library with local priority via MergerFS";

    server = mkOption {
      type = types.str;
      description = "NFS server hostname for remote Steam library";
      example = "aka";
    };

    remotePath = mkOption {
      type = types.str;
      default = "/home/simonwjackson/.local/share/Steam";
      description = "Path to Steam directory on remote server";
    };

    nfsMountPoint = mkOption {
      type = types.str;
      default = "/tundra/avalanche/steam";
      description = "Mount point for NFS remote Steam library";
    };

    localPath = mkOption {
      type = types.str;
      default = "/tundra/glacier/steam";
      description = "Local Steam storage (priority over network)";
    };

    mergedPath = mkOption {
      type = types.str;
      default = "/tundra/merged/steam";
      description = "Unified merged view for Steam to use";
    };

    user = mkOption {
      type = types.str;
      default = "simonwjackson";
      description = "User that owns Steam data";
    };

    uid = mkOption {
      type = types.int;
      default = 333;
      description = "UID for file ownership";
    };

    gid = mkOption {
      type = types.int;
      default = 333;
      description = "GID for file ownership";
    };

    nfsOptions = mkOption {
      type = types.listOf types.str;
      default = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=5s"
        "soft" # Return errors instead of hanging on network issues
        "timeo=10" # 1 second timeout (in deciseconds)
        "retrans=2" # Only retry twice
        "nfsvers=4"
        "_netdev"
      ];
      description = "NFS mount options for graceful network handling";
    };

    mergerfsOptions = mkOption {
      type = types.listOf types.str;
      default = [
        "defaults"
        "allow_other"
        "use_ino"
        "category.create=ff" # First-found: write to first branch (local)
        "category.search=ff" # First-found: prefer local files
        "category.action=ff"
        "moveonenospc=true" # Move to another branch if disk full
        "dropcacheonclose=true"
        "cache.files=auto-full"
        "branches-mount-timeout=5" # Timeout for unavailable branches
        "fsname=steam-merged"
      ];
      description = "MergerFS mount options for local-priority union";
    };
  };

  config = mkIf cfg.enable {
    # Required packages
    environment.systemPackages = with pkgs; [
      nfs-utils
      mergerfs
    ];

    # Create local directories
    systemd.tmpfiles.settings."20-steam-library-hybrid" = {
      "${cfg.localPath}".d = {
        user = cfg.user;
        group = "users";
        mode = "0755";
      };
      "${cfg.localPath}/steamapps".d = {
        user = cfg.user;
        group = "users";
        mode = "0755";
      };
      "${cfg.localPath}/steamapps/common".d = {
        user = cfg.user;
        group = "users";
        mode = "0755";
      };
      "${cfg.localPath}/steamapps/compatdata".d = {
        user = cfg.user;
        group = "users";
        mode = "0755";
      };
      "${cfg.localPath}/steamapps/shadercache".d = {
        user = cfg.user;
        group = "users";
        mode = "0755";
      };
      "${cfg.nfsMountPoint}".d = {
        user = cfg.user;
        group = "users";
        mode = "0755";
      };
      "${cfg.mergedPath}".d = {
        user = cfg.user;
        group = "users";
        mode = "0755";
      };
    };

    # Mount remote Steam library via NFS with soft timeouts
    fileSystems."${cfg.nfsMountPoint}" = {
      device = "${cfg.server}:${cfg.remotePath}";
      fsType = "nfs";
      options = cfg.nfsOptions;
    };

    # MergerFS union: local (priority) + remote (fallback)
    fileSystems."${cfg.mergedPath}" = {
      device = branchesStr;
      fsType = "fuse.mergerfs";
      options = cfg.mergerfsOptions;
      depends = [cfg.nfsMountPoint];
    };

    # Note: For systems with impermanence, add cfg.localPath to your
    # environment.persistence configuration manually to persist local games
  };
}
