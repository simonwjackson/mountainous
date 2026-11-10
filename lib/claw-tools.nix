# One tool policy shared by the enforcing endpoints and OpenClaw's own filter.
{
  claw-calendar = {
    app = "google";
    tools = [ "calendar_busy" ];
  };
  claw-maps = {
    app = "maps";
    tools = [ "travel_time" ];
  };
}
