# Production contracts: Pace 2 is separate from quarantined Pace 1.
{
  lib,
  rakku,
  yari,
}:
let
  unit = rakku.systemd.services.pace2;
  rows = rakku.mountainous.tailnetNames.ai.mcpRoutes;
  credential = person: "pace-key-${person}:${rakku.sops.secrets."pace-key-${person}".path}";
  gateway = container: yari.containers.${container}.config.services.openclaw-gateway.config;
in
assert unit.environment.HOST == "127.0.0.1";
assert unit.environment.PORT == "3195";
assert unit.environment.TZ == "America/Denver";
assert unit.environment.PACE_SYNC == "on";
assert unit.serviceConfig.StateDirectory == "pace2";
assert unit.serviceConfig.User == "pace2";
assert
  unit.serviceConfig.LoadCredential == [
    (credential "simon")
    (credential "laure")
    "simplefin-access-url:${rakku.sops.secrets.simplefin-access-url.path}"
  ];
assert unit.serviceConfig.ProtectSystem == "strict";
assert unit.serviceConfig.ReadWritePaths == [ "/var/lib/pace2" ];
assert unit.serviceConfig.SystemCallFilter == [ "@system-service" ];
assert unit.serviceConfig.CapabilityBoundingSet == "";
assert unit.serviceConfig.MemoryDenyWriteExecute;
assert lib.all
  (
    row:
    rows.${row}.backend == "http://127.0.0.1:3195/mcp"
    && rows.${row}.mcpTools == [ "pace_status" ]
    && rows.${row}.mcpResources == [ "ui://pace/status" ]
  )
  [
    "pace"
    "pace-laure"
  ];
assert rows.pace.callerNodeIds == [ "nbQJZMcewG11CNTRL" ];
assert rows.pace-laure.callerNodeIds == [ "nkT3Yhzyy121CNTRL" ];
assert rows.pace.bearerCredentialFile == rakku.sops.secrets.pace-key-simon.path;
assert rows.pace-laure.bearerCredentialFile == rakku.sops.secrets.pace-key-laure.path;
assert lib.all
  (person: lib.elem "tsnet-proxy-ai.service" rakku.sops.secrets."pace-key-${person}".restartUnits)
  [
    "simon"
    "laure"
  ];
assert lib.all
  (
    pair:
    (gateway pair.container).mcp.servers.pace == {
      transport = "streamable-http";
      url = "https://ai.hummingbird-lake.ts.net/mcp/${pair.row}";
      toolFilter.include = [ "pace_status" ];
    }
    && lib.pathExists "${lib.head (gateway pair.container).skills.load.extraDirs}/pace/SKILL.md"
  )
  [
    {
      container = "claw-simon";
      row = "pace";
    }
    {
      container = "openclaw";
      row = "pace-laure";
    }
  ];
true
