# Test-only candidate: keep the real sidecar, but exit before serving HTTP.
{
  inputs = {
    application.url = "path:../service-app-canary";
    nixpkgs.follows = "application/nixpkgs";
  };
  outputs =
    { application, nixpkgs, ... }:
    {
      packages.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          healthy = application.packages.x86_64-linux.default;
        in
        pkgs.runCommand "broken-canary-${healthy.version}" { inherit (healthy) version; } ''
          mkdir -p "$out/bin"
          ln -s ${healthy}/bin/service-app-canary-tsnet "$out/bin/service-app-canary-tsnet"
          printf '#!%s\nexit 1\n' ${pkgs.runtimeShell} > "$out/bin/service-app-canary-server"
          chmod +x "$out/bin/service-app-canary-server"
        '';
    };
}
