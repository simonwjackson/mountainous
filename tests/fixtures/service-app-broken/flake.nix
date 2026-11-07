# Test-only candidate: keep the real sidecar, but exit before serving HTTP.
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
        pkgs.runCommand "broken-groceries-${healthy.version}" { inherit (healthy) version; } ''
          mkdir -p "$out/bin"
          ln -s ${healthy}/bin/groceries-tsnet "$out/bin/groceries-tsnet"
          printf '#!%s\nexit 1\n' ${pkgs.runtimeShell} > "$out/bin/groceries-server"
          chmod +x "$out/bin/groceries-server"
        '';
    };
}
