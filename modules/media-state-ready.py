#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Refuse empty or damaged app state instead of starting a setup wizard."""
from contextlib import closing
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sqlite3
import sys
import xml.etree.ElementTree as ET

# Pinned ARR TaskManager implementations retain LastExecution on startup, but
# replace Interval. Keep every native scheduled job held until explicit resume.
SCHEDULE_HOLD_UNTIL = "2099-01-01 00:00:00"

ARR = {
    "sonarr": "/var/lib/sonarr/.config/NzbDrone",
    "radarr": "/var/lib/radarr/.config/Radarr",
    "prowlarr": "/var/lib/prowlarr",
}


def pause_columns(name):
    if name == "prowlarr":
        return {"DownloadClients": ["Enable"], "Indexers": ["Enable"], "Applications": ["SyncLevel"]}
    return {"DownloadClients": ["Enable"], "Indexers": ["EnableRss", "EnableAutomaticSearch", "EnableInteractiveSearch"]}


def processing_columns(name):
    return {**pause_columns(name), "ScheduledTasks": ["LastExecution"]}


def scheduled_task_snapshot(connection):
    columns = ("Id", "TypeName", "Interval", "LastExecution", "LastStartTime")
    available = {row[1] for row in connection.execute('PRAGMA table_info("ScheduledTasks")')}
    commands = {row[1] for row in connection.execute('PRAGMA table_info("Commands")')}
    if not set(columns).issubset(available) or "Status" not in commands:
        raise ValueError("missing configured scheduler state")
    if connection.execute("SELECT count(*) FROM Commands WHERE Status IN (0,1)").fetchone()[0]:
        raise ValueError("queued or active application commands are not held")
    rows = [dict(zip(columns, row)) for row in connection.execute(
        'SELECT Id,TypeName,Interval,LastExecution,LastStartTime FROM ScheduledTasks ORDER BY Id')]
    if not rows:
        raise ValueError("missing configured scheduler tasks")
    return rows


def validate_scheduled_pause(connection):
    expected = datetime.fromisoformat(SCHEDULE_HOLD_UNTIL).replace(tzinfo=timezone.utc)
    if datetime.now(timezone.utc).year >= 2098:
        raise ValueError("scheduled processing hold requires operator renewal")
    for row in scheduled_task_snapshot(connection):
        try:
            value = datetime.fromisoformat(str(row["LastExecution"]).replace("Z", "+00:00"))
            if value.tzinfo is None:
                value = value.replace(tzinfo=timezone.utc)
        except ValueError:
            raise ValueError("scheduled application processing is not held") from None
        if value != expected:
            raise ValueError("scheduled application processing is not held")


def validate_arr_pause_flags(name, connection):
    for table, columns in pause_columns(name).items():
        for column in columns:
            if connection.execute('SELECT count(*) FROM "' + table + '" WHERE "' + column + '" IS NULL OR "' + column + '" != 0').fetchone()[0]:
                raise ValueError("application processing is not held")
    if name != "prowlarr":
        rows = connection.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall()
        if len(rows) != 1 or rows[0][0].lower() != "false":
            raise ValueError("completed-download imports are not held")


def validate_arr_pause(name, connection):
    validate_arr_pause_flags(name, connection)
    validate_scheduled_pause(connection)


def protected_pause_receipt(receipt, original):
    fd = os.open(receipt, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as stream:
        json.dump(original, stream, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def prepare_arr_scheduler_pause(name, directory, receipt):
    """Extend an existing stopped processing hold without replacing its first receipt."""
    if name not in ARR:
        raise ValueError("unsupported application")
    directory, receipt = Path(directory), Path(receipt)
    if receipt.resolve().is_relative_to(directory.resolve()):
        raise ValueError("receipt must be outside application state")
    validate_arr(name, directory)
    with closing(sqlite3.connect("file:" + str(directory / (name + ".db")) + "?mode=rw", uri=True)) as db, db:
        db.execute("BEGIN IMMEDIATE")
        validate_arr_pause_flags(name, db)
        original = {"format": 1, "application": name, "scheduled_tasks": scheduled_task_snapshot(db),
                    "hold_until": SCHEDULE_HOLD_UNTIL}
        protected_pause_receipt(receipt, original)
        db.execute("UPDATE ScheduledTasks SET LastExecution=?", (SCHEDULE_HOLD_UNTIL,))
        validate_arr_pause(name, db)


def prepare_arr_pause(name, directory, receipt):
    """Hold a stopped target copy. Keep exact old flags for later approved recovery."""
    if name not in ARR:
        raise ValueError("unsupported application")
    directory, receipt = Path(directory), Path(receipt)
    if receipt.resolve().is_relative_to(directory.resolve()):
        raise ValueError("receipt must be outside application state")
    validate_arr(name, directory)
    database = directory / (name + ".db")
    with closing(sqlite3.connect("file:" + str(database) + "?mode=rw", uri=True)) as db, db:
        db.execute("BEGIN IMMEDIATE")
        original = {"format": 1, "application": name, "flags": {}, "completed_download_handling": None,
                    "scheduled_tasks": scheduled_task_snapshot(db), "hold_until": SCHEDULE_HOLD_UNTIL}
        for table, columns in pause_columns(name).items():
            selected = ','.join('"' + column + '"' for column in ["Id"] + columns)
            original["flags"][table] = [dict(zip(["Id"] + columns, row))
                for row in db.execute('SELECT ' + selected + ' FROM "' + table + '"')]
        if name != "prowlarr":
            rows = db.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall()
            if len(rows) > 1:
                raise ValueError("duplicate import configuration")
            original["completed_download_handling"] = rows[0][0] if rows else None
        protected_pause_receipt(receipt, original)
        db.execute("UPDATE ScheduledTasks SET LastExecution=?", (SCHEDULE_HOLD_UNTIL,))
        for table, columns in pause_columns(name).items():
            assignments = ','.join('"' + column + '"=0' for column in columns)
            db.execute('UPDATE "' + table + '" SET ' + assignments)
        if name != "prowlarr":
            if rows:
                db.execute("UPDATE Config SET Value='False' WHERE Key='enablecompleteddownloadhandling'")
            else:
                db.execute("INSERT INTO Config (Key,Value) VALUES ('enablecompleteddownloadhandling','False')")
        validate_arr_pause(name, db)


def validate_arr(name, directory, require_pause=False):
    root = ET.parse(directory / "config.xml").getroot()
    if not (root.findtext("ApiKey") or "").strip():
        raise ValueError("missing application identity")
    database = directory / (name + ".db")
    with closing(sqlite3.connect("file:" + str(database) + "?mode=ro", uri=True)) as connection:
        connection.execute("PRAGMA query_only=ON")
        if connection.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
            raise ValueError("database integrity failure")
        for table in ("Users", "VersionInfo"):
            if connection.execute('SELECT count(*) FROM "' + table + '"').fetchone()[0] == 0:
                raise ValueError("missing configured application state")
        if require_pause:
            validate_arr_pause(name, connection)


def main():
    name = sys.argv[1]
    if name in ARR:
        validate_arr(name, Path(ARR[name]), require_pause="--hold" in sys.argv[2:])
    elif name == "transmission":
        settings = json.loads(Path("/var/lib/transmission/.config/transmission-daemon/settings.json").read_text())
        if not settings.get("download-dir", settings.get("download_dir")):
            raise ValueError("missing download directory")
    elif name == "nzbget":
        path = Path("/var/lib/nzbget/nzbget.conf")
        settings = dict(tuple(part.strip() for part in line.split("=", 1))
                        for line in path.read_text().splitlines()
                        if line.strip() and not line.lstrip().startswith("#") and "=" in line)
        if not settings.get("ControlPassword", "").strip():
            raise ValueError("missing downloader credentials")
    else:
        raise ValueError("unknown application")
    print("Existing application state passed startup validation")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Parser errors can include config contents. Never print the exception.
        print("Refused startup: existing application state is missing or invalid", file=sys.stderr)
        sys.exit(1)
