# Every /mcp row on the production front door `ai`:
# https://ai.hummingbird-lake.ts.net/mcp/<row> (docs/operations/ai-mcp-production.md).
# Each row admits flakey's stable node ID only (lib/tailnet-nodes.nix).
#
# server: the MCP server name in flakey's OpenClaw. It stays the old name, so
#   tool names (<server>__<tool>), permissions, the mail agent, skills and
#   approvals do not change; only the URL moves to the row.
# tools: the one allowlist for the row and for flakey's toolFilter. A row that
#   lists a tool not named here, or a row not named here, fails evaluation.
{
  sparkyfitness = {
    server = "sparkyfitness";
    tools = import ./openclaw-sparkyfitness-tools.nix;
  };
  calendar = {
    server = "claw-calendar";
    tools = [ "calendar_busy" ];
  };
  # Used by the Simon-only "mail" agent; flakey's main agent denies claw-gmail__*.
  # No mail_send: the row cannot send.
  gmail = {
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
    server = "claw-family-calendar-simon";
    tools = [
      "family_calendar_events"
      "family_calendar_add"
      "family_calendar_remove"
    ];
  };
  ebay = {
    server = "claw-ebay-simon";
    tools = import ./openclaw-ebay-tools.nix;
  };
  # Served natively by the proxy for Simon's Scryer account.
  scryer = {
    server = "claw-scryer-simon";
    tools = import ./openclaw-scryer-tools.nix;
  };
}
