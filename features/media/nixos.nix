{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatMapStringsSep listToAttrs map mkAfter mkIf mkMerge nameValuePair optional optionalAttrs unique;
  cfg = config.mountainous.features.media;
  tieringCfg = config.mountainous.features.media-tiering;

  # Only create local, authoritative storage paths here.
  # App-facing range mountpoints (for example /srv/range/media/{movies,tv})
  # are owned by the media-tiering module.
  localMoviesDir = "${cfg.mediaRoot}/movies";
  localTvDir = "${cfg.mediaRoot}/tv";
  localMusicDir = "${cfg.mediaRoot}/music";
  localAudiobooksDir = "${cfg.mediaRoot}/audiobooks";

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
    localMoviesDir
    localTvDir
    localMusicDir
    localAudiobooksDir
  ];

  normalizationRoots = unique directories;

  permissionsNormalizeScript = pkgs.writeShellScript "mountainous-media-normalize-permissions" ''
        set -euo pipefail

        normalize_root() {
          local root="$1"

          if ! [ -e "$root" ]; then
            return 0
          fi

          # Stay on the current filesystem for each managed root so we do not walk
          # into nested mountpoints such as NFS peer mounts or range mergerfs views.
          ${pkgs.findutils}/bin/find "$root" -xdev \( -type d -o -type f \) -exec ${pkgs.coreutils}/bin/chgrp ${lib.escapeShellArg cfg.group} {} +
          ${pkgs.findutils}/bin/find "$root" -xdev \( -type d -o -type f \) -exec ${pkgs.coreutils}/bin/chmod g+rwX {} +
          ${pkgs.findutils}/bin/find "$root" -xdev -type d -exec ${pkgs.coreutils}/bin/chmod g+s {} +
        }

    ${concatMapStringsSep "\n" (path: "    normalize_root ${lib.escapeShellArg path}") normalizationRoots}
  '';
in {
  config = mkIf cfg.enable (mkMerge [
    {
      assertions = optional tieringCfg.enable {
        assertion = cfg.group == "media";
        message = ''
          mountainous.features.media-tiering relies on the shared `media` group
          identity from mountainous.features.media.gid rather than per-service
          UID parity across hosts. Keep mountainous.features.media.group =
          "media" on tiered hosts.
        '';
      };

      users.groups = optionalAttrs (cfg.group == "media") {
        media = {
          gid = cfg.gid;
        };
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

      systemd.services.mountainous-media-normalize-permissions = {
        description = "Normalize ownership and group-write permissions for local managed media paths";
        after = ["local-fs.target" "systemd-tmpfiles-setup.service"];
        wants = ["systemd-tmpfiles-setup.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = permissionsNormalizeScript;
        };
      };

      systemd.timers.mountainous-media-normalize-permissions = {
        description = "Periodically normalize permissions for local managed media paths";
        wantedBy = ["timers.target"];
        timerConfig = {
          Unit = "mountainous-media-normalize-permissions.service";
          OnBootSec = "15min";
          OnUnitActiveSec = "6h";
          RandomizedDelaySec = "5min";
          Persistent = true;
        };
      };
    }

    (mkIf (config.mountainous.features.jellyfin.enable or false) {
      systemd.services.jellyfin = {
        after = mkAfter ["mountainous-media-normalize-permissions.service"];
        wants = ["mountainous-media-normalize-permissions.service"];
      };
    })

    (mkIf (config.mountainous.features.radarr.enable or false) {
      systemd.services.radarr = {
        after = mkAfter ["mountainous-media-normalize-permissions.service"];
        wants = ["mountainous-media-normalize-permissions.service"];
      };
    })

    (mkIf (config.mountainous.features.sonarr.enable or false) {
      systemd.services.sonarr = {
        after = mkAfter ["mountainous-media-normalize-permissions.service"];
        wants = ["mountainous-media-normalize-permissions.service"];
      };
    })

    (mkIf (config.mountainous.features.nzbget.enable or false) {
      systemd.services.nzbget = {
        after = mkAfter ["mountainous-media-normalize-permissions.service"];
        wants = ["mountainous-media-normalize-permissions.service"];
      };
    })

    (mkIf (config.mountainous.features.transmission.enable or false) {
      systemd.services.transmission = {
        after = mkAfter ["mountainous-media-normalize-permissions.service"];
        wants = ["mountainous-media-normalize-permissions.service"];
      };
    })
  ]);
}
