{ self, ... }:
let
  endpoints = import ../lib/claw-tools.nix;
in
{
  nixos.modules.claw-tools =
    { config, lib, ... }:
    {
      mountainous.tailnetNames = lib.mapAttrs (_: endpoint: {
        description = "Read-only OpenClaw ${endpoint.app} MCP endpoint";
        backend = "http://127.0.0.1:${
          toString config.mountainous.features.pi-assistant.people.simon.apps.${endpoint.app}.port
        }";
        after = [ "assistant-app-simon-${endpoint.app}.service" ];
        tags = [ "tag:claw-tools" ];
        mcpTools = endpoint.tools;
      }) endpoints;
    };
  perSystem =
    { pkgs, lib, ... }:
    let
      rakku = self.nixosConfigurations.rakku.config;
      containers = self.nixosConfigurations.yari.config.containers;
      mcp =
        containers.claw-simon.config.services.openclaw-gateway.config.mcp.servers
        // containers.claw-laure.config.services.openclaw-gateway.config.mcp.servers;
    in
    {
      checks.claw-tools =
        assert endpoints.claw-calendar.tools == [ "calendar_busy" ];
        assert endpoints.claw-maps.tools == [ "travel_time" ];
        assert endpoints.claw-family-calendar.tools == [ "family_calendar_events" ];
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
          && mcp.${name}.transport == "streamable-http"
          && mcp.${name}.toolFilter.include == endpoint.tools
        ) (lib.attrNames endpoints);
        pkgs.runCommand "claw-tools-boundary" { nativeBuildInputs = [ pkgs.go ]; } ''
          export HOME=$TMPDIR GOCACHE=$TMPDIR/go-cache CGO_ENABLED=0
          go test -v ${../packages/media-tsnet-proxy/mcp-filter.go} ${../packages/media-tsnet-proxy/mcp-filter_test.go}
          go vet ${../packages/media-tsnet-proxy/mcp-filter.go}
          touch $out
        '';
    };
}
