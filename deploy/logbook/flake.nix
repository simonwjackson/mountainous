# App-only deployment. scripts/logbook-deploy supplies and locks both source SHAs.
{
  inputs = {
    logbook.url = "git+file:///var/lib/app-updater/logbook/source?ref=main";
    nixpkgs.follows = "logbook/nixpkgs";
    deploy-rs = {
      url = "github:serokell/deploy-rs/45ba3f8c5cb28396fff71671806e2550b464ac86";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      logbook,
      nixpkgs,
      deploy-rs,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      deployPkgs = import nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlays.default
          (_final: prev: {
            deploy-rs = {
              inherit (pkgs) deploy-rs;
              inherit (prev.deploy-rs) lib;
            };
          })
        ];
      };
      application = logbook.packages.${system}.default;
      deploy.nodes.rakku = {
        hostname = "rakku.hummingbird-lake.ts.net";
        sshUser = "logbook";
        user = "logbook";
        remoteBuild = false;
        autoRollback = true;
        magicRollback = true;
        activationTimeout = 300;
        confirmTimeout = 60;
        sshOpts = [
          "-F"
          "/dev/null"
          "-i"
          "/var/lib/app-updater/ssh/id_ed25519"
          "-o"
          "IdentitiesOnly=yes"
          "-o"
          "BatchMode=yes"
          "-o"
          "StrictHostKeyChecking=yes"
          "-o"
          "HostKeyAlias=rakku"
          "-o"
          "HostKeyAlgorithms=ssh-ed25519"
          "-o"
          "UserKnownHostsFile=${./known_hosts}"
          "-o"
          "GlobalKnownHostsFile=/dev/null"
          "-o"
          "ConnectTimeout=10"
        ];
        profiles.logbook = {
          profilePath = "/nix/var/nix/profiles/per-user/logbook/application";
          path = deployPkgs.deploy-rs.lib.activate.custom application ''
            # sudo matches the controller's store path, not the profile symlink.
            control=$(${pkgs.coreutils}/bin/readlink -f /run/current-system/sw/bin/logbook-service-control)
            /run/wrappers/bin/sudo "$control" stop
            /run/wrappers/bin/sudo "$control" start
            ${pkgs.curl}/bin/curl --fail --silent --show-error --retry 30 --retry-connrefused --retry-delay 1 \
              http://127.0.0.1:3160/healthz | ${pkgs.jq}/bin/jq -e '.status == "ok"'
            ${pkgs.curl}/bin/curl --fail --silent --show-error http://127.0.0.1:3160/rpc \
              -H 'Content-Type: application/json' \
              -d '{"jsonrpc":"2.0","id":1,"method":"metrics.list","params":{}}' \
              | ${pkgs.jq}/bin/jq -e '.result | length > 0'
          '';
        };
      };
    in
    {
      inherit deploy;
      packages.${system} = {
        inherit application;
        deployer = pkgs.deploy-rs;
      };
      checks.${system} = deployPkgs.deploy-rs.lib.deployChecks deploy;
    };
}
