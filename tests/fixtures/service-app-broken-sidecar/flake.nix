# Test-only candidate: serve the real backend, but fail the tsnet sidecar.
{
  inputs = {
    application.url = "git+ssh://simonwjackson@zao.hummingbird-lake.ts.net/home/simonwjackson/code/sandbox/groceries?ref=main";
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
          ln -s ${healthy}/bin/groceries-server "$out/bin/groceries-server"
          printf '#!%s\nexit 1\n' ${pkgs.runtimeShell} > "$out/bin/groceries-tsnet"
          chmod +x "$out/bin/groceries-tsnet"
        '';
    };
}
