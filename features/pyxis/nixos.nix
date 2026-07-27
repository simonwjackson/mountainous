{
  config,
  lib,
  ...
}: let
  inherit (lib) attrByPath mkIf mkMerge mkDefault optional;

  cfg = config.mountainous.features.pyxis;
  tsnetProxyEnabled = attrByPath ["mountainous" "features" "tsnet-proxy" "enable"] false config;
  hasRuntimeSecrets = cfg.sources.pandora.passwordFile != null || cfg.sources.discogs.tokenFile != null;
in {
  config = mkIf cfg.enable (mkMerge [
    {
      assertions =
        optional cfg.proxy.enable {
          assertion = tsnetProxyEnabled;
          message = "mountainous.features.pyxis requires mountainous.features.tsnet-proxy.enable = true when proxy.enable = true";
        }
        ++ optional cfg.backup.enable {
          assertion = cfg.backup.passphraseFile != null;
          message = "mountainous.features.pyxis.backup requires backup.passphraseFile";
        };

      services.pyxis = {
        enable = true;

        package = mkDefault cfg.package;
        openFirewall = mkDefault cfg.openFirewall;

        server = {
          port = mkDefault cfg.port;
          hostname = mkDefault cfg.hostname;
        };

        web.allowedHosts = mkDefault cfg.allowedHosts;

        sources = {
          pandora = {
            username = mkDefault cfg.sources.pandora.username;
            passwordFile = mkDefault cfg.sources.pandora.passwordFile;
          };

          discogs.tokenFile = mkDefault cfg.sources.discogs.tokenFile;
        };

        sonos = {
          enabled = mkDefault cfg.sonos.enable;
          lanStreamBaseUrl = mkDefault cfg.sonos.lanStreamBaseUrl;
          seedHosts = mkDefault cfg.sonos.seedHosts;
          discoveryIntervalSeconds = mkDefault cfg.sonos.discoveryIntervalSeconds;
          pollIntervalMs = mkDefault cfg.sonos.pollIntervalMs;
          requestTimeoutMs = mkDefault cfg.sonos.requestTimeoutMs;
        };

        log.level = mkDefault cfg.logLevel;
      };

      users.groups.pyxis-secrets = mkIf hasRuntimeSecrets {};
      systemd.services.pyxis.serviceConfig.SupplementaryGroups = mkIf hasRuntimeSecrets ["pyxis-secrets"];
    }

    (mkIf cfg.backup.enable {
      services.borgbackup.jobs.pyxis = {
        paths = ["/var/lib/pyxis/pyxis/db"];
        exclude = [
          "/var/lib/pyxis/pyxis/db/pyxis.db-wal"
          "/var/lib/pyxis/pyxis/db/pyxis.db-shm"
        ];
        repo = cfg.backup.repoPath;
        encryption = {
          mode = "repokey";
          passCommand = "cat ${cfg.backup.passphraseFile}";
        };
        compression = "auto,zstd";
        startAt = cfg.backup.startAt;
        prune.keep = {
          daily = 7;
          weekly = 4;
          monthly = 6;
        };
        preHook = ''
          systemctl stop pyxis.service || true
        '';
        postHook = ''
          systemctl start pyxis.service || true
        '';
      };
    })

    (mkIf cfg.proxy.enable {
      mountainous.features.tsnet-proxy.services.pyxis = {
        hostname = cfg.proxy.hostname;
        protocol = cfg.proxy.protocol;
        host = "127.0.0.1";
        port = cfg.port;
        openFirewall = cfg.proxy.openFirewall;
      };
    })
  ]);
}
