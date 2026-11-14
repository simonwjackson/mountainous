{ self, ... }:
let
  rows = import ../lib/ai-mcp-rows.nix;
  nodes = import ../lib/tailnet-nodes.nix;
  # The rows on the production front door that reach Simon's assistant apps,
  # keyed by app. The callers and tools come from lib/ai-mcp-rows.nix.
  appRows = {
    google = [
      "calendar"
      "gmail"
      "family-calendar"
      "family-calendar-laure"
    ];
    maps = [ "maps" ];
  };
  # Simon's own Google rows, flakey only (stage 5).
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
      # No key: the Google and Maps apps on loopback take none. Stage 7 retired
      # the last per-tool nodes (claw-family-calendar, claw-maps).
      config = lib.mkIf config.mountainous.features.ai-gateway.enable {
        mountainous.tailnetNames.ai.mcpRoutes = lib.mkMerge (
          lib.mapAttrsToList (
            app: names:
            lib.genAttrs names (row: {
              backend = "http://127.0.0.1:${port app}/mcp";
              callerNodeIds = map (node: nodes.${node}) rows.${row}.callers;
              mcpTools = rows.${row}.tools;
            })
          ) appRows
        );
      };
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
    in
    {
      checks.claw-tools =
        assert rows.calendar.tools == [ "calendar_busy" ];
        assert
          rows.gmail.tools == [
            "mail_list"
            "mail_read"
            "mail_not_mine"
            "mail_label"
            "mail_archive"
            "mail_draft"
            "mail_discard_draft"
          ];
        # Stage 5 retired Simon's per-tool Google nodes, stage 7 Laure's and
        # the shared one: no app node remains.
        assert lib.all (name: !(rakku.mountainous.tailnetNames ? ${name})) [
          "claw-calendar"
          "claw-gmail"
          "claw-family-calendar-simon"
          "claw-family-calendar"
          "claw-maps"
        ];
        assert lib.all (name: !(rakku.systemd.services ? "tsnet-proxy-${name}")) [
          "claw-family-calendar"
          "claw-maps"
        ];
        # Stage 5: the Google rows on production ai, flakey's stable ID only,
        # the same Google app backend and tools; flakey's servers point there.
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
          && server.url == "https://ai.hummingbird-lake.ts.net/mcp/${row}"
          && server.toolFilter.include == rows.${row}.tools
          && !(laureServers ? ${rows.${row}.server})
        ) googleRows;
        # Stage 7: Laure's family calendar (her node only) and the shared maps
        # (both gateways), with the same app backends and tools as their nodes.
        assert
          builtins.removeAttrs rakku.mountainous.tailnetNames.ai.mcpRoutes.family-calendar-laure [ "_module" ]
          == {
            backend = "http://127.0.0.1:3171/mcp";
            callerNodeIds = [ "nkT3Yhzyy121CNTRL" ];
            mcpTools = [ "family_calendar_events" ];
            mcpResources = [ ];
            bearerCredentialFile = null;
            scryer = null;
            webSearch = null;
          };
        assert
          builtins.removeAttrs rakku.mountainous.tailnetNames.ai.mcpRoutes.maps [ "_module" ] == {
            backend = "http://127.0.0.1:${toString rakku.mountainous.features.pi-assistant.people.simon.apps.maps.port}/mcp";
            callerNodeIds = [
              "nbQJZMcewG11CNTRL"
              "nkT3Yhzyy121CNTRL"
            ];
            mcpTools = [ "travel_time" ];
            mcpResources = [ ];
            bearerCredentialFile = null;
            scryer = null;
            webSearch = null;
          };
        assert rakku.mountainous.features.pi-assistant.people.simon.apps.maps.port == 3172;
        assert
          laureServers.claw-family-calendar.url
          == "https://ai.hummingbird-lake.ts.net/mcp/family-calendar-laure";
        assert lib.all (servers: servers.claw-maps.url == "https://ai.hummingbird-lake.ts.net/mcp/maps") [
          containers.claw-simon.config.services.openclaw-gateway.config.mcp.servers
          laureServers
        ];
        assert !(lib.elem "mail_send" rakku.mountainous.tailnetNames.ai.mcpRoutes.gmail.mcpTools);
        assert
          containers.claw-simon.config.services.openclaw-gateway.config.mcp.servers.claw-gmail.toolFilter.include
          == rows.gmail.tools;
        assert
          !(lib.elem "mail_send" containers.claw-simon.config.services.openclaw-gateway.config.mcp.servers.claw-gmail.toolFilter.include);
        assert
          !(containers.${laureContainer}.config.services.openclaw-gateway.config.mcp.servers ? claw-gmail);
        assert
          rakku.systemd.services.assistant-app-simon-google.environment.GOOGLE_LABEL_ALLOWLIST == "Not Me";
        assert rakku.systemd.services.assistant-app-simon-google.environment.GOOGLE_POLL_DISABLED == "1";
        assert lib.elem "mail_not_mine"
          rakku.mountainous.features.pi-assistant.people.simon.apps.google.readOnlyTools;
        assert
          rows.family-calendar.tools == [
            "family_calendar_events"
            "family_calendar_add"
            "family_calendar_remove"
          ];
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
        pkgs.runCommand "claw-tools-boundary" { nativeBuildInputs = [ pkgs.go ]; } ''
          export HOME=$TMPDIR GOCACHE=$TMPDIR/go-cache CGO_ENABLED=0
          go test -v ${../packages/media-tsnet-proxy/mcp-filter.go} ${../packages/media-tsnet-proxy/mcp-filter_test.go}
          go vet ${../packages/media-tsnet-proxy/mcp-filter.go}
          touch $out
        '';
    };
}
