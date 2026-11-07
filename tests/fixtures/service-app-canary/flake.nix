# Isolated runtime rollback target: two loopback HTTP processes, no real data,
# credentials, provider calls, tsnet state, or tailnet node identity.
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/4975466d324710c576dc11ad614684e6bd8cad8e";
  outputs =
    { nixpkgs, ... }:
    {
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.symlinkJoin {
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
          };
        }
      );
    };
}
