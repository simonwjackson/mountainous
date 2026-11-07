# Test-only candidate: serve the real backend, but fail the tsnet sidecar.
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
        pkgs.runCommand "broken-sidecar-${healthy.version}" { inherit (healthy) version; } ''
          mkdir -p "$out/bin"
          ln -s ${healthy}/bin/service-app-canary-server "$out/bin/service-app-canary-server"
          printf '#!%s\nexit 1\n' ${pkgs.runtimeShell} > "$out/bin/service-app-canary-tsnet"
          chmod +x "$out/bin/service-app-canary-tsnet"
        '';
    };
}
