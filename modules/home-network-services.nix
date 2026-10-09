# Network services accompanying the existing home automation instance.
{ inputs, ... }:
{
  nixos.modules.home-network-services =
    { config, pkgs, ... }:
    let
      airconnect = pkgs.stdenv.mkDerivation {
        pname = "airconnect";
        version = "1.9.2";
        src = inputs.airconnect-src;
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = [
          pkgs.alsa-lib
          pkgs.openssl
        ];
        installPhase = ''
          runHook preInstall
          install -Dm755 airupnp-linux-x86_64-static $out/bin/airupnp
          runHook postInstall
        '';
      };
      proxy =
        inputs.gomod2nix-rakku.legacyPackages.${pkgs.stdenv.hostPlatform.system}.buildGoApplication
          {
            pname = "tsnet-proxy";
            version = "1.0.0";
            src = ../packages/tsnet-proxy;
            modules = ../packages/tsnet-proxy/gomod2nix.toml;
            ldflags = [
              "-s"
              "-w"
            ];
            doCheck = false;
          };
    in
    {
      users.users.tsnet-proxy = {
        isSystemUser = true;
        group = "tsnet-proxy";
        uid = 991;
      };
      users.groups.tsnet-proxy.gid = 989;
      systemd.services.tsnet-proxy-habitat = {
        description = "Home Assistant habitat tailnet proxy";
        after = [
          "network.target"
          "local-fs.target"
        ];
        requires = [ "local-fs.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          TS_STATE_DIR = "/var/lib/tsnet-proxy-habitat";
          HOME = "/var/lib/tsnet-proxy-habitat";
        };
        serviceConfig = {
          User = "tsnet-proxy";
          Group = "tsnet-proxy";
          Restart = "always";
          RestartSec = "10s";
          StateDirectory = "tsnet-proxy-habitat";
          StateDirectoryMode = "0700";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectHostname = true;
          ProtectClock = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
          RestrictNamespaces = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          RemoveIPC = true;
        };
        script = ''
          export TS_AUTHKEY="$(cat ${config.sops.secrets.tailscale-ephemeral.path} | tr -d '\n')"
          mkdir -p "$TS_STATE_DIR/.config"
          exec ${proxy}/bin/tsnet-proxy -hostname habitat -backend http://localhost:8123 -port 443
        '';
      };
      services.tinyproxy = {
        enable = true;
        settings = {
          Port = 8888;
          Listen = "0.0.0.0";
          Timeout = 600;
          Allow = [
            "127.0.0.1"
            "100.64.0.0/10"
          ];
          MaxClients = 20;
          LogLevel = "Warning";
          ConnectPort = [
            443
            563
          ];
        };
      };
      systemd.services.airconnect = {
        description = "AirConnect - AirPlay to Sonos/UPnP Bridge";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${airconnect}/bin/airupnp -l 1000:2000 -Z";
          Restart = "on-failure";
          RestartSec = "10s";
          DynamicUser = true;
        };
      };
    };
}
