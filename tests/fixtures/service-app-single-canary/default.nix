# One isolated loopback process, with no credentials or tailnet identity.
{ pkgs }:
(pkgs.writeShellScriptBin "service-app-single-canary-server" ''
  exec ${pkgs.python3}/bin/python3 ${../service-app-canary/server.py} "$@"
'').overrideAttrs
  (_: {
    version = "1.0.0";
  })
