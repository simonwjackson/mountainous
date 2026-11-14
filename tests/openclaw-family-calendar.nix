{ lib, host }:
let
  simon = host.containers.claw-simon.config.services.openclaw-gateway.config;
  laure = host.containers.openclaw.config.services.openclaw-gateway.config;
  skill = builtins.readFile ../lib/openclaw-skills/simon/family-calendar/SKILL.md;
  windDown = builtins.readFile ../lib/openclaw-skills/simon/wind-down/SKILL.md;
in
# Text contracts guard the model-facing protocol; live Control UI tests prove
# the rendered buttons and real add/read/Undo behaviour.
assert lib.all (text: lib.hasInfix text skill) [
  "clear intent"
  "Add to Family calendar?"
  "Family calendar: add <draftId>"
  "Family calendar: change <draftId>"
  "Family calendar: skip <draftId>"
  "Family calendar: all-day <draftId>"
  "Family calendar: set-time <draftId>"
  "All day"
  "Set a time…"
  "Don't add"
  "possible duplicate"
  "at most 3"
  "Never write a draft to memory"
  "before a click or a clear typed yes"
  "read back"
  "ask_user"
  "neutral"
  "sendPrompt"
  "outcome_unknown"
];
assert lib.all (text: lib.hasInfix text windDown) [
  "clear intent"
  "confirm card"
  "Never save calendar drafts"
];
assert lib.elem "show_widget" simon.tools.allow;
assert simon.mcp.servers ? claw-family-calendar-simon;
assert !(laure.mcp.servers ? claw-family-calendar-simon);
assert lib.pathExists "${builtins.elemAt simon.skills.load.extraDirs 1}/family-calendar/SKILL.md";
assert lib.all (dir: !lib.pathExists "${dir}/family-calendar/SKILL.md") laure.skills.load.extraDirs;
true
