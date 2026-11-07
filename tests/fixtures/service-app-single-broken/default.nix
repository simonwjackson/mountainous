# Fail only the isolated single-process canary before serving HTTP.
{ pkgs, healthy }:
pkgs.runCommand "broken-single-canary-${healthy.version}" { inherit (healthy) version; } ''
  mkdir -p "$out/bin"
  printf '#!%s\nexit 1\n' ${pkgs.runtimeShell} > "$out/bin/service-app-single-canary-server"
  chmod +x "$out/bin/service-app-single-canary-server"
''
