# Network services accompanying the existing home automation instance.
{ inputs, ... }:
{
  nixos.modules.home-network-services =
    { pkgs, ... }:
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
    in
    {
      mountainous.tailnetNames.habitat = {
        description = "Home Assistant habitat tailnet proxy";
        backend = "http://127.0.0.1:8123";
        after = [ "home-assistant.service" ];
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
