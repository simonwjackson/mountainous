# One tool policy shared by the enforcing endpoints and OpenClaw's own filter.
{
  claw-calendar = {
    app = "google";
    tools = [ "calendar_busy" ];
  };
  # Prepared on Rakku only. No gateway receives mail tools in this step.
  claw-gmail = {
    app = "google";
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
