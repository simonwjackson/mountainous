{ lib, host }:
let
  job = import ../lib/openclaw-wind-down.nix;
  simon = host.containers.claw-simon.config;
  laure = host.containers.openclaw.config;
  inherit (simon.services.openclaw-gateway) config;
  other = laure.services.openclaw-gateway.config;
  unit = simon.systemd.services.openclaw-wind-down;
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
assert lib.elem "show_widget" config.tools.allow;
assert !lib.elem "show_widget" other.tools.allow;
assert lib.pathExists "${builtins.elemAt config.skills.load.extraDirs 1}/wind-down/SKILL.md";
assert lib.all (dir: !lib.pathExists "${dir}/wind-down/SKILL.md") other.skills.load.extraDirs;
assert !(laure.systemd.services ? openclaw-wind-down);
assert !((import ../lib/openclaw-people.nix).laure.enableWindDown or false);
true
