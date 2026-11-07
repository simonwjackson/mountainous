# Keep the canary backend; fail its sidecar to exercise all-unit readiness.
{ pkgs, healthy }:
pkgs.runCommand "broken-sidecar-${healthy.version}" { inherit (healthy) version; } ''
  mkdir -p "$out/bin"
  ln -s ${healthy}/bin/service-app-canary-server "$out/bin/service-app-canary-server"
  printf '#!%s\nexit 1\n' ${pkgs.runtimeShell} > "$out/bin/service-app-canary-tsnet"
  chmod +x "$out/bin/service-app-canary-tsnet"
''
