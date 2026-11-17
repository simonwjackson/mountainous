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
  mindwtr = {
    callers = [ "flakey" ];
    server = "mindwtr";
    tools = import ./openclaw-mindwtr-tools.nix;
  };
  pace = {
    callers = [ "flakey" ];
    server = "pace";
    tools = [
      "pace_status"
      "pace_overview"
      "pace_goal_set"
      "pace_goal_add"
      "pace_goal_remove"
      "pace_goal_paid"
      "pace_budget_set"
      "pace_budget_remove"
      "pace_category_correct"
      "pace_category_one_off"
      "pace_changes"
      "pace_undo"
      "pace_events"
      "pace_goal_paid_answer"
    ];
  };
  pace-laure = {
    callers = [ "snowy" ];
    server = "pace";
    tools = [
      "pace_status"
      "pace_overview"
      "pace_goal_set"
      "pace_goal_add"
      "pace_goal_remove"
      "pace_goal_paid"
      "pace_budget_set"
      "pace_budget_remove"
      "pace_category_correct"
      "pace_category_one_off"
      "pace_changes"
      "pace_undo"
      "pace_events"
      "pace_goal_paid_answer"
    ];
  };
  sparkyfitness = {
    callers = [ "flakey" ];
    server = "sparkyfitness";
    tools = import ./openclaw-sparkyfitness-tools.nix;
  };
  calendar = {
    callers = [ "flakey" ];
    server = "claw-calendar";
    tools = [
      "calendar_busy"
      "calendars_list"
      "calendar_events"
      "calendar_add"
      "calendar_remove"
    ];
  };
  # Reader tools plus Gmail cards for Simon only. Send is app-only in the
  # connector; mail_send is never forwarded or registered.
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
      "mail_queue"
      "mail_triage"
      "mail_send_card"
      "mail_card_items"
      "mail_card_archive"
      "mail_card_undo"
      "mail_answer_owner"
      "mail_draft_get"
      "mail_send_draft"
      "mail_discard_card"
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
  # Web search through the front door's /v1/search source cascade, served
  # natively by the proxy with the gateways' own front-door key
  # (modules/claw-websearch.nix).
  websearch = {
    callers = [
      "flakey"
      "snowy"
    ];
    server = "claw-websearch";
    tools = [ "web_search" ];
  };
}
