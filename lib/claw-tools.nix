# One tool policy shared by the enforcing endpoints and OpenClaw's own filter.
let
  rows = import ./ai-mcp-rows.nix;
in
{
  # Retiring: flakey now uses /mcp/calendar on ai (lib/ai-mcp-rows.nix).
  claw-calendar = {
    app = "google";
    inherit (rows.calendar) tools;
  };
  # Retiring: flakey now uses /mcp/gmail on ai.
  claw-gmail = {
    app = "google";
    inherit (rows.gmail) tools;
  };
  # Reads only the Family calendar; the app fixes the calendar ID, not the caller.
  claw-family-calendar = {
    app = "google";
    tools = [ "family_calendar_events" ];
  };
  # Retiring: flakey now uses /mcp/family-calendar on ai.
  # Stable tailnet node ID, not a caller-controlled HTTP header or shared tag.
  claw-family-calendar-simon = {
    app = "google";
    inherit (rows.family-calendar) tools;
    allowedNodeIds = [ (import ./tailnet-nodes.nix).flakey ];
  };
  claw-maps = {
    app = "maps";
    tools = [ "travel_time" ];
  };
}
