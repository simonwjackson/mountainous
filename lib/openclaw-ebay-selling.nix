# Gateway-owned state, reconciled with cron.add/cron.update; never run on deploy.
{
  declarationKey = "mountainous:ebay-selling";
  name = "ebay-selling";
  description = "Daily eBay selling drafts for Simon's approval";
  enabled = true;
  agentId = "main";
  sessionKey = "agent:main:main";
  sessionTarget = "isolated";
  wakeMode = "now";
  schedule = {
    kind = "cron";
    expr = "0 8 * * *";
    tz = "America/Denver";
    staggerMs = 0;
  };
  payload = {
    kind = "agentTurn";
    message = builtins.readFile ./openclaw-ebay-selling.md;
    timeoutSeconds = 300;
  };
  delivery.mode = "announce";
}
