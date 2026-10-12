# One protected saved tsnet identity per independently placed application.
{ inputs, ... }:
{
  nixos.modules.media-identities =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.media-identities;
      placement = config.mountainous.features.media-applications.placement;
      apps = [
        "sonarr"
        "radarr"
        "prowlarr"
        "nzbget"
        "transmission"
      ];
      here = lib.filter (
        name:
        placement.${name} == config.networking.hostName
        && (name != "nzbget" || config.mountainous.features.media-applications.usenet != "nzbfast")
      ) apps;
      vpnApps = [
        "nzbfast"
        "nzbget"
        "transmission"
        "prowlarr"
      ];
      names = {
        sonarr = "tv";
        radarr = "movies";
        prowlarr = "indexers";
        nzbget = "usenet";
        transmission = "torrents";
      };
      ports = {
        sonarr = 8989;
        radarr = 7878;
        prowlarr = 9696;
        nzbget = 6789;
        nzbfast = 6790;
        transmission = 9091;
      };
      proxy = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.media-tsnet-proxy;
    in
    {
      options.mountainous.features.media-identities = {
        enable = lib.mkEnableOption "protected OAuth-backed media service identities";
        tags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "tag:mountainous" ];
        };
        oauthIdFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = config.mountainous.tailscale.oauthClientIdFile;
        };
        oauthSecretFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = config.mountainous.tailscale.oauthSecretFile;
        };
      };
      config = lib.mkMerge [
        (lib.mkIf config.services.nzbfast.enable {
          # 391 is free in the host and nixpkgs static UID registry; media is 390.
          # No new tsnet identity: the existing usenet identity stays on NZBGet.
          users.users.nzbfast.uid = 391;
        })
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = cfg.oauthIdFile != null && cfg.oauthSecretFile != null && cfg.tags != [ ];
              message = "Media identities require existing OAuth credential files and enrollment tags.";
            }
            {
              assertion = config.mountainous.features.media-runtime.enable;
              message = "Media identities require the protected runtime and storage layer.";
            }
          ];
          users.groups.media-proxy = { };
          users.users.media-proxy = {
            isSystemUser = true;
            group = "media-proxy";
            home = "/var/empty";
          };
          systemd.services = lib.listToAttrs (
            map (
              name:
              let
                directory = "/var/lib/tsnet-proxy-${name}";
                state = "${directory}/.config/tsnet-tsnet-proxy";
                backend = if builtins.elem name vpnApps then "10.200.200.2" else "127.0.0.1";
              in
              lib.nameValuePair "tsnet-proxy-${name}" {
                description = "Preserved ${names.${name}} media identity";
                wantedBy = [ "multi-user.target" ];
                wants = [
                  "network-online.target"
                  "${name}.service"
                ];
                after = [
                  "network-online.target"
                  "${name}.service"
                ];
                unitConfig = {
                  ConditionPathExists = "/var/lib/media-migration/ready/${name}";
                  ConditionFileNotEmpty = "${state}/tailscaled.state";
                };
                serviceConfig = {
                  User = "media-proxy";
                  Group = "media-proxy";
                  StateDirectory = "tsnet-proxy-${name}";
                  StateDirectoryMode = "0700";
                  UMask = "0077";
                  LoadCredential = [
                    "oauth-id:${cfg.oauthIdFile}"
                    "oauth-secret:${cfg.oauthSecretFile}"
                  ];
                  ExecStart =
                    "${proxy}/bin/tsnet-proxy -hostname ${names.${name}} -state ${state}"
                    + " -backend http://${backend}:${toString ports.${name}} -port 443"
                    + " -oauth-id-file %d/oauth-id -oauth-secret-file %d/oauth-secret"
                    + " -tags ${lib.concatStringsSep "," cfg.tags}";
                  Restart = "on-failure";
                  RestartSec = "30s";
                  NoNewPrivileges = true;
                  ProtectSystem = "strict";
                  ProtectHome = true;
                  PrivateTmp = true;
                  PrivateDevices = true;
                  ProtectKernelTunables = true;
                  ProtectKernelModules = true;
                  ProtectControlGroups = true;
                  RestrictSUIDSGID = true;
                  RestrictAddressFamilies = [
                    "AF_INET"
                    "AF_INET6"
                    "AF_UNIX"
                    "AF_NETLINK"
                  ];
                };
              }
            ) here
          );
        })
      ];
    };
}
