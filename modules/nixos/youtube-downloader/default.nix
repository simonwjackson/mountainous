{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.youtube-dl-subscriptions;

  subscriptionsFile =
    if cfg.subscriptions == null
    then "${cfg.dataDir}/subscriptions.txt"
    else if builtins.isList cfg.subscriptions
    then pkgs.writeText "subscriptions.txt" (lib.concatStringsSep "\n" cfg.subscriptions)
    else cfg.subscriptions;

  archiveFile =
    if cfg.archive == null
    then "${cfg.dataDir}/archive.txt"
    else cfg.archive;

  downloadDir =
    if cfg.tmpDir == null
    then cfg.dataDir
    else cfg.tmpDir;
in {
  options.services.youtube-dl-subscriptions = {
    enable = lib.mkEnableOption "YouTube-DL subscriptions service";

    user = lib.mkOption {
      type = lib.types.str;
      default = "youtube-dl";
      description = "User account under which the service runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "youtube-dl";
      description = "Group under which the service runs.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;

      default = "/var/lib/youtube-downloader";
      description = "Directory to store YouTube-DL data.";
    };

    tmpDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Temporary directory for downloads. If null, downloads directly to dataDir.";
      example = "/tmp/youtube-dl-downloads";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/30";
      description = "Systemd calendar expression for how often to run the service.";
    };

    subscriptions = lib.mkOption {
      type = lib.types.nullOr (lib.types.either (lib.types.listOf lib.types.str) lib.types.path);
      default = null;
      description = "List of subscriptions, path to subscriptions file, or null to use default file.";
      example = [
        "https://www.youtube.com/user/example1"
        "https://www.youtube.com/user/example2"
      ];
    };

    archive = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the archive file. If null, defaults to `dataDir`/archive.txt";
      example = "/path/to/your/archive.txt";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra arguments to pass to yt-dlp";
      example = ["--embed-thumbnail" "--write-auto-sub"];
    };

    fileTemplate = lib.mkOption {
      type = lib.types.str;
      default = "%(uploader)s/%(upload_date>%Y-%m-%d)s - %(title).220B.%(ext)s";
      description = "Output filename template. If null, defaults to '%(uploader)s/%(title)s.%(ext)s'";
      example = "%(upload_date)s-%(title)s.%(ext)s";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.youtube-dl-subscriptions = {
      description = "Download latest video from YouTube subscriptions";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = let
          inherit (pkgs) writeShellScript yt-dlp;
        in "${writeShellScript "youtube-downloader"
          # bash
          ''
            ${yt-dlp}/bin/yt-dlp \
              --ignore-errors \
              --no-overwrites \
              --verbose \
              ${toString cfg.extraArgs} \
              --download-archive ${archiveFile} \
              --output '${downloadDir}/${cfg.fileTemplate}' \
              --batch-file ${subscriptionsFile}

            ${lib.optionalString (cfg.tmpDir != null)
              # bash
              ''
                # Clean up any empty directories in the temp folder
                find ${cfg.tmpDir} -type d -empty -delete
              ''}
          ''}";
        # --replace-in-metadata "uploader" "[^\w\s\-]" "" \
        # --replace-in-metadata "title" "[^\w\s\-]" "" \
        # --exec "${pkgs.coreutils}/bin/mkdir -p '${cfg.dataDir}/$(${pkgs.coreutils}/bin/dirname $(echo '${downloadDir}/${cfg.fileTemplate}' | ${pkgs.gnused}/bin/sed 's|^${downloadDir}/||'))' && ${pkgs.coreutils}/bin/mv -f '${downloadDir}/${cfg.fileTemplate}' '${cfg.dataDir}/$(${pkgs.coreutils}/bin/dirname $(echo '${downloadDir}/${cfg.fileTemplate}' | ${pkgs.gnused}/bin/sed 's|^${downloadDir}/||'))/'" \
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
      };
    };

    systemd.timers.youtube-dl-subscriptions = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.interval;
        Unit = "youtube-dl-subscriptions.service";
      };
    };

    users.groups.${cfg.group} = {};

    system.activationScripts = {
      youtube-dl-setup = ''
        ${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}
        ${pkgs.coreutils}/bin/chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}

        ${lib.optionalString (cfg.tmpDir != null) "${pkgs.coreutils}/bin/mkdir -p ${cfg.tmpDir}"}
        ${lib.optionalString (cfg.tmpDir != null) "${pkgs.coreutils}/bin/chown -R ${cfg.user}:${cfg.group} ${cfg.tmpDir}"}

        ${lib.optionalString (cfg.archive == null) "${pkgs.coreutils}/bin/touch ${archiveFile}"}
        ${lib.optionalString (cfg.archive != null) "${pkgs.coreutils}/bin/chown ${cfg.user}:${cfg.group} ${cfg.archive}"}

        ${lib.optionalString (cfg.subscriptions == null) "${pkgs.coreutils}/bin/touch ${subscriptionsFile}"}

      '';
    };
  };
}
