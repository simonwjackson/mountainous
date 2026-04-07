{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.mountainous.features.media-tiering;
  mediaCfg = config.mountainous.features.media;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.media-tiering = {
    enable = mkEnableOption "tier media between hosts while preserving stable library paths";

    role = mkOption {
      type = types.enum ["source" "sink"];
      description = ''
        source = writable ingest host that evacuates older media to its peer.
        sink   = storage host that exports writable backing storage to the source.
      '';
    };

    peerHost = mkOption {
      type = types.str;
      description = "Peer hostname used for the cross-host NFS mount.";
    };

    localBackingRoot = mkOption {
      type = types.str;
      default = "${mediaCfg.root}/media";
      description = "Local backing root that stores this host's physical movie and TV files (basin media layer).";
    };

    peerMountRoot = mkOption {
      type = types.str;
      default = "/net/mountainous/${cfg.peerHost}/media";
      description = "Where the peer host's backing media export is mounted.";
    };

    localSources = {
      movies = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional existing local movies directory to bind into the backing namespace.";
      };

      tv = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional existing local TV directory to bind into the backing namespace.";
      };
    };

    nfs = {
      clients = mkOption {
        type = types.str;
        default = "100.64.0.0/10";
        description = "Client CIDR allowed to mount the backing export.";
      };

      anonuid = mkOption {
        type = types.int;
        default = 0;
        description = "UID that all NFS clients are mapped to (all_squash).";
      };

      anongid = mkOption {
        type = types.int;
        default = 0;
        description = "GID that all NFS clients are mapped to (all_squash).";
      };
    };

    mover = {
      enable = mkEnableOption "media mover automation for the source host";

      nightlySchedule = mkOption {
        type = types.str;
        default = "*-*-* 03:00:00 America/Denver";
        description = "systemd OnCalendar expression for the nightly full move run.";
      };

      lowSpaceCheckInterval = mkOption {
        type = types.str;
        default = "5min";
        description = "How often to check for low space on the source backing filesystem.";
      };

      minFreePercent = mkOption {
        type = types.int;
        default = 20;
        description = "Run low-space evacuation when free space is at or below this percentage.";
      };

      minAgeMinutes = mkOption {
        type = types.int;
        default = 60;
        description = "Only move files older than this many minutes.";
      };

      jellyfin = {
        host = mkOption {
          type = types.str;
          default = cfg.peerHost;
          description = "Jellyfin host to refresh after successful move batches.";
        };

        username = mkOption {
          type = types.str;
          default = "simonwjackson";
          description = "Jellyfin username used for refresh authentication.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Secret file containing the Jellyfin password.";
        };
      };
    };
  };
}
