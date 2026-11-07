{ pkgs, inputs }:
let
  runtime = import ./pi-service-runtime.nix {
    inherit pkgs inputs;
    name = "pace";
  };
in
runtime
// {
  serverArgs = [
    "--data-dir"
    "/var/lib/pace/data"
    "--origin"
    "https://pace.hummingbird-lake.ts.net"
  ];
  secrets = runtime.secrets // {
    pace-simplefin = "data/simplefin.json";
    pace-typesafe-api-key = "config/typesafe-api-key";
  };
  readOnlyBinds = runtime.readOnlyBinds ++ [
    "/run/secrets/pace-typesafe-api-key:/home/simonwjackson/.config/pace/typesafe-api-key.iYu0D0"
  ];
  scheduledCommands.sync = {
    args = [
      "--data-dir"
      "/var/lib/pace/data"
    ];
    onCalendar = "*-*-* 00,06,12,18:17:00";
    onBootSec = "5min";
  };
  smokeCommand = "${pkgs.curl}/bin/curl -fsS --max-time 3 http://127.0.0.1:4321/manifest.webmanifest >/dev/null";
  checkCommand = ''
    test "$("$APP_PACKAGE/bin/pace-server" --version)" = 'pace-server 0.1.0'
    "$APP_PACKAGE/bin/pace-sync" --help >/dev/null
  '';
}
