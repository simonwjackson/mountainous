{
  config,
  lib,
  ...
}: let
  inherit (lib) listToAttrs map mkIf nameValuePair optionalAttrs;
  cfg = config.mountainous.features.media;

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
    cfg.torrentsRoot
    cfg.torrentsCompletedDir
    cfg.torrentsIncompleteDir
    cfg.torrentsWatchDir
    cfg.mediaRoot
    cfg.moviesDir
    cfg.tvDir
    cfg.musicDir
    cfg.audiobooksDir
  ];
in {
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
