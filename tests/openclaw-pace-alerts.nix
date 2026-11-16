{ lib, host }:
let
  job = import ../lib/openclaw-pace-alerts.nix;
  simon = host.containers.claw-simon.config;
  laure = host.containers.openclaw.config;
  unit = simon.systemd.services.openclaw-pace-alerts;
in
assert job.declarationKey == "mountainous:pace-alerts";
assert job.enabled && job.agentId == "main";
assert job.sessionTarget == "isolated" && job.sessionKey == "agent:main:main";
assert job.delivery == { mode = "announce"; };
assert
  job.schedule == {
    kind = "cron";
    expr = "30 */6 * * *";
    tz = "America/Denver";
    staggerMs = 0;
  };
assert job.payload.kind == "agentTurn" && job.payload.timeoutSeconds == 300;
assert
  job.payload.message
  == "Call pace__pace_events with {}. With no events, return exactly NO_REPLY. With events, return the tool's text exactly. Do not append NO_REPLY. Report tool failures rather than treating them as empty results.";
assert unit.wantedBy == [ "multi-user.target" ];
assert unit.after == [ "openclaw-gateway.service" ];
assert unit.requires == [ "openclaw-gateway.service" ];
assert unit.partOf == [ "openclaw-gateway.service" ];
assert unit.serviceConfig.Type == "oneshot" && unit.serviceConfig.RemainAfterExit;
assert unit.serviceConfig.Restart == "on-failure";
assert !(laure.systemd.services ? openclaw-pace-alerts);
# Same atomic declaration and binding refresh as the existing cron reconciles.
assert lib.hasInfix "openclaw-ensure-pace-alerts" unit.serviceConfig.ExecStart;
true
