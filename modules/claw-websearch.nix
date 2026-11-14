{ self, ... }:
let
  row = (import ../lib/ai-mcp-rows.nix).websearch;
  nodes = import ../lib/tailnet-nodes.nix;
in
{
  nixos.modules.claw-websearch =
    { config, lib, ... }:
    lib.mkIf config.mountainous.features.ai-gateway.enable {
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
      # Both gateways' web search, on the production front door (stage 7): the
      # proxy runs the same search code with the same key, URL and model.
      mountainous.tailnetNames.ai.mcpRoutes.websearch = {
        callerNodeIds = map (node: nodes.${node}) row.callers;
        mcpTools = row.tools;
        webSearch = {
          url = "http://127.0.0.1:8430/v1/responses";
          model = "gpt-6.1-sol";
          keyFile = config.sops.secrets.ai-gateway-key-openclaw-yari.path;
        };
      };
      # systemd copies the key at unit start: a new value restarts ai once.
      sops.secrets.ai-gateway-key-openclaw-yari.restartUnits = [
        "tsnet-proxy-ai.service"
        "tsnet-proxy-claw-websearch.service"
      ];
    };
  perSystem =
    { pkgs, lib, ... }:
    let
      cfg = self.nixosConfigurations.rakku.config;
      endpoint = cfg.mountainous.tailnetNames.claw-websearch;
      route = cfg.mountainous.tailnetNames.ai.mcpRoutes.websearch;
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
        # Stage 7: /mcp/websearch on production ai, both gateways' stable IDs,
        # the same key, Responses URL and model as the node.
        assert
          builtins.removeAttrs route [ "_module" ] == {
            backend = null;
            callerNodeIds = [
              "nbQJZMcewG11CNTRL"
              "nkT3Yhzyy121CNTRL"
            ];
            mcpTools = [ "web_search" ];
            mcpResources = [ ];
            bearerCredentialFile = null;
            scryer = null;
            webSearch = {
              url = endpoint.backend;
              model = endpoint.webSearchModel;
              keyFile = endpoint.webSearchKeyFile;
            };
          };
        assert lib.elem "mcp-websearch:${route.webSearch.keyFile}"
          cfg.systemd.services.tsnet-proxy-ai.serviceConfig.LoadCredential;
        assert lib.elem "tsnet-proxy-ai.service" cfg.sops.secrets.ai-gateway-key-openclaw-yari.restartUnits;
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
