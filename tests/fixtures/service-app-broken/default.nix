# Keep the canary sidecar; fail its backend before serving HTTP.
{ pkgs, healthy }:
pkgs.runCommand "broken-canary-${healthy.version}" { inherit (healthy) version; } ''
  mkdir -p "$out/bin"
  ln -s ${healthy}/bin/service-app-canary-tsnet "$out/bin/service-app-canary-tsnet"
  printf '#!%s\nexit 1\n' ${pkgs.runtimeShell} > "$out/bin/service-app-canary-server"
  chmod +x "$out/bin/service-app-canary-server"
''
