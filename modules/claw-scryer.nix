{ self, ... }:
{
  nixos.modules.claw-scryer =
    { config, ... }:
    {
      mountainous.tailnetNames.claw-scryer = {
        description = "Full-admin Scryer MCP endpoint for the OpenClaw trial";
        backend = "https://scryer.hummingbird-lake.ts.net/graphql";
        tags = [ "tag:claw-tools" ];
        scryerPasswordFile = config.sops.secrets.scryer-admin-password.path;
      };
      sops.secrets.scryer-admin-password.restartUnits = [ "tsnet-proxy-claw-scryer.service" ];
    };
  perSystem =
    { pkgs, lib, ... }:
    let
      cfg = self.nixosConfigurations.rakku.config;
      endpoint = cfg.mountainous.tailnetNames.claw-scryer;
      unit = cfg.systemd.services.tsnet-proxy-claw-scryer.serviceConfig;
    in
    {
      checks.claw-scryer =
        assert endpoint.tags == [ "tag:claw-tools" ];
        assert endpoint.mcpTools == null;
        assert endpoint.scryerPasswordFile == cfg.sops.secrets.scryer-admin-password.path;
        assert lib.elem "scryer-admin-password:${endpoint.scryerPasswordFile}" unit.LoadCredential;
        assert lib.hasInfix "-scryer-password-file %d/scryer-admin-password" unit.ExecStart;
        pkgs.runCommand "claw-scryer-boundary" { nativeBuildInputs = [ pkgs.go ]; } ''
          export HOME=$TMPDIR GOCACHE=$TMPDIR/go-cache CGO_ENABLED=0
          go test -v ${../packages/media-tsnet-proxy/mcp-filter.go} ${../packages/media-tsnet-proxy/scryer.go} ${../packages/media-tsnet-proxy/scryer_test.go}
          go vet ${../packages/media-tsnet-proxy/mcp-filter.go} ${../packages/media-tsnet-proxy/scryer.go}
          touch $out
        '';
    };
}
