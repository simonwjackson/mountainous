{ self, ... }:
let
  row = (import ../lib/ai-mcp-rows.nix).websearch;
  nodes = import ../lib/tailnet-nodes.nix;
in
{
  nixos.modules.claw-websearch =
    { config, lib, ... }:
    lib.mkIf config.mountainous.features.ai-gateway.enable {
      # Both gateways' web search, on the production front door (stage 7): the
      # proxy runs the same search code with the same key, URL and model as the
      # retired claw-websearch node. It reuses the gateways' granted Responses
      # key; no new secret, grant, search vendor or store value is needed.
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
      sops.secrets.ai-gateway-key-openclaw-yari.restartUnits = [ "tsnet-proxy-ai.service" ];
    };
  perSystem =
    { pkgs, lib, ... }:
    let
      cfg = self.nixosConfigurations.rakku.config;
      route = cfg.mountainous.tailnetNames.ai.mcpRoutes.websearch;
      proxy = ../packages/media-tsnet-proxy;
    in
    {
      checks.claw-websearch =
        # Stage 7 retired the claw-websearch node.
        assert !(cfg.mountainous.tailnetNames ? claw-websearch);
        assert !(cfg.systemd.services ? tsnet-proxy-claw-websearch);
        # /mcp/websearch on production ai, both gateways' stable IDs, the same
        # key, Responses URL and model as the retired node.
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
              url = "http://127.0.0.1:8430/v1/responses";
              model = "gpt-6.1-sol";
              keyFile = cfg.sops.secrets.ai-gateway-key-openclaw-yari.path;
            };
          };
        assert lib.elem "mcp-websearch:${route.webSearch.keyFile}"
          cfg.systemd.services.tsnet-proxy-ai.serviceConfig.LoadCredential;
        assert lib.elem "tsnet-proxy-ai.service" cfg.sops.secrets.ai-gateway-key-openclaw-yari.restartUnits;
        # Both gateways' claw-websearch server reaches the row; neither holds a key.
        assert lib.all
          (
            container:
            self.nixosConfigurations.yari.config.containers.${container}.config.services.openclaw-gateway.config.mcp.servers.claw-websearch
            == {
              transport = "streamable-http";
              url = "https://ai.hummingbird-lake.ts.net/mcp/websearch";
              toolFilter.include = [ "web_search" ];
            }
          )
          [
            "claw-simon"
            "openclaw"
          ];
        assert lib.any (
          grant:
          grant.name == "openclaw@yari"
          && lib.elem "responses" grant.dialects
          && lib.elem route.webSearch.model grant.models
        ) cfg.mountainous.features.ai-gateway.settings.gateway_keys;
        pkgs.runCommand "claw-websearch-boundary" { nativeBuildInputs = [ pkgs.go ]; } ''
          export HOME=$TMPDIR GOCACHE=$TMPDIR/go-cache CGO_ENABLED=0
          go test -v ${proxy}/mcp-filter.go ${proxy}/websearch.go ${proxy}/websearch_test.go
          go vet ${proxy}/mcp-filter.go ${proxy}/websearch.go
          touch $out
        '';
    };
}
