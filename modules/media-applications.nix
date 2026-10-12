# Application state is transferred before activation. Never seed fresh settings.
{ inputs, ... }:
{
  nixos.modules.media-applications =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.media-applications;
      media = import inputs.nixpkgs-media {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
      apps = [
        "sonarr"
        "radarr"
        "prowlarr"
        "nzbget"
        "transmission"
      ];
      present = name: cfg.placement.${name} == config.networking.hostName;
      held = cfg.processing != "enabled";
      importsOnly = cfg.processing == "imports-only";
      nzbPaths = {
        MainDir = "/srv/basin/downloads/usenet";
        DestDir = "/srv/basin/downloads/usenet/completed";
        InterDir = "/srv/basin/downloads/usenet/intermediate";
        NzbDir = "/srv/basin/downloads/usenet/incoming";
        QueueDir = "/srv/basin/downloads/usenet/queue";
        TempDir = "/srv/basin/downloads/usenet/tmp";
        ScriptDir = "/srv/basin/downloads/usenet/scripts";
        RequiredDir = "/srv/basin/downloads/usenet/completed,/srv/basin/downloads/usenet/intermediate";
        ControlIP = "0.0.0.0";
        ControlPort = "6789";
        UMask = "0002";
        OutputMode = "loggable";
        ArticleCache = "500";
        WriteBuffer = "1024";
        DirectUnpack = "yes";
        # Retained ARR client categories. The small saved config only contains
        # secrets; native defaults must not erase the public integration contract.
        "Category1.Name" = "Movies";
        "Category2.Name" = "Series";
        "Server1.Name" = "newsdemon";
        "Server1.Host" = "news.newsdemon.com";
        "Server1.Port" = "563";
        "Server1.Encryption" = "yes";
        "Server1.Connections" = "50";
        WebDir = "${media.nzbget}/share/nzbget/webui";
        UnrarCmd = "${media.unrar}/bin/unrar";
        SevenZipCmd = "${media.p7zip}/bin/7z";
      };
      nzbFlags = lib.concatStringsSep " " (
        lib.mapAttrsToList (name: value: "--option ${lib.escapeShellArg "${name}=${value}"}") nzbPaths
      );
      configs = {
        sonarr = "/var/lib/sonarr/.config/NzbDrone/config.xml";
        radarr = "/var/lib/radarr/.config/Radarr/config.xml";
        prowlarr = "/var/lib/prowlarr/config.xml";
        nzbget = "/var/lib/nzbget/nzbget.conf";
        transmission = "/var/lib/transmission/.config/transmission-daemon/settings.json";
      };
      databases = {
        sonarr = "/var/lib/sonarr/.config/NzbDrone/sonarr.db";
        radarr = "/var/lib/radarr/.config/Radarr/radarr.db";
        prowlarr = "/var/lib/prowlarr/prowlarr.db";
      };
    in
    {
      options.mountainous.features.media-applications = {
        enable = lib.mkEnableOption "state-preserving portable media applications";
        placement = lib.mkOption {
          type = lib.types.submodule {
            options = lib.genAttrs apps (
              _:
              lib.mkOption {
                type = lib.types.str;
                default = "unzen";
              }
            );
          };
          default = { };
          description = "Host assignment; application settings and state paths do not change.";
        };
        processing = lib.mkOption {
          type = lib.types.enum [
            "held"
            "imports-only"
            "arr-enabled"
            "enabled"
          ];
          default = "held";
          description = "Verification starts held. Imports-only holds automatic imports, removal, indexers, schedules and downloaders. Arr-enabled restores ARR processing while downloader launches and mover timers stay held. Enabled restores normal processing after approved acceptance.";
        };
        processingReceipts = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/media-migration/processing-original-safe";
          description = "Protected original processing receipts used to admit imports-only startup.";
        };
        mediaGid = lib.mkOption {
          type = lib.types.ints.positive;
          description = "Explicit shared media GID, checked against the host before activation. Map transferred ownership deliberately.";
        };
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = lib.all (name: cfg.placement ? ${name}) apps;
            message = "Media placement must explicitly assign all five applications.";
          }
        ];
        users.groups.media.gid = cfg.mediaGid;
        services = {
          sonarr = {
            enable = present "sonarr";
            package = media.sonarr;
            group = "media";
            dataDir = "/var/lib/sonarr/.config/NzbDrone";
          };
          radarr = {
            enable = present "radarr";
            package = media.radarr;
            group = "media";
            dataDir = "/var/lib/radarr/.config/Radarr";
          };
          prowlarr = {
            enable = present "prowlarr";
            package = media.prowlarr;
          };
          nzbget = {
            enable = present "nzbget";
            package = media.nzbget;
            group = "media";
          };
          transmission = {
            enable = present "transmission";
            package = media.transmission_4;
            group = "media";
            home = "/var/lib/transmission";
            extraFlags = lib.optionals held [
              "--paused"
              "--no-watch-dir"
            ];
            # These paths govern the sandbox, not the transferred settings file.
            settings = {
              download-dir = "/srv/basin/downloads/torrents/completed";
              incomplete-dir = "/srv/basin/downloads/torrents/incomplete";
              watch-dir = "/srv/basin/downloads/torrents/watch";
            };
            downloadDirPermissions = null;
          };
        };
        systemd.services = lib.mkMerge [
          (lib.genAttrs (lib.filter present apps) (name: {
            # Both conditions must pass. Missing state never starts a setup wizard.
            unitConfig = {
              ConditionPathExists = "/var/lib/media-migration/ready/${name}";
              ConditionFileNotEmpty = [ configs.${name} ] ++ lib.optional (databases ? ${name}) databases.${name};
            };
            preStart = lib.mkBefore ''
              ${pkgs.python3}/bin/python3 ${./media-state-ready.py} ${name} ${
                lib.optionalString (
                  databases ? ${name} && (cfg.processing == "held" || (importsOnly && name == "prowlarr"))
                ) "--hold"
              }
            '';
            serviceConfig = {
              UMask = lib.mkForce "0002";
              # Receipts remain root-only. Only this read-only admission runs
              # as root; the application keeps its existing service user.
              ExecStartPre = lib.mkBefore (
                lib.optional
                  (
                    importsOnly
                    && builtins.elem name [
                      "sonarr"
                      "radarr"
                    ]
                  )
                  "+${pkgs.python3}/bin/python3 ${./media-state-ready.py} ${name} --imports-only ${lib.escapeShellArg "${cfg.processingReceipts}/${name}.json"}"
                ++
                  lib.optional
                    (
                      databases ? ${name}
                      && builtins.elem cfg.processing [
                        "arr-enabled"
                        "enabled"
                      ]
                    )
                    "+${pkgs.python3}/bin/python3 ${./media-state-ready.py} ${name} --enabled ${lib.escapeShellArg "${cfg.processingReceipts}/${name}.json"}"
              );
            };
          }))
          {
            nzbget = lib.mkIf (present "nzbget") {
              path = lib.mkForce [
                media.unrar
                media.p7zip
              ];
              preStart = lib.mkForce ''
                ${pkgs.python3}/bin/python3 ${./media-state-ready.py} nzbget
              '';
              serviceConfig.ExecStart = lib.mkForce "${pkgs.python3}/bin/python3 ${./media-nzbget-launch.py} ${media.nzbget}/bin/nzbget ${
                if held then "held" else "enabled"
              } /var/lib/nzbget/nzbget.conf ${nzbFlags}";
              serviceConfig.ExecStop = lib.mkForce "${media.nzbget}/bin/nzbget --quit --configfile /var/lib/nzbget/nzbget.conf";
            };
            transmission = lib.mkIf (present "transmission") {
              # Current upstream regenerates settings.json. Keep the complete
              # transferred file, including credentials and non-Nix UI settings.
              serviceConfig.ExecStartPre = lib.mkForce [
                "${pkgs.python3}/bin/python3 ${./media-state-ready.py} transmission"
              ];
              serviceConfig.BindPaths = lib.mkAfter [ "/srv/basin/downloads/torrents" ];
            };
          }
        ];
        systemd.tmpfiles.rules = [
          "d /var/lib/media-migration 0700 root root -"
          "d /var/lib/media-migration/ready 0700 root root -"
        ];
      };
    };
}
