{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.youtube-dl-subscriptions;

  subscriptionsFile =
    if builtins.isList cfg.subscriptions
    then pkgs.writeText "youtube-dl-subscriptions.txt" (lib.concatStringsSep "\n" cfg.subscriptions)
    else cfg.subscriptions;

  archiveFile =
    if cfg.archive == null
    then "${cfg.dataDir}/archive.txt"
    else cfg.archive;

  fileTemplate =
    if cfg.fileTemplate == null
    then "%(uploader)s/%(title)s.%(ext)s"
    else cfg.fileTemplate;
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
      default = "/var/lib/youtube-dl";
      description = "Directory to store YouTube-DL data.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/30";
      description = "Systemd calendar expression for how often to run the service.";
    };

    subscriptions = lib.mkOption {
      type = lib.types.either (lib.types.listOf lib.types.str) lib.types.path;
      description = "List of subscriptions or path to subscriptions file.";
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
      type = lib.types.nullOr lib.types.str;
      default = null;
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
        in "${writeShellScript "youtube-dl-script" ''
          ${yt-dlp}/bin/yt-dlp \
            --ignore-errors \
            --no-overwrites \
            --playlist-end 1 \
            --download-archive ${archiveFile} \
            -o '${cfg.dataDir}/${fileTemplate}' \
            --batch-file ${subscriptionsFile} \
            ${lib.escapeShellArgs cfg.extraArgs}
        ''}";
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

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = {};

    system.activationScripts = {
      youtube-dl-setup = ''
        mkdir -p ${cfg.dataDir}
        ${lib.optionalString (cfg.archive == null) "touch ${archiveFile}"}
        chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
        ${lib.optionalString (cfg.archive != null) "chown ${cfg.user}:${cfg.group} ${cfg.archive}"}
      '';
    };
  };
}
