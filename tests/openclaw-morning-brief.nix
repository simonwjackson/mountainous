{ lib, container }:
let
  job = import ../lib/openclaw-morning-brief.nix;
  unit = container.systemd.services.openclaw-morning-brief;
in
assert job.declarationKey == "mountainous:morning-brief";
assert job.enabled && job.agentId == "main";
assert
  job.schedule == {
    kind = "cron";
    expr = "0 7 * * *";
    tz = "America/Denver";
    staggerMs = 0;
  };
assert job.sessionTarget == "isolated" && job.sessionKey == "agent:main:main";
assert job.delivery == { mode = "announce"; };
assert job.payload.kind == "agentTurn" && job.payload.timeoutSeconds == 180;
assert !(job.payload ? lightContext) && !(job.payload ? model);
assert lib.hasInfix "calendar_busy" job.payload.message;
assert lib.hasInfix "America/Denver" job.payload.message;
assert lib.hasInfix "45 minutes" job.payload.message;
assert lib.hasInfix "08:00 and 22:00" job.payload.message;
assert lib.hasInfix "No busy events today" job.payload.message;
assert lib.hasInfix "at most one question" job.payload.message;
assert lib.hasInfix "actual coordinates present" job.payload.message;
assert lib.hasInfix "Do not pick tasks" job.payload.message;
assert lib.hasInfix "No health" job.payload.message;
assert lib.hasInfix "03:00 to 03:00" job.payload.message;
assert lib.hasInfix "web_fetch" job.payload.message;
assert lib.hasInfix
  "Home is Denver, 39.739, -104.985 (America/Denver); use it for weather unless an event says otherwise."
  job.payload.message;
assert lib.hasInfix "relevant memory" job.payload.message;
assert lib.hasInfix "wind_down_state" job.payload.message;
assert lib.hasInfix "assuming an ordinary day" job.payload.message;
assert lib.hasInfix "do not post a duplicate" job.payload.message;
assert unit.after == [ "openclaw-gateway.service" ];
assert unit.requires == [ "openclaw-gateway.service" ];
assert unit.partOf == [ "openclaw-gateway.service" ];
assert unit.wantedBy == [ "multi-user.target" ];
assert unit.serviceConfig.Type == "oneshot" && unit.serviceConfig.RemainAfterExit;
assert unit.serviceConfig.Restart == "on-failure";
true
