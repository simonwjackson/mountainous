{ inputs, self, ... }:
{
  nixos.modules.claw-ebay =
    { config, ... }:
    {
      systemd.services.ebay-server = {
        description = "eBay selling approval product service for Simon";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = {
          PORT = "3191";
          EBAY_STATE_DIR = "/var/lib/ebay";
          TZ = "America/Denver";
        };
        serviceConfig = {
          ExecStart = "${inputs.ebay.packages.x86_64-linux.default}/bin/ebay-server";
          LoadCredential = [
            "ebay-api-env:${config.sops.secrets.ebay-api-env.path}"
            "ebay-refresh-token:${config.sops.secrets.ebay-refresh-token.path}"
          ];
          DynamicUser = true;
          StateDirectory = "ebay";
          StateDirectoryMode = "0700";
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
        description = "Simon's eBay approval MCP endpoint for OpenClaw";
        backend = "http://127.0.0.1:3191";
        after = [ "ebay-server.service" ];
        tags = [ "tag:claw-tools" ];
        mcpTools = import ../lib/openclaw-ebay-tools.nix;
        mcpResources = [
          "ui://ebay/search.html"
          "ui://ebay/listings.html"
          "ui://ebay/needs.html"
          "ui://ebay/price.html"
          "ui://ebay/reply.html"
          "ui://ebay/offer.html"
          "ui://ebay/listing.html"
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
        assert inputs.ebay.rev == "aae1854bf09c1f2eee375287e29c1533f00aeb2c";
        assert endpoint.tags == [ "tag:claw-tools" ];
        assert endpoint.backend == "http://127.0.0.1:3191";
        assert
          endpoint.mcpTools == [
            "ebay_search"
            "ebay_listings"
            "ebay_drafts"
            "ebay_messages"
            "ebay_offers"
            "ebay_draft_price"
            "ebay_draft_reply"
            "ebay_draft_offer"
            "ebay_draft_listing"
            "ebay_apply_draft"
            "ebay_skip_draft"
            "ebay_save_draft"
            "ebay_put_back_price"
            "ebay_upload_photo"
          ];
        assert
          endpoint.mcpResources == [
            "ui://ebay/search.html"
            "ui://ebay/listings.html"
            "ui://ebay/needs.html"
            "ui://ebay/price.html"
            "ui://ebay/reply.html"
            "ui://ebay/offer.html"
            "ui://ebay/listing.html"
          ];
        assert lib.hasInfix (
          "-mcp-tools " + lib.concatStringsSep "," endpoint.mcpTools
        ) proxyUnit.ExecStart;
        assert lib.hasInfix (
          "-mcp-resources " + lib.concatStringsSep "," endpoint.mcpResources
        ) proxyUnit.ExecStart;
        assert unit.environment.PORT == "3191";
        assert unit.serviceConfig.DynamicUser && unit.serviceConfig.ProtectSystem == "strict";
        assert unit.serviceConfig.StateDirectory == "ebay";
        assert unit.serviceConfig.StateDirectoryMode == "0700";
        assert unit.environment.EBAY_STATE_DIR == "/var/lib/ebay";
        assert unit.environment.TZ == "America/Denver";
        assert
          unit.serviceConfig.LoadCredential == [
            "ebay-api-env:${cfg.sops.secrets.ebay-api-env.path}"
            "ebay-refresh-token:${cfg.sops.secrets.ebay-refresh-token.path}"
          ];
        assert simon.mcp.servers.claw-ebay-simon.toolFilter.include == endpoint.mcpTools;
        assert simon.mcp.servers.claw-ebay-simon.codex.defaultToolsApprovalMode == "approve";
        assert import ../tests/openclaw-ebay-selling.nix {
          inherit lib;
          container = containers.claw-simon.config;
        };
        assert !(containers.openclaw.config.systemd.services ? openclaw-ebay-selling);
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
