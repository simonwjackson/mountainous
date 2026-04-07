{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.features.media;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.media = {
    enable = mkEnableOption "shared media, usenet, and torrent storage layout";

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
      default = "/srv/basin";
      description = "Root directory for this host's physical media and download storage.";
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

    torrentsRoot = mkOption {
      type = types.str;
      default = "${cfg.downloadsRoot}/torrents";
      description = "Root directory for torrent downloads and work directories.";
    };

    torrentsCompletedDir = mkOption {
      type = types.str;
      default = "${cfg.torrentsRoot}/completed";
      description = "Directory for completed torrent payloads before import.";
    };

    torrentsIncompleteDir = mkOption {
      type = types.str;
      default = "${cfg.torrentsRoot}/incomplete";
      description = "Directory for active and partial torrent downloads.";
    };

    torrentsWatchDir = mkOption {
      type = types.str;
      default = "${cfg.torrentsRoot}/watch";
      description = "Directory watched for incoming .torrent files.";
    };

    mediaRoot = mkOption {
      type = types.str;
      default = "${cfg.root}/media";
      description = "Root directory for this host's physical media libraries (basin layer).";
    };

    # ── Range layer (app-visible, potentially merged across hosts) ────

    rangeRoot = mkOption {
      type = types.str;
      default = "/srv/range";
      description = ''
        Root of the app-visible merged media layer.
        When media-tiering is enabled, mergerfs mounts the union of local
        basin media and remote peer media here.  When tiering is not
        enabled, services that reference the range paths should override
        moviesDir / tvDir to point back to the basin.
      '';
    };

    rangeMoviesDir = mkOption {
      type = types.str;
      default = "${cfg.rangeRoot}/media/movies";
      description = "Merged movies library path (range layer).";
    };

    rangeTvDir = mkOption {
      type = types.str;
      default = "${cfg.rangeRoot}/media/tv";
      description = "Merged TV library path (range layer).";
    };

    # ── App-facing library paths ─────────────────────────────────────
    # These are what Radarr, Sonarr, Jellyfin, etc. actually use.
    # They default to the range (merged) layer so apps automatically
    # see the cross-host union when media-tiering is active.

    moviesDir = mkOption {
      type = types.str;
      default = cfg.rangeMoviesDir;
      description = "Movies library path used by media services.";
    };

    tvDir = mkOption {
      type = types.str;
      default = cfg.rangeTvDir;
      description = "TV library path used by media services.";
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
}
