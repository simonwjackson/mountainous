# Gateway-owned state, reconciled with cron.add/cron.update; never run on deploy.
{
  declarationKey = "mountainous:pace-alerts";
  name = "pace-alerts";
  description = "Six-hour Pace alerts for Simon";
  enabled = true;
  agentId = "main";
  sessionKey = "agent:main:main";
  sessionTarget = "isolated";
  wakeMode = "now";
  schedule = {
    kind = "cron";
    expr = "30 */6 * * *";
    tz = "America/Denver";
    staggerMs = 0;
  };
  payload = {
    kind = "agentTurn";
    message = "Call pace__pace_events with {}. With no events, return exactly NO_REPLY. With events, return the tool's text exactly. Do not append NO_REPLY. Report tool failures rather than treating them as empty results.";
    timeoutSeconds = 300;
  };
  delivery.mode = "announce";
}
