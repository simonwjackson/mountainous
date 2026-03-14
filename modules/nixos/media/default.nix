{
  config,
  lib,
  ...
}: let
  inherit (lib) listToAttrs map mkEnableOption mkIf mkOption nameValuePair optionalAttrs types;

  cfg = config.mountainous.media;

  directories = [
    cfg.root
    cfg.downloadsRoot
    cfg.usenetRoot
    cfg.usenetIncomingDir
    cfg.usenetIntermediateDir
    cfg.usenetCompletedDir
    cfg.usenetFailedDir
    "${cfg.usenetRoot}/queue"
    "${cfg.usenetRoot}/tmp"
    "${cfg.usenetRoot}/scripts"
    cfg.mediaRoot
    cfg.moviesDir
    cfg.tvDir
    cfg.musicDir
    cfg.audiobooksDir
  ];
in {
  options.mountainous.media = {
    enable = mkEnableOption "shared media and usenet storage layout";

    owner = mkOption {
      type = types.str;
      default = "root";
      description = "Owner for shared media directories.";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Shared group for media services and users.";
    };

    directoryMode = mkOption {
      type = types.str;
      default = "2775";
      description = "Mode for shared directories; setgid keeps group ownership consistent.";
    };

    root = mkOption {
      type = types.str;
      default = "/srv/storage";
      description = "Root directory used by media services on this host.";
    };

    downloadsRoot = mkOption {
      type = types.str;
      default = "${cfg.root}/downloads";
      description = "Root directory for downloader payloads.";
    };

    usenetRoot = mkOption {
      type = types.str;
      default = "${cfg.downloadsRoot}/usenet";
      description = "Root directory for Usenet downloads and work directories.";
    };

    usenetIncomingDir = mkOption {
      type = types.str;
      default = "${cfg.usenetRoot}/incoming";
      description = "Directory watched for incoming NZB files.";
    };

    usenetIntermediateDir = mkOption {
      type = types.str;
      default = "${cfg.usenetRoot}/intermediate";
      description = "Working directory for active Usenet downloads and unpacking.";
    };

    usenetCompletedDir = mkOption {
      type = types.str;
      default = "${cfg.usenetRoot}/completed";
      description = "Directory for completed Usenet downloads before import.";
    };

    usenetFailedDir = mkOption {
      type = types.str;
      default = "${cfg.usenetRoot}/failed";
      description = "Directory for failed Usenet downloads and leftovers worth reviewing.";
    };

    mediaRoot = mkOption {
      type = types.str;
      default = "${cfg.root}/media";
      description = "Root directory for served media libraries.";
    };

    moviesDir = mkOption {
      type = types.str;
      default = "${cfg.mediaRoot}/movies";
      description = "Shared movies library path.";
    };

    tvDir = mkOption {
      type = types.str;
      default = "${cfg.mediaRoot}/tv";
      description = "Shared TV library path.";
    };

    musicDir = mkOption {
      type = types.str;
      default = "${cfg.mediaRoot}/music";
      description = "Shared music library path.";
    };

    audiobooksDir = mkOption {
      type = types.str;
      default = "${cfg.mediaRoot}/audiobooks";
      description = "Shared audiobooks library path.";
    };
  };

  config = mkIf cfg.enable {
    users.groups = optionalAttrs (cfg.group == "media") {
      media = {};
    };

    systemd.tmpfiles.settings."10-mountainous-media" = listToAttrs (
      map (path:
        nameValuePair path {
          d = {
            user = cfg.owner;
            group = cfg.group;
            mode = cfg.directoryMode;
          };
        })
      directories
    );
  };
}
