{ self, ... }:
{
  nixos.modules.claw-websearch =
    { config, ... }:
    {
      mountainous.tailnetNames.claw-websearch = {
        description = "Model-native web search MCP for both OpenClaw agents";
        backend = "http://127.0.0.1:8430/v1/responses";
        after = [ "ai-gateway.service" ];
        tags = [ "tag:claw-tools" ];
        # Reuse the already granted Responses key. Only a credential copy reaches
        # this unit; no new secret, grant, search vendor or store value is needed.
        webSearchKeyFile = config.sops.secrets.ai-gateway-key-openclaw-yari.path;
        webSearchModel = "gpt-6.1-sol";
      };
      sops.secrets.ai-gateway-key-openclaw-yari.restartUnits = [ "tsnet-proxy-claw-websearch.service" ];
    };
  perSystem =
    { pkgs, lib, ... }:
    let
      cfg = self.nixosConfigurations.rakku.config;
      endpoint = cfg.mountainous.tailnetNames.claw-websearch;
      unit = cfg.systemd.services.tsnet-proxy-claw-websearch.serviceConfig;
      proxy = ../packages/media-tsnet-proxy;
    in
    {
      checks.claw-websearch =
        assert endpoint.tags == [ "tag:claw-tools" ];
        assert endpoint.backend == "http://127.0.0.1:8430/v1/responses";
        assert endpoint.webSearchModel == "gpt-6.1-sol";
        assert endpoint.mcpTools == null && endpoint.scryerPasswordFile == null;
        assert endpoint.webSearchKeyFile == cfg.sops.secrets.ai-gateway-key-openclaw-yari.path;
        assert lib.elem "websearch-key:${endpoint.webSearchKeyFile}" unit.LoadCredential;
        assert lib.hasInfix "-websearch-key-file %d/websearch-key" unit.ExecStart;
        assert lib.hasInfix "-tags tag:claw-tools" unit.ExecStart;
        assert lib.any (
          grant:
          grant.name == "openclaw@yari"
          && lib.elem "responses" grant.dialects
          && lib.elem endpoint.webSearchModel grant.models
        ) cfg.mountainous.features.ai-gateway.settings.gateway_keys;
        pkgs.runCommand "claw-websearch-boundary" { nativeBuildInputs = [ pkgs.go ]; } ''
          export HOME=$TMPDIR GOCACHE=$TMPDIR/go-cache CGO_ENABLED=0
          go test -v ${proxy}/mcp-filter.go ${proxy}/websearch.go ${proxy}/websearch_test.go
          go vet ${proxy}/mcp-filter.go ${proxy}/websearch.go
          touch $out
        '';
    };
}
