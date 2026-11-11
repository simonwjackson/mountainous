# One tool policy shared by the enforcing endpoints and OpenClaw's own filter.
{
  claw-calendar = {
    app = "google";
    tools = [ "calendar_busy" ];
  };
  # Reads only the Family calendar; the app fixes the calendar ID, not the caller.
  claw-family-calendar = {
    app = "google";
    tools = [ "family_calendar_events" ];
  };
  claw-maps = {
    app = "maps";
    tools = [ "travel_time" ];
  };
}
