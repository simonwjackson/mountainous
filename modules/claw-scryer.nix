{ self, ... }:
{
  nixos.modules.claw-scryer =
    { config, ... }:
    {
      mountainous.tailnetNames = builtins.listToAttrs (
        map
          (username: {
            name = "claw-scryer-${username}";
            value = {
              description = "${username}'s Scryer MCP endpoint for OpenClaw";
              backend = "https://scryer.hummingbird-lake.ts.net/graphql";
              tags = [ "tag:claw-tools" ];
              scryerUsername = username;
              scryerPasswordFile = config.sops.secrets."scryer-password-${username}".path;
            };
          })
          [
            "simon"
            "laure"
          ]
      );
      sops.secrets.scryer-password-simon.restartUnits = [ "tsnet-proxy-claw-scryer-simon.service" ];
      sops.secrets.scryer-password-laure.restartUnits = [ "tsnet-proxy-claw-scryer-laure.service" ];
    };
  perSystem =
    { pkgs, lib, ... }:
    let
      cfg = self.nixosConfigurations.rakku.config;
      proxy = ../packages/media-tsnet-proxy;
    in
    {
      checks.claw-scryer =
        assert !(cfg.mountainous.tailnetNames ? claw-scryer);
        assert builtins.all
          (
            username:
            let
              endpoint = cfg.mountainous.tailnetNames."claw-scryer-${username}";
              unit = cfg.systemd.services."tsnet-proxy-claw-scryer-${username}".serviceConfig;
            in
            endpoint.tags == [ "tag:claw-tools" ]
            && endpoint.mcpTools == null
            && endpoint.scryerUsername == username
            && endpoint.scryerPasswordFile == cfg.sops.secrets."scryer-password-${username}".path
            && lib.elem "scryer-password:${endpoint.scryerPasswordFile}" unit.LoadCredential
            && !(lib.any (c: lib.hasInfix "scryer-admin-password" c) unit.LoadCredential)
            && lib.hasInfix "-scryer-password-file %d/scryer-password" unit.ExecStart
            && lib.hasInfix "-scryer-username ${lib.escapeShellArg username}" unit.ExecStart
          )
          [
            "simon"
            "laure"
          ];
        pkgs.runCommand "claw-scryer-boundary" { nativeBuildInputs = [ pkgs.go ]; } ''
          export HOME=$TMPDIR GOCACHE=$TMPDIR/go-cache CGO_ENABLED=0
          # The MCP App view is embedded from scryer-view/dist and stamped by its sources.
          mkdir src && cd src
          cp ${proxy}/mcp-filter.go ${proxy}/scryer.go ${proxy}/scryer_app.go ${proxy}/scryer_test.go ${proxy}/scryer_app_test.go .
          cp -r ${proxy}/scryer-view scryer-view
          go test -v mcp-filter.go scryer.go scryer_app.go scryer_test.go scryer_app_test.go
          go vet mcp-filter.go scryer.go scryer_app.go
          touch $out
        '';
    };
}
