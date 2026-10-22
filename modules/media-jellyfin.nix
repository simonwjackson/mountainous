# Jellyfin on the library host, moved from Zao with its state and its
# tailnet identity (watch.<tailnet>). The release stays on the pinned media
# nixpkgs: a move is not a schema upgrade.
#
# The service is held until its migrated state is admitted
# (/var/lib/media-migration/ready/jellyfin), and it stops with the media
# storage guard like every other library consumer.
{ inputs, ... }:
{
  nixos.modules.media-jellyfin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.media-jellyfin;
      media = import inputs.nixpkgs-media { system = pkgs.stdenv.hostPlatform.system; };
      identities = config.mountainous.features.media-identities;
      proxy = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.media-tsnet-proxy;
      ready = "/var/lib/media-migration/ready/jellyfin";
      directory = "/var/lib/tsnet-proxy-jellyfin";
      state = "${directory}/.config/tsnet-tsnet-proxy";
    in
    {
      options.mountainous.features.media-jellyfin = {
        enable = lib.mkEnableOption "Jellyfin on the library host";
        hostname = lib.mkOption {
          type = lib.types.str;
          default = "watch";
          description = "Preserved tailnet name of the moved identity.";
        };
        lanAccess = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open port 8096 on the LAN for clients without Tailscale, such as the TV.";
        };
        renderDevice = lib.mkOption {
          type = lib.types.str;
          default = "/dev/dri/renderD128";
        };
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.mountainous.features.media-runtime.enable && identities.enable;
            message = "Jellyfin needs the media runtime and the media identity credentials.";
          }
        ];

        # Intel Quick Sync through the iHD driver. The legacy compute runtime
        # supplies OpenCL for HDR tone mapping on Gen9 to Gen11 graphics.
        hardware.graphics = {
          enable = true;
          extraPackages = [
            pkgs.intel-media-driver
            pkgs.intel-compute-runtime-legacy1
          ];
        };

        services.jellyfin = {
          enable = true;
          package = media.jellyfin;
          group = "media";
          openFirewall = cfg.lanAccess;
          hardwareAcceleration = {
            enable = true;
            type = "qsv";
            device = cfg.renderDevice;
          };
          # Declared encoding settings replace the migrated software-only ones.
          forceEncodingConfig = true;
          transcoding = {
            enableHardwareEncoding = true;
            enableToneMapping = true;
            # UHD 630 decodes these in hardware. AV1 falls back to the CPU.
            hardwareDecodingCodecs = {
              h264 = true;
              hevc = true;
              hevc10bit = true;
              vp9 = true;
              mpeg2 = true;
              vc1 = true;
            };
            hardwareEncodingCodecs.hevc = true;
          };
        };
        users.users.jellyfin.extraGroups = [
          "render"
          "video"
        ];

        systemd.services.jellyfin = {
          requires = [ "media-storage-ready.service" ];
          after = [ "media-storage-ready.service" ];
          bindsTo = [ "media-storage-ready.service" ];
          unitConfig = {
            ConditionPathExists = ready;
            RequiresMountsFor = [
              "/srv/range/media/movies"
              "/srv/range/media/tv"
            ];
          };
        };

        # The moved identity must already exist; this unit never enrolls anew.
        systemd.services.tsnet-proxy-jellyfin = {
          description = "Preserved watch media identity";
          wantedBy = [ "multi-user.target" ];
          wants = [
            "network-online.target"
            "jellyfin.service"
          ];
          after = [
            "network-online.target"
            "jellyfin.service"
          ];
          unitConfig = {
            ConditionPathExists = ready;
            ConditionFileNotEmpty = "${state}/tailscaled.state";
          };
          serviceConfig = {
            User = "media-proxy";
            Group = "media-proxy";
            StateDirectory = "tsnet-proxy-jellyfin";
            StateDirectoryMode = "0700";
            UMask = "0077";
            LoadCredential = [
              "oauth-id:${identities.oauthIdFile}"
              "oauth-secret:${identities.oauthSecretFile}"
            ];
            ExecStart =
              "${proxy}/bin/tsnet-proxy -hostname ${cfg.hostname} -state ${state}"
              + " -backend http://127.0.0.1:8096 -port 443"
              + " -oauth-id-file %d/oauth-id -oauth-secret-file %d/oauth-secret"
              + " -tags ${lib.concatStringsSep "," identities.tags}";
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
        };
      };
    };
}
