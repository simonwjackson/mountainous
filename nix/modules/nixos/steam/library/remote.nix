{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.steam.library.remote;
in {
  options.mountainous.steam.library.remote = {
    enable = mkEnableOption "Mount remote Steam library via NFS";

    server = mkOption {
      type = types.str;
      description = "NFS server hostname (e.g., Tailscale DNS name)";
      example = "aka";
    };

    remotePath = mkOption {
      type = types.str;
      default = "/home/simonwjackson/.local/share/Steam";
      description = "Path to Steam directory on remote server";
    };

    mountPoint = mkOption {
      type = types.str;
      default = "/tundra/avalanche/steam";
      description = "Local mount point for remote Steam library";
    };

    user = mkOption {
      type = types.str;
      default = "simonwjackson";
      description = "User that owns local Steam data";
    };

    localCompatdataPath = mkOption {
      type = types.str;
      default = "/home/simonwjackson/.local/share/Steam/steamapps/compatdata";
      description = "Local path for Proton compatibility data (kept local per machine)";
    };

    localShadercachePath = mkOption {
      type = types.str;
      default = "/home/simonwjackson/.local/share/Steam/steamapps/shadercache";
      description = "Local path for shader cache (kept local per machine)";
    };

    nfsOptions = mkOption {
      type = types.listOf types.str;
      default = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=5s"
        "soft"
        "timeo=14"
        "nfsvers=4"
      ];
      description = "NFS mount options";
    };
  };

  config = mkIf cfg.enable {
    # NFS client utilities
    environment.systemPackages = with pkgs; [
      nfs-utils
    ];

    # Mount remote Steam library via NFS with automount
    fileSystems."${cfg.mountPoint}" = {
      device = "${cfg.server}:${cfg.remotePath}";
      fsType = "nfs";
      options = cfg.nfsOptions;
    };

    # Create local directories for machine-specific data
    systemd.tmpfiles.settings."20-steam-library-remote" = {
      "${cfg.localCompatdataPath}".d = {
        user = cfg.user;
        group = "users";
        mode = "0755";
      };
      "${cfg.localShadercachePath}".d = {
        user = cfg.user;
        group = "users";
        mode = "0755";
      };
    };

    # Note: For impermanence, add localCompatdataPath and localShadercachePath
    # to your environment.persistence configuration manually
  };
}
