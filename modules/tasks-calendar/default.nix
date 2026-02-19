{ config, lib, pkgs, ... }:

let
  cfg = config.services.tasks-calendar;

  python = pkgs.python3.withPackages (ps: [
    ps.icalendar
    ps.recurring-ical-events
  ]);

  tasks-calendar-today = pkgs.writeScriptBin "tasks-calendar-today" ''
    #!${python}/bin/python3
    """Fetch today's calendar events from an Outlook ICS feed.

    Outputs one JSON object per line:
      {"summary":"...","start":"HH:MM","end":"HH:MM"}

    All times converted to the configured timezone.
    """

    import json
    import os
    import sys
    from datetime import date, datetime, timedelta
    from pathlib import Path
    from urllib.request import urlopen
    from zoneinfo import ZoneInfo

    from icalendar import Calendar
    from recurring_ical_events import of

    TARGET_TZ = ZoneInfo("${cfg.timezone}")


    def get_calendar_url() -> str:
        url = os.environ.get("CALENDAR_URL", "")
        if url:
            return url.strip()

        secret_path = Path("${cfg.calendarUrlFile}")
        if secret_path.exists():
            return secret_path.read_text().strip()

        print("Error: No calendar URL. Set CALENDAR_URL or configure calendarUrlFile.", file=sys.stderr)
        sys.exit(1)


    def main():
        url = get_calendar_url()

        with urlopen(url, timeout=30) as resp:
            ics_data = resp.read()

        cal = Calendar.from_ical(ics_data)

        now_local = datetime.now(TARGET_TZ)
        today = now_local.date()
        start_dt = datetime(today.year, today.month, today.day, tzinfo=TARGET_TZ)
        end_dt = start_dt + timedelta(days=1)

        events = of(cal).between(start_dt, end_dt)

        results = []
        for event in events:
            summary = str(event.get("SUMMARY", "")).strip()
            if not summary:
                continue

            dtstart = event.get("DTSTART")
            dtend = event.get("DTEND")
            if not dtstart:
                continue

            dt_start = dtstart.dt
            dt_end = dtend.dt if dtend else None

            if isinstance(dt_start, date) and not isinstance(dt_start, datetime):
                results.append({
                    "summary": summary,
                    "start": "all-day",
                    "end": "",
                })
                continue

            if dt_start.tzinfo is None:
                dt_start = dt_start.replace(tzinfo=ZoneInfo("UTC"))
            dt_start = dt_start.astimezone(TARGET_TZ)

            if dt_end:
                if dt_end.tzinfo is None:
                    dt_end = dt_end.replace(tzinfo=ZoneInfo("UTC"))
                dt_end = dt_end.astimezone(TARGET_TZ)
                end_str = dt_end.strftime("%H:%M")
            else:
                end_str = ""

            results.append({
                "summary": summary,
                "start": dt_start.strftime("%H:%M"),
                "end": end_str,
            })

        results.sort(key=lambda e: e["start"])

        for r in results:
            print(json.dumps(r))


    if __name__ == "__main__":
        main()
  '';

in {
  options.services.tasks-calendar = {
    enable = lib.mkEnableOption "tasks-calendar — daily calendar fetcher";

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "America/Denver";
      description = "IANA timezone for displaying event times.";
    };

    calendarUrlFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/outlook-calendar-url";
      description = "Path to a file containing the ICS calendar URL.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ tasks-calendar-today ];
  };
}
