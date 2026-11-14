{ lib, host }:
let
  simon = host.containers.claw-simon.config.services.openclaw-gateway.config;
  laure = host.containers.openclaw.config.services.openclaw-gateway.config;
  skill = builtins.readFile ../lib/openclaw-skills/simon/calendar/SKILL.md;
  windDown = builtins.readFile ../lib/openclaw-skills/simon/wind-down/SKILL.md;
in
# Text contracts guard the model-facing protocol; live Control UI tests prove
# the rendered buttons and real add/read/Undo behaviour.
assert lib.all (text: lib.hasInfix text skill) [
  "clear intent"
  "Add to calendar?"
  "Calendar: add <draftId> to <calendar short ref>"
  "Calendar: change <draftId> to <calendar short ref>"
  "Calendar: skip <draftId> to <calendar short ref>"
  "Calendar: all-day <draftId> to <calendar short ref>"
  "Calendar: set-time <draftId> to <calendar short ref>"
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
  "calendars_list"
  "aria-pressed"
  "local JavaScript state"
  "at most one short line"
  "Choose above."
  "prose becomes stale"
  "outcome_unknown"
];
assert lib.all (text: lib.hasInfix text windDown) [
  "clear intent"
  "confirm card"
  "Never save calendar drafts"
];
assert !(lib.hasInfix "family-event mentions" windDown);
assert !(lib.hasInfix "mentions a family event" windDown);
assert lib.elem "show_widget" simon.tools.allow;
assert
  simon.mcp.servers.claw-calendar.toolFilter.include == (import ../lib/ai-mcp-rows.nix)
  .calendar.tools;
assert !(simon.mcp.servers ? claw-family-calendar-simon);
assert !(laure.mcp.servers ? claw-family-calendar-simon);
assert lib.pathExists "${builtins.elemAt simon.skills.load.extraDirs 1}/calendar/SKILL.md";
assert lib.all (dir: !lib.pathExists "${dir}/calendar/SKILL.md") laure.skills.load.extraDirs;
true
