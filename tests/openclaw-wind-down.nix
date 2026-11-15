{ lib, host }:
let
  job = import ../lib/openclaw-wind-down.nix;
  simon = host.containers.claw-simon.config;
  laure = host.containers.openclaw.config;
  inherit (simon.services.openclaw-gateway) config;
  other = laure.services.openclaw-gateway.config;
  unit = simon.systemd.services.openclaw-wind-down;
  root = ../lib/openclaw-skills/simon/wind-down;
  skill = builtins.readFile (root + "/SKILL.md");
  ref = name: builtins.readFile (root + "/references/${name}.md");
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
# Model-facing contracts; real Control UI acceptance also required.
assert lib.all
  (
    name: lib.hasInfix "references/${name}.md" skill && lib.pathExists (root + "/references/${name}.md")
  )
  [
    "day"
    "week"
    "scale"
    "storage"
    "cards"
    "therapy"
    "not-connected"
  ];
assert lib.hasInfix "at most three" (ref "day");
assert lib.hasInfix "always include lookBack" (ref "day");
assert lib.hasInfix "read-back" (ref "storage");
assert lib.hasInfix "### Tomorrow — YYYY-MM-DD" (ref "storage");
assert lib.hasInfix "latest-zone.json" (ref "storage");
assert lib.hasInfix "energy_value" (ref "storage");
assert lib.hasInfix "mood_value" (ref "storage");
assert lib.hasInfix "population" (ref "scale");
assert lib.hasInfix "14-day" (ref "scale");
assert lib.hasInfix "not enough data yet" (ref "scale");
assert lib.hasInfix "input | baseline | deviation | weight | pull" (ref "scale");
assert lib.hasInfix "OFF" (ref "therapy");
assert lib.hasInfix "five buttons" (ref "cards");
assert lib.hasInfix "ChargeRead.weeks" (ref "week");
assert lib.hasInfix "USER.md" skill && lib.hasInfix "MEMORY.md" skill;
assert simon.systemd.services ? openclaw-wind-down-references;
assert !(laure.systemd.services ? openclaw-wind-down-references);
assert lib.hasInfix ".wind-down-references"
  simon.systemd.services.openclaw-wind-down-references.script;
assert lib.hasInfix "install -m 0444" simon.systemd.services.openclaw-wind-down-references.script;
assert lib.hasInfix ".wind-down-references/<name>.md" skill;
assert lib.elem "show_widget" config.tools.allow;
assert !lib.elem "show_widget" other.tools.allow;
assert lib.pathExists "${builtins.elemAt config.skills.load.extraDirs 1}/wind-down/SKILL.md";
assert lib.all (dir: !lib.pathExists "${dir}/wind-down/SKILL.md") other.skills.load.extraDirs;
assert !(laure.systemd.services ? openclaw-wind-down);
assert !((import ../lib/openclaw-people.nix).laure.enableWindDown or false);
true
