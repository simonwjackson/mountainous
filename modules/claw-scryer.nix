{ self, ... }:
let
  rows = import ../lib/ai-mcp-rows.nix;
  nodes = import ../lib/tailnet-nodes.nix;
  # Each Scryer row on the production front door and the account it serves.
  accounts = {
    scryer = "simon";
    scryer-laure = "laure";
  };
in
{
  nixos.modules.claw-scryer =
    { config, lib, ... }:
    {
      mountainous.tailnetNames = lib.mkMerge [
        # flakey's and Laure's Scryer, on the production front door: the proxy
        # serves each account itself, with the same GraphQL URL and password as
        # its claw-scryer-<user> node. Callers come from lib/ai-mcp-rows.nix.
        (lib.mkIf config.mountainous.features.ai-gateway.enable {
          ai.mcpRoutes = lib.mapAttrs (row: username: {
            callerNodeIds = map (node: nodes.${node}) rows.${row}.callers;
            mcpTools = rows.${row}.tools;
            scryer = {
              url = "https://scryer.hummingbird-lake.ts.net/graphql";
              inherit username;
              passwordFile = config.sops.secrets."scryer-password-${username}".path;
            };
          }) accounts;
        })
        # Laure's own node stays. Simon's claw-scryer-simon node is retired.
        {
          claw-scryer-laure = {
            description = "laure's Scryer MCP endpoint for OpenClaw";
            backend = "https://scryer.hummingbird-lake.ts.net/graphql";
            tags = [ "tag:claw-tools" ];
            scryerUsername = "laure";
            scryerPasswordFile = config.sops.secrets.scryer-password-laure.path;
          };
        }
      ];
      # systemd copies the password at unit start: a new value restarts ai once.
      sops.secrets.scryer-password-simon.restartUnits = [ "tsnet-proxy-ai.service" ];
      sops.secrets.scryer-password-laure.restartUnits = [
        "tsnet-proxy-ai.service"
        "tsnet-proxy-claw-scryer-laure.service"
      ];
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
        # Stage 5 retired claw-scryer-simon; Laure's claw-scryer-laure stays.
        assert !(cfg.mountainous.tailnetNames ? claw-scryer-simon);
        assert !(cfg.systemd.services ? tsnet-proxy-claw-scryer-simon);
        assert
          !(lib.elem "tsnet-proxy-claw-scryer-simon.service" cfg.sops.secrets.scryer-password-simon.restartUnits);
        # Stage 5: /mcp/scryer on production ai serves Simon's account natively,
        # flakey only, with the same GraphQL URL and password as claw-scryer-simon.
        assert
          builtins.removeAttrs cfg.mountainous.tailnetNames.ai.mcpRoutes.scryer [ "_module" ] == {
            backend = null;
            callerNodeIds = [ "nbQJZMcewG11CNTRL" ];
            mcpTools = import ../lib/openclaw-scryer-tools.nix;
            mcpResources = [ ];
            bearerCredentialFile = null;
            scryer = {
              url = "https://scryer.hummingbird-lake.ts.net/graphql";
              username = "simon";
              passwordFile = cfg.sops.secrets.scryer-password-simon.path;
            };
            webSearch = null;
          };
        assert lib.elem "mcp-scryer:${cfg.sops.secrets.scryer-password-simon.path}"
          cfg.systemd.services.tsnet-proxy-ai.serviceConfig.LoadCredential;
        assert lib.elem "tsnet-proxy-ai.service" cfg.sops.secrets.scryer-password-simon.restartUnits;
        # Stage 7: /mcp/scryer-laure serves Laure's account natively, her node
        # only, with the same GraphQL URL and password as claw-scryer-laure.
        assert
          builtins.removeAttrs cfg.mountainous.tailnetNames.ai.mcpRoutes.scryer-laure [ "_module" ] == {
            backend = null;
            callerNodeIds = [ "nkT3Yhzyy121CNTRL" ];
            mcpTools = import ../lib/openclaw-scryer-tools.nix;
            mcpResources = [ ];
            bearerCredentialFile = null;
            scryer = {
              url = "https://scryer.hummingbird-lake.ts.net/graphql";
              username = "laure";
              passwordFile = cfg.sops.secrets.scryer-password-laure.path;
            };
            webSearch = null;
          };
        assert lib.elem "mcp-scryer-laure:${cfg.sops.secrets.scryer-password-laure.path}"
          cfg.systemd.services.tsnet-proxy-ai.serviceConfig.LoadCredential;
        assert lib.elem "tsnet-proxy-ai.service" cfg.sops.secrets.scryer-password-laure.restartUnits;
        assert
          self.nixosConfigurations.yari.config.containers.claw-simon.config.services.openclaw-gateway.config.mcp.servers.claw-scryer-simon.url
          == "https://ai.hummingbird-lake.ts.net/mcp/scryer";
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
