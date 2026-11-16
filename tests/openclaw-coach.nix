{ lib, host }:
let
  simon = host.containers.claw-simon.config;
  laure = host.containers.openclaw.config;
  root = ../lib/openclaw-skills/simon/coach;
  skill = builtins.readFile (root + "/SKILL.md");
  ref = name: builtins.readFile (root + "/references/${name}.md");
  pointer = builtins.readFile ../lib/openclaw-skills/simon/wind-down/references/therapy.md;
in
assert lib.pathExists (root + "/SKILL.md");
assert lib.hasInfix "name: coach" skill;
assert lib.hasInfix "Simon-only" skill;
assert lib.all (name: lib.hasInfix "references/${name}.md" skill) [
  "safety"
  "patterns"
  "crash-plan"
  "evidence"
  "sleep"
  "parenting"
];
assert lib.all (
  dir: !lib.pathExists "${dir}/coach/SKILL.md"
) laure.services.openclaw-gateway.config.skills.load.extraDirs;
assert lib.any (
  dir: lib.pathExists "${dir}/coach/SKILL.md"
) simon.services.openclaw-gateway.config.skills.load.extraDirs;
assert simon.systemd.services ? openclaw-coach-references;
assert !(laure.systemd.services ? openclaw-coach-references);
assert simon.systemd.services.openclaw-coach-references.before == [ "openclaw-gateway.service" ];
assert lib.hasInfix ".coach-references" simon.systemd.services.openclaw-coach-references.script;
assert lib.hasInfix "install -m 0444" simon.systemd.services.openclaw-coach-references.script;
assert lib.hasInfix ".coach-references/<name>.md" skill;
assert lib.hasInfix "coach" pointer && lib.hasInfix "live" pointer;
assert !(lib.hasInfix "OFF" pointer);
assert lib.hasInfix "ONE next step" skill;
assert lib.hasInfix "00:30" skill;
assert lib.hasInfix "two free nights a week, never back to" skill;
assert lib.hasInfix "only if Simon says tired/fried/overwhelmed" skill;
assert lib.hasInfix "coach/state.json" skill;
assert lib.hasInfix "ending your life" (ref "safety");
assert lib.hasInfix "988" (ref "safety") && lib.hasInfix "911" (ref "safety");
assert !(lib.hasInfix "741741" (ref "safety"));
assert lib.hasInfix "about a week" (ref "safety");
assert lib.hasInfix "two or more confirmed" (ref "safety");
assert lib.hasInfix "decisionRule" (ref "patterns");
assert lib.hasInfix "Correct / Delete" (ref "patterns");
assert lib.hasInfix "school run" (ref "crash-plan");
assert lib.hasInfix "Sunday 2026-11-15" (ref "crash-plan");
assert lib.hasInfix "TEST-crash-plan.md" (ref "crash-plan");
assert lib.hasInfix "using this TEST plan for a real crash" (ref "crash-plan");
assert lib.hasInfix "lack of visual access is not evidence of failure" (ref "crash-plan");
assert lib.hasInfix "don't duplicate its options" (ref "crash-plan");
assert lib.hasInfix "not walks, exercise or new health goals" (ref "crash-plan");
assert lib.hasInfix "unverified" (ref "evidence");
assert lib.hasInfix "## Do not claim" (ref "evidence");
assert lib.hasInfix "one sleep habit at a time" (ref "sleep");
assert lib.hasInfix "Only when Simon raises a hard parenting moment" (ref "parenting");
true
