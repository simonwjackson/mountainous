{ self, ... }:
let
  endpoints = import ../lib/claw-tools.nix;
  rows = import ../lib/ai-mcp-rows.nix;
  # Simon's Google tools on the production front door, flakey only.
  googleRows = [
    "calendar"
    "gmail"
    "family-calendar"
  ];
in
{
  nixos.modules.claw-tools =
    { config, lib, ... }:
    let
      port = app: toString config.mountainous.features.pi-assistant.people.simon.apps.${app}.port;
    in
    {
      config = lib.mkMerge [
        {
          mountainous.tailnetNames = lib.mapAttrs (_: endpoint: {
            description = "Filtered OpenClaw ${endpoint.app} MCP endpoint";
            backend = "http://127.0.0.1:${port endpoint.app}";
            after = [ "assistant-app-simon-${endpoint.app}.service" ];
            tags = [ "tag:claw-tools" ];
            mcpTools = endpoint.tools;
            mcpAllowedNodeIds = endpoint.allowedNodeIds or [ ];
          }) endpoints;
        }
        # No key: the Google app on loopback takes none, as before.
        (lib.mkIf config.mountainous.features.ai-gateway.enable {
          mountainous.tailnetNames.ai.mcpRoutes = lib.genAttrs googleRows (row: {
            backend = "http://127.0.0.1:${port "google"}/mcp";
            callerNodeIds = [ (import ../lib/tailnet-nodes.nix).flakey ];
            mcpTools = rows.${row}.tools;
          });
        })
      ];
    };
  perSystem =
    { pkgs, lib, ... }:
    let
      rakku = self.nixosConfigurations.rakku.config;
      containers = self.nixosConfigurations.yari.config.containers;
      laureContainer =
        if self.nixosConfigurations.yari.config.mountainous.features.openclaw.legacy.enable then
          "claw-laure"
        else
          "openclaw";
      laureServers = containers.${laureContainer}.config.services.openclaw-gateway.config.mcp.servers;
      mcp = containers.claw-simon.config.services.openclaw-gateway.config.mcp.servers // laureServers;
    in
    {
      checks.claw-tools =
        assert endpoints.claw-calendar.tools == [ "calendar_busy" ];
        assert
          endpoints.claw-gmail.tools == [
            "mail_list"
            "mail_read"
            "mail_not_mine"
            "mail_label"
            "mail_archive"
            "mail_draft"
            "mail_discard_draft"
          ];
        assert !(lib.elem "mail_send" rakku.mountainous.tailnetNames.claw-gmail.mcpTools);
        # Stage 5: the Google rows on production ai, flakey's stable ID only,
        # the same Google app backend and tools as flakey's filter.
        assert lib.all (
          row:
          let
            route = rakku.mountainous.tailnetNames.ai.mcpRoutes.${row};
            server =
              containers.claw-simon.config.services.openclaw-gateway.config.mcp.servers.${rows.${row}.server};
          in
          route.backend
          == "http://127.0.0.1:${toString rakku.mountainous.features.pi-assistant.people.simon.apps.google.port}/mcp"
          && route.callerNodeIds == [ "nbQJZMcewG11CNTRL" ]
          && route.mcpTools == rows.${row}.tools
          && route.bearerCredentialFile == null
          && route.mcpResources == [ ]
          && server.toolFilter.include == rows.${row}.tools
          && !(laureServers ? ${rows.${row}.server})
        ) googleRows;
        assert !(lib.elem "mail_send" rakku.mountainous.tailnetNames.ai.mcpRoutes.gmail.mcpTools);
        assert
          containers.claw-simon.config.services.openclaw-gateway.config.mcp.servers.claw-gmail.toolFilter.include
          == endpoints.claw-gmail.tools;
        assert
          !(lib.elem "mail_send" containers.claw-simon.config.services.openclaw-gateway.config.mcp.servers.claw-gmail.toolFilter.include);
        assert
          !(containers.${laureContainer}.config.services.openclaw-gateway.config.mcp.servers ? claw-gmail);
        assert
          rakku.systemd.services.assistant-app-simon-google.environment.GOOGLE_LABEL_ALLOWLIST == "Not Me";
        assert rakku.systemd.services.assistant-app-simon-google.environment.GOOGLE_POLL_DISABLED == "1";
        assert lib.elem "mail_not_mine"
          rakku.mountainous.features.pi-assistant.people.simon.apps.google.readOnlyTools;
        assert endpoints.claw-maps.tools == [ "travel_time" ];
        assert endpoints.claw-family-calendar.tools == [ "family_calendar_events" ];
        assert
          endpoints.claw-family-calendar-simon.tools == [
            "family_calendar_events"
            "family_calendar_add"
            "family_calendar_remove"
          ];
        assert
          rakku.mountainous.tailnetNames.claw-family-calendar-simon.mcpAllowedNodeIds
          == [ "nbQJZMcewG11CNTRL" ];
        assert lib.hasInfix "-mcp-allowed-node-ids nbQJZMcewG11CNTRL"
          rakku.systemd.services.tsnet-proxy-claw-family-calendar-simon.serviceConfig.ExecStart;
        assert
          !(
            containers.${laureContainer}.config.services.openclaw-gateway.config.mcp.servers
            ? claw-family-calendar-simon
          );
        assert lib.all
          (
            tool:
            !(lib.elem tool rakku.mountainous.features.pi-assistant.people.simon.apps.google.readOnlyTools)
          )
          [
            "family_calendar_add"
            "family_calendar_remove"
          ];
        assert
          rakku.systemd.services.assistant-app-simon-google.environment.GOOGLE_FAMILY_CALENDAR_ID
          == "46g7he3srihobgru1lmoegsar8@group.calendar.google.com";
        assert lib.all (
          name:
          let
            endpoint = endpoints.${name};
            cfg = rakku.mountainous.tailnetNames.${name};
            unit = rakku.systemd.services."tsnet-proxy-${name}";
          in
          cfg.tags == [ "tag:claw-tools" ]
          && cfg.mcpTools == endpoint.tools
          && lib.hasInfix "-mcp-tools" unit.serviceConfig.ExecStart
          && lib.hasInfix "-tags tag:claw-tools" unit.serviceConfig.ExecStart
          && lib.hasInfix "-oauth-secret-file" unit.serviceConfig.ExecStart
          && (
            name == "claw-gmail"
            || (mcp.${name}.transport == "streamable-http" && mcp.${name}.toolFilter.include == endpoint.tools)
          )
        ) (lib.attrNames endpoints);
        pkgs.runCommand "claw-tools-boundary" { nativeBuildInputs = [ pkgs.go ]; } ''
          export HOME=$TMPDIR GOCACHE=$TMPDIR/go-cache CGO_ENABLED=0
          go test -v ${../packages/media-tsnet-proxy/mcp-filter.go} ${../packages/media-tsnet-proxy/mcp-filter_test.go}
          go vet ${../packages/media-tsnet-proxy/mcp-filter.go}
          touch $out
        '';
    };
}
