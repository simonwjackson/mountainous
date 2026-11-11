# Gateway state, reconciled through its API. Never edit its SQLite store directly.
{
  declarationKey = "mountainous:morning-brief";
  name = "morning-brief";
  description = "Daily calendar-only brief for Simon in the main Control UI conversation";
  enabled = true;
  agentId = "main";
  sessionKey = "agent:main:main";
  sessionTarget = "isolated";
  wakeMode = "now";
  schedule = {
    kind = "cron";
    expr = "0 7 * * *";
    tz = "America/Denver";
    staggerMs = 0;
  };
  payload = {
    kind = "agentTurn";
    message = builtins.readFile ./openclaw-morning-brief.md;
    timeoutSeconds = 180;
  };
  # No channel, recipient, webhook or best-effort fallback. The session binding
  # makes the final reply a durable assistant message in the main conversation.
  delivery.mode = "announce";
}
