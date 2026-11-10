# Manual downloads: a stateless assistant module beside the VPN downloader.
{ inputs, self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.media-torrents = import ../tests/media-torrents.nix { inherit pkgs self; };
    };

  nixos.modules.torrents =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.torrents;
      password = config.sops.secrets.transmission-rpc-password.path;
    in
    {
      options.mountainous.features.torrents.enable =
        lib.mkEnableOption "the manual-download assistant module";
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion =
              config.services.transmission.enable && config.mountainous.features.media-identities.enable;
            message = "Torrents requires local Transmission and media tsnet identities.";
          }
        ];
        users.users.torrents = {
          isSystemUser = true;
          group = "media";
        };
        sops.secrets.transmission-rpc-password = {
          sopsFile = ../secrets/hosts/unzen.yaml;
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = [
            "transmission.service"
            "torrents.service"
          ];
        };
        mountainous.features.media-applications.transmissionRpcPasswordFile = password;
        systemd.tmpfiles.rules = [ "d /srv/basin/manual 2775 transmission media -" ];
        systemd.services.transmission.serviceConfig.BindPaths = [ "/srv/basin/manual" ];
        systemd.services.torrents = {
          description = "Manual-download assistant module";
          wantedBy = [ "multi-user.target" ];
          wants = [
            "media-vpn.service"
            "transmission.service"
          ];
          after = [
            "media-vpn.service"
            "transmission.service"
          ];
          unitConfig.RequiresMountsFor = [ "/srv/basin/manual" ];
          environment = {
            HOST = "127.0.0.1";
            PORT = "3190";
            TORRENTS_ROOT = "/srv/basin/manual";
            TORRENTS_ALLOWED_HOSTS = "127.0.0.1,localhost,torrents-mcp,torrents-mcp.hummingbird-lake.ts.net";
            TORRENTS_PEOPLE = "simon";
            TRANSMISSION_URL = "http://10.200.200.2:9091/transmission/rpc";
            TRANSMISSION_USER = "torrents";
          };
          serviceConfig = {
            User = "torrents";
            Group = "media";
            ExecStart = "${inputs.torrents.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/torrents";
            LoadCredential = [ "transmission-rpc-password:${password}" ];
            Restart = "on-failure";
            RestartSec = "5s";
            UMask = "0077";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadOnlyPaths = [ "/srv/basin/manual" ];
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            CapabilityBoundingSet = [ ];
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];
          };
        };
      };
    };
}
