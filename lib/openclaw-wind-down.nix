# Gateway-owned state, reconciled through its API. Never edit SQLite directly.
{
  declarationKey = "mountainous:wind-down";
  name = "wind-down";
  description = "Short evening wind-down opener for Simon";
  enabled = true;
  agentId = "main";
  sessionKey = "agent:main:main";
  sessionTarget = "isolated";
  wakeMode = "now";
  schedule = {
    kind = "cron";
    expr = "0 21 * * *";
    tz = "America/Denver";
    staggerMs = 0;
  };
  payload = {
    kind = "agentTurn";
    message = builtins.readFile ./openclaw-wind-down.md;
    timeoutSeconds = 60;
  };
  delivery.mode = "announce";
}
