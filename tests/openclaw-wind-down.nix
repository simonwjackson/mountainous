{ lib, host }:
let
  job = import ../lib/openclaw-wind-down.nix;
  simon = host.containers.claw-simon.config;
  laure = host.containers.openclaw.config;
  inherit (simon.services.openclaw-gateway) config;
  other = laure.services.openclaw-gateway.config;
  unit = simon.systemd.services.openclaw-wind-down;
  skill = builtins.readFile ../lib/openclaw-skills/simon/wind-down/SKILL.md;
in
assert job.declarationKey == "mountainous:wind-down";
assert job.enabled && job.agentId == "main";
assert
  job.schedule == {
    kind = "cron";
    expr = "0 21 * * *";
    tz = "America/Denver";
    staggerMs = 0;
  };
assert job.sessionTarget == "isolated" && job.sessionKey == "agent:main:main";
assert job.delivery == { mode = "announce"; };
assert job.payload.kind == "agentTurn" && job.payload.timeoutSeconds == 60;
assert lib.hasInfix "NO_REPLY" job.payload.message;
assert lib.hasInfix "memory/YYYY-MM-DD.md" job.payload.message;
assert lib.hasInfix "## Wind-down" job.payload.message;
assert lib.hasInfix "calendar_busy" job.payload.message;
assert lib.hasInfix "10–15 minutes" job.payload.message;
assert lib.hasInfix "at most one" job.payload.message;
assert unit.after == [ "openclaw-gateway.service" ];
assert unit.requires == [ "openclaw-gateway.service" ];
assert unit.partOf == [ "openclaw-gateway.service" ];
assert unit.wantedBy == [ "multi-user.target" ];
assert unit.serviceConfig.Type == "oneshot" && unit.serviceConfig.RemainAfterExit;
assert unit.serviceConfig.Restart == "on-failure";
assert lib.hasInfix "Until Stop's write and read-back succeed" skill;
assert lib.hasInfix "Always include lookBack when charge is 4 or 5" skill;
assert lib.hasInfix "short mode: Rate, Capture, Stop" skill;
assert lib.hasInfix "at most 3 must-dos" skill;
# SparkyFitness is the read-only source for food, training, sleep and body data.
assert lib.hasInfix "come only from `sparkyfitness`" skill;
assert lib.hasInfix "read-only, so\nnever log, change or delete" skill;
assert !(lib.hasInfix "Body data, food, training" skill);
assert lib.elem "show_widget" config.tools.allow;
assert !lib.elem "show_widget" other.tools.allow;
assert lib.pathExists "${builtins.elemAt config.skills.load.extraDirs 1}/wind-down/SKILL.md";
assert lib.all (dir: !lib.pathExists "${dir}/wind-down/SKILL.md") other.skills.load.extraDirs;
assert !(laure.systemd.services ? openclaw-wind-down);
assert !((import ../lib/openclaw-people.nix).laure.enableWindDown or false);
true
