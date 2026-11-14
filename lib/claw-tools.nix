# One tool policy shared by the enforcing endpoints and OpenClaw's own filter.
# Each entry is its own tailnet node on Rakku. Simon's own Google tools are
# rows on the production front door instead (lib/ai-mcp-rows.nix).
{
  # Laure's: reads only the Family calendar; the app fixes the calendar ID, not the caller.
  claw-family-calendar = {
    app = "google";
    tools = [ "family_calendar_events" ];
  };
  # Shared by both gateways.
  claw-maps = {
    app = "maps";
    tools = [ "travel_time" ];
  };
}
