{ inputs, self, ... }:
{
  nixos.modules.claw-ebay =
    { config, ... }:
    {
      systemd.services.ebay-server = {
        description = "Read-only eBay product service for Simon";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment.PORT = "3191";
        serviceConfig = {
          ExecStart = "${inputs.ebay.packages.x86_64-linux.default}/bin/ebay-server";
          LoadCredential = [
            "ebay-api-env:${config.sops.secrets.ebay-api-env.path}"
            "ebay-refresh-token:${config.sops.secrets.ebay-refresh-token.path}"
          ];
          DynamicUser = true;
          Restart = "on-failure";
          RestartSec = "5s";
          UMask = "0077";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          TemporaryFileSystem = [
            "/tmp:ro"
            "/var/tmp:ro"
          ];
          PrivateDevices = true;
          ProtectHostname = true;
          ProtectClock = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          CapabilityBoundingSet = "";
          RemoveIPC = true;
        };
      };
      sops.secrets.ebay-api-env.restartUnits = [ "ebay-server.service" ];
      sops.secrets.ebay-refresh-token.restartUnits = [ "ebay-server.service" ];
      mountainous.tailnetNames.claw-ebay-simon = {
        description = "Simon's read-only eBay MCP endpoint for OpenClaw";
        backend = "http://127.0.0.1:3191";
        after = [ "ebay-server.service" ];
        tags = [ "tag:claw-tools" ];
        mcpTools = [
          "ebay_search"
          "ebay_listings"
        ];
        mcpResources = [
          "ui://ebay/search.html"
          "ui://ebay/listings.html"
        ];
      };
    };
  perSystem =
    { pkgs, lib, ... }:
    let
      cfg = self.nixosConfigurations.rakku.config;
      endpoint = cfg.mountainous.tailnetNames.claw-ebay-simon;
      unit = cfg.systemd.services.ebay-server;
      proxyUnit = cfg.systemd.services.tsnet-proxy-claw-ebay-simon.serviceConfig;
      containers = self.nixosConfigurations.yari.config.containers;
      simon = containers.claw-simon.config.services.openclaw-gateway.config;
      laure = containers.openclaw.config.services.openclaw-gateway.config;
      proxy = ../packages/media-tsnet-proxy;
    in
    {
      checks.claw-ebay =
        assert inputs.ebay.rev == "416f6fc2d7876b45871d721548f5ee5e6f1257a6";
        assert endpoint.tags == [ "tag:claw-tools" ];
        assert endpoint.backend == "http://127.0.0.1:3191";
        assert
          endpoint.mcpTools == [
            "ebay_search"
            "ebay_listings"
          ];
        assert
          endpoint.mcpResources == [
            "ui://ebay/search.html"
            "ui://ebay/listings.html"
          ];
        assert lib.hasInfix "-mcp-tools ebay_search,ebay_listings" proxyUnit.ExecStart;
        assert lib.hasInfix "-mcp-resources ui://ebay/search.html,ui://ebay/listings.html"
          proxyUnit.ExecStart;
        assert unit.environment.PORT == "3191";
        assert unit.serviceConfig.DynamicUser && unit.serviceConfig.ProtectSystem == "strict";
        assert !(unit.serviceConfig ? StateDirectory);
        assert
          unit.serviceConfig.LoadCredential == [
            "ebay-api-env:${cfg.sops.secrets.ebay-api-env.path}"
            "ebay-refresh-token:${cfg.sops.secrets.ebay-refresh-token.path}"
          ];
        assert simon.mcp.servers.claw-ebay-simon.toolFilter.include == endpoint.mcpTools;
        assert !(simon.mcp.servers.claw-ebay-simon ? approval);
        assert lib.all (tool: lib.elem "claw-ebay-simon__${tool}" simon.tools.allow) endpoint.mcpTools;
        assert !(laure.mcp.servers ? claw-ebay-simon);
        assert !(lib.any (tool: lib.hasInfix "ebay" tool) laure.tools.allow);
        pkgs.runCommand "claw-ebay-boundary" { nativeBuildInputs = [ pkgs.go ]; } ''
          export HOME=$TMPDIR GOCACHE=$TMPDIR/go-cache CGO_ENABLED=0
          go test -v ${proxy}/mcp-filter.go ${proxy}/mcp-filter_test.go
          go vet ${proxy}/mcp-filter.go
          touch $out
        '';
    };
}
