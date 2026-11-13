# Gateway-owned state. Reconcile through cron.add/update, never run on deploy.
{
  declarationKey = "mountainous:mail-not-me";
  name = "mail-not-me";
  description = "Hourly metadata-only Not Me filing for Simon";
  enabled = true;
  agentId = "mail";
  sessionTarget = "isolated";
  wakeMode = "now";
  # Avoid the 07:00 brief and the top-of-hour heartbeat.
  schedule = {
    kind = "cron";
    expr = "15 * * * *";
    tz = "America/Denver";
    staggerMs = 0;
  };
  payload = {
    toolsAllow = map (tool: "claw-gmail__${tool}") [
      "mail_list"
      "mail_not_mine"
      "mail_label"
      "mail_archive"
    ];
    kind = "agentTurn";
    message = builtins.readFile ./openclaw-mail-filing.md;
    timeoutSeconds = 600;
  };
  delivery.mode = "none";
  failureAlert = false;
}
