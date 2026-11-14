# Every /mcp row on the production front door `ai`:
# https://ai.hummingbird-lake.ts.net/mcp/<row> (docs/operations/ai-mcp-production.md).
#
# callers: the gateway nodes the row admits, as keys of lib/tailnet-nodes.nix.
#   The row matches their stable node IDs, never a name. Each gateway's
#   person has the same key as its nodeName (lib/openclaw-people.nix).
# server: the MCP server name in each caller's OpenClaw. It stays the old
#   name, so tool names (<server>__<tool>), permissions, the mail agent,
#   skills and approvals do not change; only the URL moves to the row.
# tools: the one allowlist for the row and for the callers' toolFilter. A row
#   that lists a tool not named here, a row not named here, or a row whose
#   callers differ from these fails evaluation.
{
  sparkyfitness = {
    callers = [ "flakey" ];
    server = "sparkyfitness";
    tools = import ./openclaw-sparkyfitness-tools.nix;
  };
  calendar = {
    callers = [ "flakey" ];
    server = "claw-calendar";
    tools = [ "calendar_busy" ];
  };
  # Used by the Simon-only "mail" agent; flakey's main agent denies claw-gmail__*.
  # No mail_send: the row cannot send.
  gmail = {
    callers = [ "flakey" ];
    server = "claw-gmail";
    tools = [
      "mail_list"
      "mail_read"
      "mail_not_mine"
      "mail_label"
      "mail_archive"
      "mail_draft"
      "mail_discard_draft"
    ];
  };
  # Reads and writes the Family calendar; the app fixes the calendar ID.
  family-calendar = {
    callers = [ "flakey" ];
    server = "claw-family-calendar-simon";
    tools = [
      "family_calendar_events"
      "family_calendar_add"
      "family_calendar_remove"
    ];
  };
  ebay = {
    callers = [ "flakey" ];
    server = "claw-ebay-simon";
    tools = import ./openclaw-ebay-tools.nix;
  };
  # Served natively by the proxy for Simon's Scryer account.
  scryer = {
    callers = [ "flakey" ];
    server = "claw-scryer-simon";
    tools = import ./openclaw-scryer-tools.nix;
  };
  # Laure's (stage 7). Reads only the Family calendar, through the same Google
  # app; no add or remove.
  family-calendar-laure = {
    callers = [ "snowy" ];
    server = "claw-family-calendar";
    tools = [ "family_calendar_events" ];
  };
  # Served natively by the proxy for Laure's Scryer account.
  scryer-laure = {
    callers = [ "snowy" ];
    server = "claw-scryer-laure";
    tools = import ./openclaw-scryer-tools.nix;
  };
  # Shared by both gateways (stage 7).
  maps = {
    callers = [
      "flakey"
      "snowy"
    ];
    server = "claw-maps";
    tools = [ "travel_time" ];
  };
  # Model-native web search, served natively by the proxy with the gateways'
  # own front-door key (modules/claw-websearch.nix).
  websearch = {
    callers = [
      "flakey"
      "snowy"
    ];
    server = "claw-websearch";
    tools = [ "web_search" ];
  };
}
