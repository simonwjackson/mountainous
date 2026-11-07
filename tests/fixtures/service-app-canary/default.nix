# Data-free loopback canary. No inputs, credentials, providers or tailnet identity.
{ pkgs }:
pkgs.symlinkJoin {
  name = "service-app-canary-1.0.0";
  version = "1.0.0";
  paths =
    map
      (
        binary:
        pkgs.writeShellScriptBin binary ''
          exec ${pkgs.python3}/bin/python3 ${./server.py} "$@"
        ''
      )
      [
        "service-app-canary-server"
        "service-app-canary-tsnet"
      ];
}
